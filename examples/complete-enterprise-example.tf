# VPN Gateway Module - Complete Enterprise Example

# This example demonstrates a production-ready VPN Gateway deployment with:
# - Site-to-Site VPN connections
# - Point-to-Site VPN configuration
# - BGP support for dynamic routing
# - Active-Active configuration for high availability
# - Azure Policy integration
# - Comprehensive monitoring and diagnostics

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80.0"
    }
  }
}

# Data sources
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "example" {
  name     = "rg-vpn-gateway-example"
  location = "East US"

  tags = {
    Environment = "example"
    Module      = "vpn-gateway"
    Owner       = "platform-team"
  }
}

# Log Analytics Workspace for diagnostics
resource "azurerm_log_analytics_workspace" "example" {
  name                = "law-vpn-gateway-example"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    Environment = "example"
  }
}

# Virtual Network and Gateway Subnet
resource "azurerm_virtual_network" "example" {
  name                = "vnet-vpn-gateway-example"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    Environment = "example"
  }
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}

# VPN Gateway Module
module "vpn_gateway" {
  source = "../"

  # Basic Configuration
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  environment         = "example"
  vpn_gateway_name    = "vpn-gw-example"

  # Gateway Configuration
  sku           = "VpnGw2AZ" # Zone-redundant for high availability
  vpn_type      = "RouteBased"
  active_active = true # Enable active-active for redundancy
  enable_bgp    = true # Enable BGP for dynamic routing

  # BGP Configuration
  bgp_asn = 65001
  bgp_peering_addresses = [
    {
      ip_configuration_name = "vnetGatewayConfig1"
      apipa_addresses       = ["169.254.21.1"]
    },
    {
      ip_configuration_name = "vnetGatewayConfig2"
      apipa_addresses       = ["169.254.21.5"]
    }
  ]

  # Public IP Configurations (Active-Active requires 2 PIPs)
  public_ip_configurations = {
    pip1 = {
      name              = "pip-vpn-gw-1"
      allocation_method = "Static"
      sku               = "Standard"
      zones             = ["1", "2", "3"] # Zone-redundant
    }
    pip2 = {
      name              = "pip-vpn-gw-2"
      allocation_method = "Static"
      sku               = "Standard"
      zones             = ["1", "2", "3"] # Zone-redundant
    }
  }

  # IP Configurations
  ip_configurations = [
    {
      name                          = "vnetGatewayConfig1"
      public_ip_address_id          = module.vpn_gateway.public_ip_ids["pip1"]
      private_ip_address_allocation = "Dynamic"
      subnet_id                     = azurerm_subnet.gateway.id
    },
    {
      name                          = "vnetGatewayConfig2"
      public_ip_address_id          = module.vpn_gateway.public_ip_ids["pip2"]
      private_ip_address_allocation = "Dynamic"
      subnet_id                     = azurerm_subnet.gateway.id
    }
  ]

  # Point-to-Site VPN Configuration
  vpn_client_configuration = {
    address_space = ["192.168.100.0/24"]
    root_certificates = [
      {
        name             = "P2SRootCert"
        public_cert_data = "MIIC5jCCAc6gAwIBAgITQ...[Base64 encoded certificate data]"
      }
    ]
    vpn_client_protocols = ["IkeV2", "OpenVPN"]
    vpn_auth_types       = ["Certificate"]
  }

  # Local Network Gateways for Site-to-Site VPN
  local_network_gateways = {
    "onprem-office" = {
      name            = "lng-onprem-office"
      gateway_address = "203.0.113.1"
      address_space   = ["192.168.1.0/24", "192.168.2.0/24"]
      bgp_settings = {
        asn                 = 65002
        bgp_peering_address = "203.0.113.2"
        peer_weight         = 0
      }
    }
    "onprem-datacenter" = {
      name            = "lng-onprem-datacenter"
      gateway_address = "203.0.113.10"
      address_space   = ["10.10.0.0/16"]
      bgp_settings = {
        asn                 = 65003
        bgp_peering_address = "203.0.113.11"
        peer_weight         = 0
      }
    }
  }

