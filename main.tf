# VPN Gateway Module - Enterprise Secure Connectivity
# Creates Azure VPN Gateways with enterprise-grade security and high availability

resource "azurerm_virtual_network_gateway" "vpn_gateway" {
  name                = local.vpn_gateway_name
  location            = var.location
  resource_group_name = var.resource_group_name

  type     = "Vpn"
  vpn_type = var.vpn_type

  sku = var.sku

  # Active-active configuration for high availability
  active_active = var.active_active

  # BGP settings for dynamic routing
  dynamic "bgp_settings" {
    for_each = var.enable_bgp ? [1] : []
    content {
      asn = var.bgp_asn
      dynamic "peering_addresses" {
        for_each = var.bgp_peering_addresses
        content {
          ip_configuration_name = peering_addresses.value.ip_configuration_name
          apipa_addresses       = peering_addresses.value.apipa_addresses
        }
      }
    }
  }

  # IP configuration
  dynamic "ip_configuration" {
    for_each = var.ip_configurations
    content {
      name                          = ip_configuration.value.name
      public_ip_address_id          = ip_configuration.value.public_ip_address_id
      private_ip_address_allocation = ip_configuration.value.private_ip_address_allocation
      subnet_id                     = ip_configuration.value.subnet_id
    }
  }

  # VPN client configuration for P2S
  dynamic "vpn_client_configuration" {
    for_each = var.vpn_client_configuration != null ? [var.vpn_client_configuration] : []
    content {
      address_space = vpn_client_configuration.value.address_space

      # Root certificates
      dynamic "root_certificate" {
        for_each = vpn_client_configuration.value.root_certificates
        content {
          name             = root_certificate.value.name
          public_cert_data = root_certificate.value.public_cert_data
        }
      }

      # Revoked certificates
      dynamic "revoked_certificate" {
        for_each = vpn_client_configuration.value.revoked_certificates
        content {
          name          = revoked_certificate.value.name
          thumbprint    = revoked_certificate.value.thumbprint
        }
      }

      # RADIUS settings
      dynamic "radius_server" {
        for_each = vpn_client_configuration.value.radius_server != null ? [vpn_client_configuration.value.radius_server] : []
        content {
          address = radius_server.value.address
          secret  = radius_server.value.secret
          score   = radius_server.value.score
        }
      }

      vpn_client_protocols = vpn_client_configuration.value.vpn_client_protocols
      vpn_auth_types       = vpn_client_configuration.value.vpn_auth_types
    }
  }

  tags = local.tags
}

# Local Network Gateways for S2S VPN
resource "azurerm_local_network_gateway" "local_gateways" {
  for_each = var.local_network_gateways

  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name

  gateway_address = each.value.gateway_address

  # Address spaces
  address_space = each.value.address_space

  # BGP settings
  dynamic "bgp_settings" {
    for_each = each.value.bgp_settings != null ? [each.value.bgp_settings] : []
    content {
      asn                 = bgp_settings.value.asn
      bgp_peering_address = bgp_settings.value.bgp_peering_address
      peer_weight         = bgp_settings.value.peer_weight
    }
  }

}

# VPN Connections
resource "azurerm_virtual_network_gateway_connection" "connections" {
  for_each = var.vpn_connections

  name                       = each.value.name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn_gateway.id

  type            = each.value.type
  connection_mode = each.value.connection_mode

  # Connection configuration based on type
  local_network_gateway_id = each.value.type == "IPSec" ? azurerm_local_network_gateway.local_gateways[each.value.local_gateway_name].id : null

  # Shared key for authentication
  shared_key = each.value.shared_key

  # DPD timeout
  dpd_timeout_seconds = each.value.dpd_timeout_seconds

  # Enable BGP
  enable_bgp = each.value.enable_bgp

  # Use policy-based traffic selectors
  use_policy_based_traffic_selectors = each.value.use_policy_based_traffic_selectors

}

# Public IP Addresses for VPN Gateway
resource "azurerm_public_ip" "vpn_gateway_pips" {
  for_each = var.public_ip_configurations

  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name

  allocation_method = each.value.allocation_method
  sku               = each.value.sku

  # Zones for high availability
  zones = each.value.zones
}

# Network Security Groups for Gateway Subnet
resource "azurerm_network_security_group" "gateway_subnet" {
  count = var.create_gateway_nsg ? 1 : 0

  name                = "${local.vpn_gateway_name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow IKEv2
  security_rule {
    name                       = "Allow_IKEv2"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "500"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow IPsec NAT-T
  security_rule {
    name                       = "Allow_IPsec_NAT_T"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "4500"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow SSTP VPN
  security_rule {
    name                       = "Allow_SSTP_VPN"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.tags
}

# Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "vpn_gateway_diagnostics" {
  for_each = var.diagnostic_settings

  name                       = each.value.name
  target_resource_id         = azurerm_virtual_network_gateway.vpn_gateway.id
  log_analytics_workspace_id = each.value.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = each.value.logs
    content {
      category = enabled_log.value.category
    }
  }

  dynamic "metric" {
    for_each = each.value.metrics
    content {
      category = metric.value.category
      enabled  = metric.value.enabled
    }
  }
}

# Local values
locals {
  vpn_gateway_name = var.vpn_gateway_name != null ? var.vpn_gateway_name : "vgw-${var.naming_prefix}-${var.environment}"

  tags = merge(
    var.tags,
    {
      Module      = "vpn-gateway"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}