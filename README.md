# Azure VPN Gateway Module

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

### Basic VPN Gateway

```hcl
module "vpn_gateway" {
  source = "./modules/network/vpn-gateway"

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
  source = "./modules/network/vpn-gateway"

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

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| azurerm | >= 3.80.0 |

## Providers

| Name | Version |
|------|---------|
| azurerm | >= 3.80.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| resource_group_name | Name of the resource group | `string` | n/a | yes |
| location | Azure region | `string` | n/a | yes |
| environment | Environment name | `string` | n/a | yes |
| vpn_gateway_name | Name of the VPN Gateway | `string` | `null` | no |
| sku | VPN Gateway SKU | `string` | `"VpnGw1"` | no |
| active_active | Enable active-active configuration | `bool` | `false` | no |
| enable_bgp | Enable BGP | `bool` | `false` | no |
| bgp_asn | BGP ASN | `number` | `65515` | no |
| bgp_peering_addresses | BGP peering addresses | `list(object({...}))` | `[]` | no |
| ip_configurations | IP configurations | `list(object({...}))` | n/a | yes |
| vpn_client_configuration | P2S VPN configuration | `object({...})` | `null` | no |
| local_network_gateways | Local network gateways | `map(object({...}))` | `{}` | no |
| vpn_connections | VPN connections | `map(object({...}))` | `{}` | no |
| public_ip_configurations | Public IP configurations | `map(object({...}))` | `{}` | no |
| create_gateway_nsg | Create NSG for gateway subnet | `bool` | `true` | no |
| diagnostic_settings | Diagnostic settings | `map(object({...}))` | `{}` | no |
| enable_policy_assignments | Enable Azure Policy assignments | `bool` | `false` | no |
| enable_custom_policies | Enable custom policies | `bool` | `false` | no |
| log_analytics_workspace_id | Log Analytics Workspace ID | `string` | `null` | no |
| minimum_sku | Minimum SKU for custom policy | `string` | `"VpnGw2"` | no |
| tags | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpn_gateway_id | VPN Gateway resource ID |
| vpn_gateway_name | VPN Gateway name |
| public_ip_ids | Public IP resource IDs |
| public_ip_addresses | Public IP addresses |
| local_network_gateway_ids | Local Network Gateway IDs |
| vpn_connection_ids | VPN connection IDs |
| bgp_peering_addresses | BGP peering addresses |
| vpn_client_configuration | P2S VPN client configuration |
| gateway_nsg_id | Gateway NSG ID |
| gateway_nsg_name | Gateway NSG name |

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
## Requirements

No requirements.

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

No inputs.

## Outputs

No outputs.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
