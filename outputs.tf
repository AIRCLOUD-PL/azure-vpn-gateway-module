output "vpn_gateway_id" {
  description = "ID of the VPN Gateway"
  value       = azurerm_virtual_network_gateway.vpn_gateway.id
}

output "vpn_gateway_name" {
  description = "Name of the VPN Gateway"
  value       = azurerm_virtual_network_gateway.vpn_gateway.name
}

output "vpn_gateway_public_ips" {
  description = "Public IP addresses of the VPN Gateway"
  value       = azurerm_virtual_network_gateway.vpn_gateway.bgp_settings[0].peering_addresses[*].tunnel_ip_addresses
}

output "vpn_gateway_bgp_asn" {
  description = "BGP ASN of the VPN Gateway"
  value       = var.enable_bgp ? azurerm_virtual_network_gateway.vpn_gateway.bgp_settings[0].asn : null
}

output "local_network_gateway_ids" {
  description = "IDs of the local network gateways"
  value = {
    for k, v in azurerm_local_network_gateway.local_gateways :
    k => v.id
  }
}

output "vpn_connection_ids" {
  description = "IDs of the VPN connections"
  value = {
    for k, v in azurerm_virtual_network_gateway_connection.connections :
    k => v.id
  }
}

output "public_ip_ids" {
  description = "IDs of the public IP addresses"
  value = {
    for k, v in azurerm_public_ip.vpn_gateway_pips :
    k => v.id
  }
}

output "public_ip_addresses" {
  description = "Public IP addresses"
  value = {
    for k, v in azurerm_public_ip.vpn_gateway_pips :
    k => v.ip_address
  }
}

output "gateway_nsg_id" {
  description = "ID of the gateway subnet NSG"
  value       = var.create_gateway_nsg ? azurerm_network_security_group.gateway_subnet[0].id : null
}

output "vpn_client_configuration" {
  description = "VPN client configuration details"
  value = var.vpn_client_configuration != null ? {
    address_space        = azurerm_virtual_network_gateway.vpn_gateway.vpn_client_configuration[0].address_space
    vpn_client_protocols = azurerm_virtual_network_gateway.vpn_gateway.vpn_client_configuration[0].vpn_client_protocols
    vpn_auth_types       = azurerm_virtual_network_gateway.vpn_gateway.vpn_client_configuration[0].vpn_auth_types
  } : null
  sensitive = true
}

output "shared_keys" {
  description = "VPN connection shared keys"
  value = {
    for k, v in azurerm_virtual_network_gateway_connection.connections :
    k => v.shared_key
  }
  sensitive = true
}