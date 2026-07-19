resource "azurerm_network_security_group" "app_vnet_nsg" {
  name                = "app-vnet-nsg-${var.app_stage}"
  location            = var.azure_location
  resource_group_name = var.azure_rg_name

  security_rule {
    name                       = "allow-all-outbound"
    priority                   = 1000
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-inter-subnet-traffic"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/8" # changed according to https://learn.microsoft.com/en-us/azure/aks/private-clusters?tabs=default-basic-networking%2Cportal%2Cazure-portal&pivots=terraform#create-a-private-aks-cluster-with-advanced-networking
    destination_address_prefix = "10.0.0.0/8" # changed according to https://learn.microsoft.com/en-us/azure/aks/private-clusters?tabs=default-basic-networking%2Cportal%2Cazure-portal&pivots=terraform#create-a-private-aks-cluster-with-advanced-networking
    # source_address_prefix      = "10.100.0.0/16" 
    # destination_address_prefix = "10.100.0.0/16"
  }
}

resource "azurerm_virtual_network" "app_vnet" {
  name                = "app-vnet-${var.app_stage}"
  location            = var.azure_location
  resource_group_name = var.azure_rg_name
  # address_space       = ["10.100.0.0/16"]
  # dns_servers         = ["10.100.0.4", "10.100.0.5"]
  address_space       = ["10.0.0.0/8"] # changed according to https://learn.microsoft.com/en-us/azure/aks/private-clusters?tabs=default-basic-networking%2Cportal%2Cazure-portal&pivots=terraform#create-a-private-aks-cluster-with-advanced-networking
}

resource "azurerm_route_table" "app_route_table_with_egress" {
  name                = "app-route-table-egress-${var.app_stage}"
  location            = var.azure_location
  resource_group_name = var.azure_rg_name

  route {
    name           = "vnet-local"
    # address_prefix = "10.100.0.0/16"
    address_prefix = "10.0.0.0/8" # Changed according to https://learn.microsoft.com/en-us/azure/aks/private-clusters?tabs=default-basic-networking%2Cportal%2Cazure-portal&pivots=terraform#create-a-private-aks-cluster-with-advanced-networking
    next_hop_type  = "VnetLocal"
  }

  route {
    name           = "internet-direct-egress"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }
}

# Create a DNS zone for all private link connections
resource "azurerm_private_dns_zone" "private_endpoints_dns" {
  name                = "privatelink-${var.app_stage}.azure.net"
    resource_group_name = var.azure_rg_name
}

# Connect DNS zone to the whole vnet
resource "azurerm_private_dns_zone_virtual_network_link" "private_endpoints_dns_vnet_link" {
  name                  = "privatelink-${var.app_stage}.azure.net"
  resource_group_name = var.azure_rg_name

  private_dns_zone_name = azurerm_private_dns_zone.private_endpoints_dns.name
  virtual_network_id    = azurerm_virtual_network.app_vnet.id
  registration_enabled = true
}