  # VPN Connections
  vpn_connections = {
    "office-connection" = {
      name                     = "vpn-conn-office"
      type                     = "IPsec"
      local_network_gateway_id = module.vpn_gateway.local_network_gateway_ids["onprem-office"]
      shared_key               = "SuperSecretSharedKey123!@#"
      connection_protocol      = "IKEv2"
      enable_bgp               = true
      ipsec_policy = {
        dh_group         = "DHGroup14"
        ike_encryption   = "AES256"
        ike_integrity    = "SHA256"
        ipsec_encryption = "AES256"
        ipsec_integrity  = "SHA256"
        pfs_group        = "PFS2048"
        sa_datasize      = 102400000
        sa_lifetime      = 27000
      }
      traffic_selector_policy = [
        {
          local_address_cidrs  = ["10.0.0.0/16"]
          remote_address_cidrs = ["192.168.1.0/24", "192.168.2.0/24"]
        }
      ]
    }
    "datacenter-connection" = {
      name                     = "vpn-conn-datacenter"
      type                     = "IPsec"
      local_network_gateway_id = module.vpn_gateway.local_network_gateway_ids["onprem-datacenter"]
      shared_key               = "AnotherSuperSecretKey456!@#"
      connection_protocol      = "IKEv2"
      enable_bgp               = true
      ipsec_policy = {
        dh_group         = "DHGroup14"
        ike_encryption   = "AES256"
        ike_integrity    = "SHA256"
        ipsec_encryption = "AES256"
        ipsec_integrity  = "SHA256"
        pfs_group        = "PFS2048"
        sa_datasize      = 102400000
        sa_lifetime      = 27000
      }
    }
  }

  # Network Security Group for Gateway Subnet
  create_gateway_nsg = true

  # Diagnostic Settings
  diagnostic_settings = {
    "diagnostics" = {
      name                       = "diag-vpn-gateway"
      log_analytics_workspace_id = azurerm_log_analytics_workspace.example.id
      logs = [
        {
          category = "GatewayDiagnosticLog"
        },
        {
          category = "TunnelDiagnosticLog"
        },
        {
          category = "RouteDiagnosticLog"
        },
        {
          category = "IKEDiagnosticLog"
        }
      ]
      metrics = [
        {
          category = "AllMetrics"
          enabled  = true
        }
      ]
    }
  }

  # Azure Policy Integration
  enable_policy_assignments  = true
  enable_custom_policies     = true
  log_analytics_workspace_id = azurerm_log_analytics_workspace.example.id
  minimum_sku                = "VpnGw2AZ"

  # Tags
  tags = {
    Environment       = "example"
    Project           = "enterprise-vpn"
    CostCenter        = "networking"
    Owner             = "platform-team"
    Confidentiality   = "internal"
    Compliance        = "sox-pci"
    Backup            = "daily"
    MaintenanceWindow = "sunday-02:00"
  }
}

# Outputs
output "vpn_gateway_id" {
  description = "VPN Gateway resource ID"
  value       = module.vpn_gateway.vpn_gateway_id
}

output "vpn_gateway_name" {
  description = "VPN Gateway name"
  value       = module.vpn_gateway.vpn_gateway_name
}

output "public_ip_addresses" {
  description = "Public IP addresses of the VPN Gateway"
  value       = module.vpn_gateway.public_ip_addresses
}

output "vpn_client_configuration" {
  description = "VPN client configuration for Point-to-Site connections"
  value       = module.vpn_gateway.vpn_client_configuration
  sensitive   = true
}

output "local_network_gateway_ids" {
  description = "Local Network Gateway resource IDs"
  value       = module.vpn_gateway.local_network_gateway_ids
}

output "vpn_connection_ids" {
  description = "VPN connection resource IDs"
  value       = module.vpn_gateway.vpn_connection_ids
}

output "bgp_peering_addresses" {
  description = "BGP peering addresses"
  value       = module.vpn_gateway.bgp_peering_addresses
}

output "gateway_nsg_id" {
  description = "Gateway subnet NSG ID"
  value       = module.vpn_gateway.gateway_nsg_id
}