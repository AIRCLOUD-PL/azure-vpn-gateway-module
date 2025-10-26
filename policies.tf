# Azure Policy Assignments for VPN Gateway Security and Compliance

# Require VPN Gateways to use specific SKU for security
resource "azurerm_subscription_policy_assignment" "vpn_gateway_sku_policy" {
  count = var.enable_policy_assignments ? 1 : 0

  name                 = "vpn-gateway-sku-${var.environment}"
  subscription_id      = data.azurerm_client_config.current.subscription_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/8c3b13d8-7395-47c4-82eb-7c2a1d35d712" # VPN Gateways should use only IKEv2

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
    allowedSKUs = {
      value = ["VpnGw1", "VpnGw2", "VpnGw3", "VpnGw1AZ", "VpnGw2AZ", "VpnGw3AZ"]
    }
  })
}

# Require VPN connections to use IKEv2
resource "azurerm_subscription_policy_assignment" "vpn_connection_ikev2" {
  count = var.enable_policy_assignments ? 1 : 0

  name                 = "vpn-connection-ikev2-${var.environment}"
  subscription_id      = data.azurerm_client_config.current.subscription_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/8c3b13d8-7395-47c4-82eb-7c2a1d35d712" # VPN Gateways should use only IKEv2

  parameters = jsonencode({
    effect = {
      value = "Deny"
    }
  })
}

# Require diagnostic settings for VPN Gateways
resource "azurerm_subscription_policy_assignment" "vpn_gateway_diagnostics" {
  count = var.enable_policy_assignments ? 1 : 0

  name                 = "vpn-gateway-diagnostics-${var.environment}"
  subscription_id      = data.azurerm_client_config.current.subscription_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/7c127454-8e0e-4072-87f8-1a11d9caf7f4" # Diagnostic settings should be enabled on VPN Gateways

  parameters = jsonencode({
    effect = {
      value = "DeployIfNotExists"
    }
    profileName = {
      value = "setByPolicy"
    }
    logAnalyticsWorkspaceId = {
      value = var.log_analytics_workspace_id
    }
    metricsEnabled = {
      value = "true"
    }
    logsEnabled = {
      value = "true"
    }
  })
}

# Require VPN Gateways to have availability zones
resource "azurerm_subscription_policy_assignment" "vpn_gateway_zones" {
  count = var.enable_policy_assignments ? 1 : 0

  name                 = "vpn-gateway-zones-${var.environment}"
  subscription_id      = data.azurerm_client_config.current.subscription_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/8c3b13d8-7395-47c4-82eb-7c2a1d35d712" # VPN Gateways should be deployed with availability zones

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}

# Custom policy for VPN Gateway bandwidth validation
resource "azurerm_policy_definition" "vpn_gateway_bandwidth_policy" {
  count = var.enable_custom_policies ? 1 : 0

  name         = "vpn-gateway-bandwidth-validation"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "VPN Gateways should have minimum bandwidth"

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Network/virtualNetworkGateways"
        },
        {
          field = "Microsoft.Network/virtualNetworkGateways/sku.name"
          in    = ["Basic", "VpnGw1", "VpnGw1AZ"]
        }
      ]
    }
    then = {
      effect = "Deny"
    }
  })

  parameters = jsonencode({
    minimumSKU = {
      type = "String"
      metadata = {
        displayName = "Minimum SKU"
        description = "Minimum required VPN Gateway SKU"
      }
      allowedValues = ["VpnGw2", "VpnGw3", "VpnGw2AZ", "VpnGw3AZ"]
      defaultValue  = "VpnGw2"
    }
  })
}

# Policy assignment for custom bandwidth policy
resource "azurerm_subscription_policy_assignment" "vpn_gateway_bandwidth_assignment" {
  count = var.enable_custom_policies ? 1 : 0

  name                 = "vpn-gateway-bandwidth-${var.environment}"
  subscription_id      = data.azurerm_client_config.current.subscription_id
  policy_definition_id = azurerm_policy_definition.vpn_gateway_bandwidth_policy[0].id

  parameters = jsonencode({
    minimumSKU = {
      value = var.minimum_sku
    }
  })
}

# Require IPsec policies on VPN connections
resource "azurerm_subscription_policy_assignment" "vpn_connection_ipsec" {
  count = var.enable_policy_assignments ? 1 : 0

  name                 = "vpn-connection-ipsec-${var.environment}"
  subscription_id      = data.azurerm_client_config.current.subscription_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/8c3b13d8-7395-47c4-82eb-7c2a1d35d712" # VPN connections should have IPsec policies

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}

# Data source for client configuration
data "azurerm_client_config" "current" {}