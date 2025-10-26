package test

import (
	"testing"
	"fmt"
	"strings"

	"github.com/gruntwork-io/terratest/modules/azure"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestVpnGatewayModule(t *testing.T) {
	t.Parallel()

	// Generate unique names for resources
	uniqueId := random.UniqueId()
	resourceGroupName := fmt.Sprintf("rg-vpn-gateway-test-%s", uniqueId)
	vpnGatewayName := fmt.Sprintf("vpn-gw-test-%s", uniqueId)
	location := "East US"

	// Configure Terraform options
	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		Vars: map[string]interface{}{
			"resource_group_name": resourceGroupName,
			"location":           location,
			"environment":       "test",
			"vpn_gateway_name":   vpnGatewayName,
			"sku":               "VpnGw1",
			"active_active":     false,
			"enable_bgp":        false,
			"create_gateway_nsg": true,
			"tags": map[string]string{
				"Environment": "test",
				"Module":      "vpn-gateway",
			},
			"public_ip_configurations": map[string]interface{}{
				"pip1": map[string]interface{}{
					"name":              "pip-vpn-gw-1",
					"allocation_method": "Static",
					"sku":               "Standard",
					"zones":             []string{"1", "2", "3"},
				},
			},
			"ip_configurations": []map[string]interface{}{
				{
					"name":                          "vnetGatewayConfig",
					"public_ip_address_id":          "", // Will be set by dependency
					"private_ip_address_allocation": "Dynamic",
					"subnet_id":                     "", // Will be set by dependency
				},
			},
		},
	}

	// Clean up resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Deploy resources
	terraform.InitAndApply(t, terraformOptions)

	// Validate VPN Gateway
	validateVpnGateway(t, terraformOptions, vpnGatewayName, resourceGroupName)

	// Validate Public IP
	validatePublicIP(t, terraformOptions, resourceGroupName)

	// Validate NSG
	validateNSG(t, terraformOptions, resourceGroupName)

	// Validate outputs
	validateOutputs(t, terraformOptions)
}

