<p align="center">
  <a href="https://aircloud.com.pl"><img src=".github/assets/banner.png" alt="AIRCLOUD: DevOps, cloud and AI engineering" width="100%"></a>
</p>

# azure-vpn-gateway-module

**Azure VPN Gateway Terraform module — parameterised, azurerm 4.x, CI-validated.**

[![CI](https://github.com/AIRCLOUD-PL/azure-vpn-gateway-module/actions/workflows/ci.yml/badge.svg)](https://github.com/AIRCLOUD-PL/azure-vpn-gateway-module/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/AIRCLOUD-PL/azure-vpn-gateway-module?sort=semver)](https://github.com/AIRCLOUD-PL/azure-vpn-gateway-module/releases)

This Terraform module creates a comprehensive Azure VPN Gateway with enterprise-grade features including Site-to-Site (S2S), Point-to-Site (P2S), and VNet-to-VNet connectivity options.

## Features

- **Multiple VPN Types**: Support for Route-based and Policy-based VPN gateways
- **High Availability**: Active-Active configuration with zone redundancy
- **BGP Support**: Dynamic routing with customizable ASN and peering addresses
- **Security**: IPsec policies, IKEv2 protocol enforcement, and traffic selectors
- **Monitoring**: Comprehensive diagnostic settings and Azure Policy integration
- **Compliance**: Built-in Azure Policy assignments for security and compliance
- **Testing**: Full Terratest coverage with multiple test scenarios

## Architecture

The module creates the following Azure resources:

- Virtual Network Gateway (VPN Gateway)
- Public IP Addresses (with zone redundancy support)
- Local Network Gateways (for S2S connections)
- VPN Connections (S2S, P2S, VNet-to-VNet)
- Network Security Group (for GatewaySubnet)
- Diagnostic Settings (logs and metrics)
- Azure Policy Assignments (optional)

## Usage

Pin the module to a release tag:

```hcl
module "vpn_gateway" {
  source = "git::https://github.com/AIRCLOUD-PL/azure-vpn-gateway-module.git?ref=v1.0.0"

  # required inputs
  environment         = "..."
  ip_configurations   = []
  location            = "..."
  resource_group_name = "..."
}
```

All inputs and outputs are listed in the generated reference below ([Inputs](#inputs), [Outputs](#outputs)). Worked examples live in [`examples/`](examples/).

### Basic VPN Gateway

```hcl
module "vpn_gateway" {
  source = "git::https://github.com/AIRCLOUD-PL/azure-vpn-gateway-module.git?ref=v1.0.0"

  resource_group_name = "rg-vpn-gateway"
  location           = "East US"
  environment       = "prod"

  sku               = "VpnGw1"
  active_active     = false
  enable_bgp        = false

  public_ip_configurations = {
    pip1 = {
      name              = "pip-vpn-gw-1"
      allocation_method = "Static"
      sku               = "Standard"
    }
  }

  ip_configurations = [
    {
      name                          = "vnetGatewayConfig"
      public_ip_address_id          = "" # Will be set by dependency
      private_ip_address_allocation = "Dynamic"
      subnet_id                     = azurerm_subnet.gateway.id
    }
  ]

  tags = {
    Environment = "prod"
  }
}
```

### Enterprise VPN Gateway with BGP and Active-Active

```hcl
module "vpn_gateway_enterprise" {
  source = "git::https://github.com/AIRCLOUD-PL/azure-vpn-gateway-module.git?ref=v1.0.0"

  resource_group_name = "rg-vpn-gateway"
  location           = "East US"
  environment       = "prod"
  vpn_gateway_name   = "vpn-gw-enterprise"

  sku           = "VpnGw2AZ"
  active_active = true
  enable_bgp    = true
  bgp_asn       = 65001

  bgp_peering_addresses = [
    {
      ip_configuration_name = "vnetGatewayConfig1"
      apipa_addresses       = ["169.254.21.1"]
    },
    {
      name                          = "vnetGatewayConfig2"
      apipa_addresses       = ["169.254.21.5"]
    }
  ]

  public_ip_configurations = {
    pip1 = {
      name              = "pip-vpn-gw-1"
      allocation_method = "Static"
      sku               = "Standard"
      zones             = ["1", "2", "3"]
    }
    pip2 = {
      name              = "pip-vpn-gw-2"
      allocation_method = "Static"
      sku               = "Standard"
      zones             = ["1", "2", "3"]
    }
  }

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

  # Point-to-Site VPN
  vpn_client_configuration = {
    address_space = ["192.168.100.0/24"]
    root_certificates = [
      {
        name             = "P2SRootCert"
        public_cert_data = "MIIC5jCCAc6gAwIBAgITQ...[Base64 encoded certificate]"
      }
    ]
    vpn_client_protocols = ["IkeV2", "OpenVPN"]
    vpn_auth_types      = ["Certificate"]
  }

  # Site-to-Site VPN
  local_network_gateways = {
    "onprem-office" = {
      name            = "lng-onprem-office"
      gateway_address = "203.0.113.1"
      address_space   = ["192.168.1.0/24"]
      bgp_settings = {
        asn                 = 65002
        bgp_peering_address = "203.0.113.2"
      }
    }
  }

  vpn_connections = {
    "office-connection" = {
      name                      = "vpn-conn-office"
      type                      = "IPsec"
      local_network_gateway_id  = module.vpn_gateway.local_network_gateway_ids["onprem-office"]
      shared_key                = "SuperSecretKey123!"
      enable_bgp                = true
      ipsec_policy = {
        dh_group         = "DHGroup14"
        ike_encryption   = "AES256"
        ike_integrity    = "SHA256"
        ipsec_encryption = "AES256"
        ipsec_integrity  = "SHA256"
        pfs_group        = "PFS2048"
      }
    }
  }

  # Security and Monitoring
  create_gateway_nsg = true
  diagnostic_settings = {
    "diagnostics" = {
      name                       = "diag-vpn-gateway"
      log_analytics_workspace_id = azurerm_log_analytics_workspace.example.id
      logs = [
        { category = "GatewayDiagnosticLog" },
        { category = "TunnelDiagnosticLog" },
        { category = "RouteDiagnosticLog" }
      ]
      metrics = [
        { category = "AllMetrics", enabled = true }
      ]
    }
  }

  # Azure Policy
  enable_policy_assignments = true
  enable_custom_policies    = true
  log_analytics_workspace_id = azurerm_log_analytics_workspace.example.id

  tags = {
    Environment = "prod"
    Compliance  = "sox-pci"
  }
}
```

## Testing

The module includes comprehensive Terratest coverage:

```bash
# Run all tests
cd test
go test -v

# Run specific test
go test -v -run TestVpnGatewayModule

# Run tests in parallel
go test -v -parallel 3
```

Test scenarios include:
- Basic VPN Gateway deployment
- BGP-enabled gateway with active-active
- VPN connections with IPsec policies
- Public IP and NSG validation
- Output validation

## Security Considerations

- Use IKEv2 protocol for enhanced security
- Implement strong pre-shared keys (minimum 32 characters)
- Enable IPsec policies with AES256 encryption
- Use certificate-based authentication for P2S VPN
- Enable Azure Policy assignments for compliance
- Configure diagnostic settings for monitoring
- Use zone-redundant SKUs for high availability

## Cost Optimization

- Choose appropriate SKU based on throughput requirements
- Use Basic SKU for development/testing environments
- Enable active-active only when required for high availability
- Configure appropriate diagnostic retention periods

## Troubleshooting

### Common Issues

1. **GatewaySubnet size**: Must be at least /27 (32 IPs minimum)
2. **BGP conflicts**: Ensure unique ASN across connected networks
3. **IPsec policy mismatch**: Verify matching policies on both sides
4. **Zone availability**: Not all regions support zone-redundant SKUs

### Diagnostic Logs

Enable diagnostic settings to collect:
- Gateway diagnostic logs
- Tunnel diagnostic logs
- Route diagnostic logs
- IKE diagnostic logs

## Contributing

1. Follow the existing code style and patterns
2. Add tests for new features
3. Update documentation
4. Ensure backward compatibility

## License

This module is licensed under the MIT License.

## Reference

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 4.81.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_local_network_gateway.local_gateways](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/local_network_gateway) | resource |
| [azurerm_monitor_diagnostic_setting.vpn_gateway_diagnostics](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_network_security_group.gateway_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_policy_definition.vpn_gateway_bandwidth_policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/policy_definition) | resource |
| [azurerm_public_ip.vpn_gateway_pips](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_subscription_policy_assignment.vpn_connection_ikev2](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subscription_policy_assignment) | resource |
| [azurerm_subscription_policy_assignment.vpn_connection_ipsec](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subscription_policy_assignment) | resource |
| [azurerm_subscription_policy_assignment.vpn_gateway_bandwidth_assignment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subscription_policy_assignment) | resource |
| [azurerm_subscription_policy_assignment.vpn_gateway_diagnostics](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subscription_policy_assignment) | resource |
| [azurerm_subscription_policy_assignment.vpn_gateway_sku_policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subscription_policy_assignment) | resource |
| [azurerm_subscription_policy_assignment.vpn_gateway_zones](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subscription_policy_assignment) | resource |
| [azurerm_virtual_network_gateway.vpn_gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway) | resource |
| [azurerm_virtual_network_gateway_connection.connections](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway_connection) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_active_active"></a> [active\_active](#input\_active\_active) | Enable active-active configuration | `bool` | `false` | no |
| <a name="input_bgp_asn"></a> [bgp\_asn](#input\_bgp\_asn) | BGP ASN for the VPN Gateway | `number` | `65515` | no |
| <a name="input_bgp_peering_addresses"></a> [bgp\_peering\_addresses](#input\_bgp\_peering\_addresses) | BGP peering addresses configuration | <pre>list(object({<br/>    ip_configuration_name = string<br/>    apipa_addresses       = optional(list(string))<br/>  }))</pre> | `[]` | no |
| <a name="input_create_gateway_nsg"></a> [create\_gateway\_nsg](#input\_create\_gateway\_nsg) | Create NSG for gateway subnet | `bool` | `true` | no |
| <a name="input_diagnostic_settings"></a> [diagnostic\_settings](#input\_diagnostic\_settings) | Diagnostic settings configurations | <pre>map(object({<br/>    name                       = string<br/>    log_analytics_workspace_id = string<br/>    logs = list(object({<br/>      category = string<br/>    }))<br/>    metrics = list(object({<br/>      category = string<br/>      enabled  = bool<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_enable_bgp"></a> [enable\_bgp](#input\_enable\_bgp) | Enable BGP for the VPN Gateway | `bool` | `false` | no |
| <a name="input_enable_custom_policies"></a> [enable\_custom\_policies](#input\_enable\_custom\_policies) | Enable custom Azure Policy definitions | `bool` | `false` | no |
| <a name="input_enable_policy_assignments"></a> [enable\_policy\_assignments](#input\_enable\_policy\_assignments) | Enable Azure Policy assignments for VPN Gateway security | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., prod, dev, test) | `string` | n/a | yes |
| <a name="input_ip_configurations"></a> [ip\_configurations](#input\_ip\_configurations) | IP configurations for the VPN Gateway | <pre>list(object({<br/>    name                          = string<br/>    public_ip_address_id          = string<br/>    private_ip_address_allocation = string<br/>    subnet_id                     = string<br/>  }))</pre> | n/a | yes |
| <a name="input_local_network_gateways"></a> [local\_network\_gateways](#input\_local\_network\_gateways) | Local network gateway configurations for S2S VPN | <pre>map(object({<br/>    name            = string<br/>    gateway_address = string<br/>    address_space   = list(string)<br/>    bgp_settings = optional(object({<br/>      asn                 = number<br/>      bgp_peering_address = string<br/>      peer_weight         = optional(number, 0)<br/>    }))<br/>    tags = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region where resources will be created | `string` | n/a | yes |
| <a name="input_log_analytics_workspace_id"></a> [log\_analytics\_workspace\_id](#input\_log\_analytics\_workspace\_id) | Log Analytics Workspace ID for diagnostic settings | `string` | `null` | no |
| <a name="input_minimum_sku"></a> [minimum\_sku](#input\_minimum\_sku) | Minimum required VPN Gateway SKU for custom policy | `string` | `"VpnGw2"` | no |
| <a name="input_naming_prefix"></a> [naming\_prefix](#input\_naming\_prefix) | Prefix for VPN Gateway naming | `string` | `"vpn-gateway"` | no |
| <a name="input_public_ip_configurations"></a> [public\_ip\_configurations](#input\_public\_ip\_configurations) | Public IP configurations for VPN Gateway | <pre>map(object({<br/>    name                    = string<br/>    allocation_method       = string<br/>    sku                     = string<br/>    zones                   = optional(list(string))<br/>    ddos_protection_plan_id = optional(string)<br/>    tags                    = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group | `string` | n/a | yes |
| <a name="input_sku"></a> [sku](#input\_sku) | SKU of the VPN Gateway | `string` | `"VpnGw1"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vpn_client_configuration"></a> [vpn\_client\_configuration](#input\_vpn\_client\_configuration) | VPN client configuration for P2S VPN | <pre>object({<br/>    address_space = list(string)<br/>    root_certificates = list(object({<br/>      name             = string<br/>      public_cert_data = string<br/>    }))<br/>    revoked_certificates = optional(list(object({<br/>      name          = string<br/>      serial_number = string<br/>      thumbprint    = string<br/>    })), [])<br/>    radius_server = optional(object({<br/>      address = string<br/>      secret  = string<br/>      score   = optional(number, 30)<br/>    }))<br/>    vpn_client_protocols = optional(list(string), ["IkeV2"])<br/>    vpn_auth_types       = optional(list(string), ["Certificate"])<br/>  })</pre> | `null` | no |
| <a name="input_vpn_connections"></a> [vpn\_connections](#input\_vpn\_connections) | VPN connection configurations | <pre>map(object({<br/>    name                               = string<br/>    type                               = string<br/>    connection_mode                    = optional(string, "Default")<br/>    local_network_gateway_id           = optional(string)<br/>    express_route_circuit_id           = optional(string)<br/>    peer_virtual_network_gateway_id    = optional(string)<br/>    shared_key                         = string<br/>    connection_protocol                = optional(string, "IKEv2")<br/>    dpd_timeout_seconds                = optional(number, 45)<br/>    enable_bgp                         = optional(bool, false)<br/>    use_policy_based_traffic_selectors = optional(bool, false)<br/>    routing = optional(object({<br/>      weight = number<br/>    }))<br/>    ipsec_policy = optional(object({<br/>      dh_group         = string<br/>      ike_encryption   = string<br/>      ike_integrity    = string<br/>      ipsec_encryption = string<br/>      ipsec_integrity  = string<br/>      pfs_group        = string<br/>      sa_datasize      = optional(number)<br/>      sa_lifetime      = optional(number)<br/>    }))<br/>    traffic_selector_policy = optional(list(object({<br/>      local_address_cidrs  = list(string)<br/>      remote_address_cidrs = list(string)<br/>    })), [])<br/>    tags = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_vpn_gateway_name"></a> [vpn\_gateway\_name](#input\_vpn\_gateway\_name) | Name of the VPN Gateway. If null, will be auto-generated. | `string` | `null` | no |
| <a name="input_vpn_type"></a> [vpn\_type](#input\_vpn\_type) | VPN type for the gateway | `string` | `"RouteBased"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_gateway_nsg_id"></a> [gateway\_nsg\_id](#output\_gateway\_nsg\_id) | ID of the gateway subnet NSG |
| <a name="output_local_network_gateway_ids"></a> [local\_network\_gateway\_ids](#output\_local\_network\_gateway\_ids) | IDs of the local network gateways |
| <a name="output_public_ip_addresses"></a> [public\_ip\_addresses](#output\_public\_ip\_addresses) | Public IP addresses |
| <a name="output_public_ip_ids"></a> [public\_ip\_ids](#output\_public\_ip\_ids) | IDs of the public IP addresses |
| <a name="output_shared_keys"></a> [shared\_keys](#output\_shared\_keys) | VPN connection shared keys |
| <a name="output_vpn_client_configuration"></a> [vpn\_client\_configuration](#output\_vpn\_client\_configuration) | VPN client configuration details |
| <a name="output_vpn_connection_ids"></a> [vpn\_connection\_ids](#output\_vpn\_connection\_ids) | IDs of the VPN connections |
| <a name="output_vpn_gateway_bgp_asn"></a> [vpn\_gateway\_bgp\_asn](#output\_vpn\_gateway\_bgp\_asn) | BGP ASN of the VPN Gateway |
| <a name="output_vpn_gateway_id"></a> [vpn\_gateway\_id](#output\_vpn\_gateway\_id) | ID of the VPN Gateway |
| <a name="output_vpn_gateway_name"></a> [vpn\_gateway\_name](#output\_vpn\_gateway\_name) | Name of the VPN Gateway |
| <a name="output_vpn_gateway_public_ips"></a> [vpn\_gateway\_public\_ips](#output\_vpn\_gateway\_public\_ips) | Public IP addresses of the VPN Gateway |
<!-- END_TF_DOCS -->

---

## Part of the AIRCLOUD Azure module catalog

Browse all modules with usage snippets in the [module catalog](https://aircloud-pl.github.io/) or on [github.com/AIRCLOUD-PL](https://github.com/AIRCLOUD-PL). Built and maintained by [AIRCLOUD](https://aircloud.com.pl): DevOps, cloud and AI engineering. Need a hand with Azure landing zones or platform engineering? See [aircloud.com.pl/consulting](https://aircloud.com.pl/consulting).
