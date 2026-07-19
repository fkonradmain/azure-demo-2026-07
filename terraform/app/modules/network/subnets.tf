resource "azurerm_subnet" "aks_node" {
  name             = "aks-node-subnet-${var.app_stage}"
  # address_prefixes = ["10.100.1.0/24"]
  address_prefixes = ["10.240.0.0/16"] # according to https://learn.microsoft.com/en-us/azure/aks/private-clusters?tabs=default-basic-networking%2Cportal%2Cazure-portal&pivots=terraform#create-a-private-aks-cluster-with-advanced-networking
  # security_group   = azurerm_network_security_group.app_vnet_nsg.id # TODO: check where we actually need the security groups
  resource_group_name = var.azure_rg_name
  virtual_network_name = azurerm_virtual_network.app_vnet.name
}

resource "azurerm_subnet" "aks_api" {
  name                 = "aks-api-subnet-${var.app_stage}"
  address_prefixes = ["10.100.2.0/24"]
  # security_group   = azurerm_network_security_group.app_vnet_nsg.id # TODO: check where we actually need the security groups
  resource_group_name = var.azure_rg_name
  virtual_network_name = azurerm_virtual_network.app_vnet.name

  # delegation {
  #   name = "aks-delegation"

  #   service_delegation {
  #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
  #     name    = "Microsoft.ContainerService/managedClusters"
  #   }
  # }
}

resource "azurerm_subnet" "aks_systemnode" {
  name                 = "aks-systemnode-subnet-${var.app_stage}"
    resource_group_name = var.azure_rg_name
  virtual_network_name = azurerm_virtual_network.app_vnet.name
  address_prefixes     = ["10.100.3.0/24"]

  lifecycle {
    ignore_changes = [
      delegation
    ]
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name             = "private-endpoints-subnet-${var.app_stage}"
  address_prefixes = ["10.100.0.0/24"]
  # security_group   = azurerm_network_security_group.app_vnet_nsg.id # TODO: check where we actually need the security groups
  resource_group_name = var.azure_rg_name
  virtual_network_name = azurerm_virtual_network.app_vnet.name
  private_endpoint_network_policies = "Enabled" # Consider changing this to NetworkSecurityGroupEnabled or maybe set it to false
}

# Create a list of all subnets for iterating through all of them
locals {
  subnets = {
        "aks_node" = { "id" = azurerm_subnet.aks_node.id }
        "aks_api" = { "id" = azurerm_subnet.aks_api.id }
        "aks_systemnode" = { "id" = azurerm_subnet.aks_systemnode.id }
        "private_endpoints" = { "id" = azurerm_subnet.private_endpoints.id }
    }
}

# # Associate all subnets with the egress route table
# resource "azurerm_subnet_route_table_association" "subnet_egress_table" {
#   for_each = { for _, item in local.subnets : item.id => item }
#   subnet_id = each.value.id
#   route_table_id = azurerm_route_table.app_route_table_with_egress.id
# }
# 
# # Associate all subnets with the default network security group
# resource "azurerm_subnet_network_security_group_association" "app_vnet_nsg" {
#   for_each = { for _, item in local.subnets : item.id => item }
#   subnet_id = each.value.id
#   network_security_group_id = azurerm_network_security_group.app_vnet_nsg.id
# }