func TestVpnGatewayWithBGP(t *testing.T) {
	t.Parallel()

	uniqueId := random.UniqueId()
	resourceGroupName := fmt.Sprintf("rg-vpn-gateway-bgp-test-%s", uniqueId)
	vpnGatewayName := fmt.Sprintf("vpn-gw-bgp-test-%s", uniqueId)
	location := "East US"

	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		Vars: map[string]interface{}{
			"resource_group_name": resourceGroupName,
			"location":           location,
			"environment":       "test",
			"vpn_gateway_name":   vpnGatewayName,
			"sku":               "VpnGw1",
			"active_active":     true,
			"enable_bgp":        true,
			"bgp_asn":           65001,
			"create_gateway_nsg": true,
			"tags": map[string]string{
				"Environment": "test",
				"Module":      "vpn-gateway-bgp",
			},
			"public_ip_configurations": map[string]interface{}{
				"pip1": map[string]interface{}{
					"name":              "pip-vpn-gw-1",
					"allocation_method": "Static",
					"sku":               "Standard",
					"zones":             []string{"1", "2", "3"},
				},
				"pip2": map[string]interface{}{
					"name":              "pip-vpn-gw-2",
					"allocation_method": "Static",
					"sku":               "Standard",
					"zones":             []string{"1", "2", "3"},
				},
			},
			"ip_configurations": []map[string]interface{}{
				{
					"name":                          "vnetGatewayConfig1",
					"public_ip_address_id":          "",
					"private_ip_address_allocation": "Dynamic",
					"subnet_id":                     "",
				},
				{
					"name":                          "vnetGatewayConfig2",
					"public_ip_address_id":          "",
					"private_ip_address_allocation": "Dynamic",
					"subnet_id":                     "",
				},
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	validateVpnGatewayWithBGP(t, terraformOptions, vpnGatewayName, resourceGroupName)
}

func TestVpnGatewayWithConnections(t *testing.T) {
	t.Parallel()

	uniqueId := random.UniqueId()
	resourceGroupName := fmt.Sprintf("rg-vpn-gateway-conn-test-%s", uniqueId)
	vpnGatewayName := fmt.Sprintf("vpn-gw-conn-test-%s", uniqueId)
	localNetworkGatewayName := fmt.Sprintf("lng-test-%s", uniqueId)
	location := "East US"

	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		Vars: map[string]interface{}{
			"resource_group_name": resourceGroupName,
			"location":           location,
			"environment":       "test",
			"vpn_gateway_name":   vpnGatewayName,
			"sku":               "VpnGw1",
			"active_active":     false,
			"enable_bgp":        false,
			"create_gateway_nsg": true,
			"tags": map[string]string{
				"Environment": "test",
				"Module":      "vpn-gateway-connections",
			},
			"public_ip_configurations": map[string]interface{}{
				"pip1": map[string]interface{}{
					"name":              "pip-vpn-gw-1",
					"allocation_method": "Static",
					"sku":               "Standard",
				},
			},
			"ip_configurations": []map[string]interface{}{
				{
					"name":                          "vnetGatewayConfig",
					"public_ip_address_id":          "",
					"private_ip_address_allocation": "Dynamic",
					"subnet_id":                     "",
				},
			},
			"local_network_gateways": map[string]interface{}{
				localNetworkGatewayName: map[string]interface{}{
					"name":            localNetworkGatewayName,
					"gateway_address": "203.0.113.1",
					"address_space":   []string{"10.0.0.0/16"},
				},
			},
			"vpn_connections": map[string]interface{}{
				"connection1": map[string]interface{}{
					"name":                      "vpn-conn-1",
					"type":                      "IPsec",
					"local_network_gateway_id": "", // Will be set by dependency
					"shared_key":                "SuperSecretKey123!",
					"connection_protocol":       "IKEv2",
					"ipsec_policy": map[string]interface{}{
						"dh_group":         "DHGroup14",
						"ike_encryption":   "AES256",
						"ike_integrity":    "SHA256",
						"ipsec_encryption": "AES256",
						"ipsec_integrity":  "SHA256",
						"pfs_group":        "PFS14",
					},
				},
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	validateVpnGatewayConnections(t, terraformOptions, vpnGatewayName, localNetworkGatewayName, resourceGroupName)
}

func validateVpnGateway(t *testing.T, terraformOptions *terraform.Options, vpnGatewayName, resourceGroupName string) {
	// Get VPN Gateway details
	vpnGateway := azure.GetVirtualNetworkGateway(t, vpnGatewayName, resourceGroupName, "")

	// Validate basic properties
	assert.Equal(t, vpnGatewayName, vpnGateway.Name)
	assert.Equal(t, "VpnGw1", vpnGateway.SKU.Name)
	assert.Equal(t, "RouteBased", vpnGateway.VPNType)
	assert.False(t, vpnGateway.EnableBGP)
	assert.False(t, vpnGateway.ActiveActive)
}

func validateVpnGatewayWithBGP(t *testing.T, terraformOptions *terraform.Options, vpnGatewayName, resourceGroupName string) {
	vpnGateway := azure.GetVirtualNetworkGateway(t, vpnGatewayName, resourceGroupName, "")

	assert.Equal(t, vpnGatewayName, vpnGateway.Name)
	assert.Equal(t, "VpnGw1", vpnGateway.SKU.Name)
	assert.True(t, vpnGateway.EnableBGP)
	assert.Equal(t, int64(65001), vpnGateway.BGPSettings.ASN)
	assert.True(t, vpnGateway.ActiveActive)
}

func validateVpnGatewayConnections(t *testing.T, terraformOptions *terraform.Options, vpnGatewayName, localNetworkGatewayName, resourceGroupName string) {
	// Validate Local Network Gateway
	localNetworkGateway := azure.GetLocalNetworkGateway(t, localNetworkGatewayName, resourceGroupName, "")
	assert.Equal(t, localNetworkGatewayName, localNetworkGateway.Name)
	assert.Equal(t, "203.0.113.1", localNetworkGateway.GatewayAddress)

	// Validate VPN Connection exists (using output)
	connectionName := terraform.Output(t, terraformOptions, "vpn_connection_names")
	assert.NotEmpty(t, connectionName)
}

func validatePublicIP(t *testing.T, terraformOptions *terraform.Options, resourceGroupName string) {
	// Get Public IP names from output
	pipNames := terraform.Output(t, terraformOptions, "public_ip_names")
	require.NotEmpty(t, pipNames)

	// Parse the list of names
	names := strings.Split(strings.Trim(pipNames, "[]"), ",")
	for _, name := range names {
		name = strings.TrimSpace(strings.Trim(name, "\""))
		if name != "" {
			pip := azure.GetPublicIP(t, name, resourceGroupName, "")
			assert.Equal(t, "Standard", pip.SKU.Name)
			assert.Equal(t, "Static", pip.PublicIPAllocationMethod)
		}
	}
}

func validateNSG(t *testing.T, terraformOptions *terraform.Options, resourceGroupName string) {
	// Get NSG name from output
	nsgName := terraform.Output(t, terraformOptions, "gateway_nsg_name")
	if nsgName != "" {
		nsg := azure.GetNetworkSecurityGroup(t, nsgName, resourceGroupName, "")
		assert.NotNil(t, nsg)
		assert.Contains(t, nsg.Name, "nsg-gateway")
	}
}

func validateOutputs(t *testing.T, terraformOptions *terraform.Options) {
	// Validate required outputs
	vpnGatewayId := terraform.Output(t, terraformOptions, "vpn_gateway_id")
	assert.NotEmpty(t, vpnGatewayId)
	assert.Contains(t, vpnGatewayId, "Microsoft.Network/virtualNetworkGateways")

	vpnGatewayName := terraform.Output(t, terraformOptions, "vpn_gateway_name")
	assert.NotEmpty(t, vpnGatewayName)

	resourceGroupName := terraform.Output(t, terraformOptions, "resource_group_name")
	assert.NotEmpty(t, resourceGroupName)

	location := terraform.Output(t, terraformOptions, "location")
	assert.NotEmpty(t, location)
}