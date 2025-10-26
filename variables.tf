variable "vpn_gateway_name" {
  description = "Name of the VPN Gateway. If null, will be auto-generated."
  type        = string
  default     = null
}

variable "naming_prefix" {
  description = "Prefix for VPN Gateway naming"
  type        = string
  default     = "vpn-gateway"
}

variable "environment" {
  description = "Environment name (e.g., prod, dev, test)"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "vpn_type" {
  description = "VPN type for the gateway"
  type        = string
  default     = "RouteBased"
  validation {
    condition     = contains(["PolicyBased", "RouteBased"], var.vpn_type)
    error_message = "VPN type must be PolicyBased or RouteBased."
  }
}

variable "sku" {
  description = "SKU of the VPN Gateway"
  type        = string
  default     = "VpnGw1"
  validation {
    condition = contains([
      "Basic", "VpnGw1", "VpnGw2", "VpnGw3", "VpnGw4", "VpnGw5",
      "VpnGw1AZ", "VpnGw2AZ", "VpnGw3AZ", "VpnGw4AZ", "VpnGw5AZ"
    ], var.sku)
    error_message = "SKU must be a valid VPN Gateway SKU."
  }
}

variable "active_active" {
  description = "Enable active-active configuration"
  type        = bool
  default     = false
}

variable "enable_bgp" {
  description = "Enable BGP for the VPN Gateway"
  type        = bool
  default     = false
}

variable "bgp_asn" {
  description = "BGP ASN for the VPN Gateway"
  type        = number
  default     = 65515
}

variable "bgp_peering_addresses" {
  description = "BGP peering addresses configuration"
  type = list(object({
    ip_configuration_name = string
    apipa_addresses       = optional(list(string))
  }))
  default = []
}

variable "ip_configurations" {
  description = "IP configurations for the VPN Gateway"
  type = list(object({
    name                          = string
    public_ip_address_id          = string
    private_ip_address_allocation = string
    subnet_id                     = string
  }))
}

variable "vpn_client_configuration" {
  description = "VPN client configuration for P2S VPN"
  type = object({
    address_space = list(string)
    root_certificates = list(object({
      name             = string
      public_cert_data = string
    }))
    revoked_certificates = optional(list(object({
      name          = string
      serial_number = string
      thumbprint    = string
    })), [])
    radius_server = optional(object({
      address = string
      secret  = string
      score   = optional(number, 30)
    }))
    vpn_client_protocols = optional(list(string), ["IkeV2"])
    vpn_auth_types       = optional(list(string), ["Certificate"])
  })
  default = null
}

variable "local_network_gateways" {
  description = "Local network gateway configurations for S2S VPN"
  type = map(object({
    name            = string
    gateway_address = string
    address_space   = list(string)
    bgp_settings = optional(object({
      asn                 = number
      bgp_peering_address = string
      peer_weight         = optional(number, 0)
    }))
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "vpn_connections" {
  description = "VPN connection configurations"
  type = map(object({
    name                               = string
    type                               = string
    connection_mode                    = optional(string, "Default")
    local_network_gateway_id           = optional(string)
    express_route_circuit_id           = optional(string)
    peer_virtual_network_gateway_id    = optional(string)
    shared_key                         = string
    connection_protocol                = optional(string, "IKEv2")
    dpd_timeout_seconds                = optional(number, 45)
    enable_bgp                         = optional(bool, false)
    use_policy_based_traffic_selectors = optional(bool, false)
    routing = optional(object({
      weight = number
    }))
    ipsec_policy = optional(object({
      dh_group         = string
      ike_encryption   = string
      ike_integrity    = string
      ipsec_encryption = string
      ipsec_integrity  = string
      pfs_group        = string
      sa_datasize      = optional(number)
      sa_lifetime      = optional(number)
    }))
    traffic_selector_policy = optional(list(object({
      local_address_cidrs  = list(string)
      remote_address_cidrs = list(string)
    })), [])
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "public_ip_configurations" {
  description = "Public IP configurations for VPN Gateway"
  type = map(object({
    name                    = string
    allocation_method       = string
    sku                     = string
    zones                   = optional(list(string))
    ddos_protection_plan_id = optional(string)
    tags                    = optional(map(string), {})
  }))
  default = {}
}

variable "create_gateway_nsg" {
  description = "Create NSG for gateway subnet"
  type        = bool
  default     = true
}

variable "diagnostic_settings" {
  description = "Diagnostic settings configurations"
  type = map(object({
    name                       = string
    log_analytics_workspace_id = string
    logs = list(object({
      category = string
    }))
    metrics = list(object({
      category = string
      enabled  = bool
    }))
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_policy_assignments" {
  description = "Enable Azure Policy assignments for VPN Gateway security"
  type        = bool
  default     = false
}

variable "enable_custom_policies" {
  description = "Enable custom Azure Policy definitions"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for diagnostic settings"
  type        = string
  default     = null
}

variable "minimum_sku" {
  description = "Minimum required VPN Gateway SKU for custom policy"
  type        = string
  default     = "VpnGw2"
  validation {
    condition = contains([
      "VpnGw2", "VpnGw3", "VpnGw2AZ", "VpnGw3AZ"
    ], var.minimum_sku)
    error_message = "Minimum SKU must be a valid high-performance VPN Gateway SKU."
  }
}