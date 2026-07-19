# Subnets were designed according to documentation available at
# https://learn.microsoft.com/en-us/azure/aks/api-server-vnet-integration#aks-standard-bring-your-own-vnet

# Subnet for nodes and kubernetes workloads
resource "azurerm_subnet" "aks_node" {
  name                 = "aks-node-subnet-${var.app_stage}"
  address_prefixes     = ["172.19.1.0/24"]
  resource_group_name  = var.azure_rg_name
  virtual_network_name = azurerm_virtual_network.app_vnet.name
}

# Subnet for Kubernetes services and API
resource "azurerm_subnet" "aks_api" {
  name                 = "aks-api-subnet-${var.app_stage}"
  address_prefixes     = ["172.19.0.0/28"]
  resource_group_name  = var.azure_rg_name
  virtual_network_name = azurerm_virtual_network.app_vnet.name

  # Service Delegation to managed Clusters
  # See https://learn.microsoft.com/en-us/azure/aks/api-server-vnet-integration#aks-standard-bring-your-own-vnet
  delegation {
    name = "aks-delegation"

    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      name    = "Microsoft.ContainerService/managedClusters"
    }
  }
}


resource "azurerm_subnet" "private_endpoints" {
  name                              = "private-endpoints-subnet-${var.app_stage}"
  address_prefixes                  = ["172.19.3.0/24"]
  resource_group_name               = var.azure_rg_name
  virtual_network_name              = azurerm_virtual_network.app_vnet.name
  private_endpoint_network_policies = "Disabled" # TODO: find out why they have to be specifically disabled
}

# Create a list of all subnets for iterating through all of them
locals {
  subnets = {
    "aks_node"          = { "id" = azurerm_subnet.aks_node.id }
    "aks_api"           = { "id" = azurerm_subnet.aks_api.id }
    "private_endpoints" = { "id" = azurerm_subnet.private_endpoints.id }
  }
}

# Associate all subnets with the default network security group
resource "azurerm_subnet_network_security_group_association" "app_vnet_nsg_aks_node" {
  subnet_id                 = azurerm_subnet.aks_node.id
  network_security_group_id = azurerm_network_security_group.app_vnet_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "app_vnet_nsg_aks_api" {
  subnet_id                 = azurerm_subnet.aks_api.id
  network_security_group_id = azurerm_network_security_group.app_vnet_nsg.id
}
resource "azurerm_subnet_network_security_group_association" "app_vnet_nsg_private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.app_vnet_nsg.id
}
