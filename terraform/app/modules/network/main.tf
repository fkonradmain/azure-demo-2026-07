# Very simple network security group, allowing no inbound traffic except ICMP, and allowing unlimited traffic between vnets
# This nsg is limited in its practicabilit and can only be used as a trivial example.
resource "azurerm_network_security_group" "app_vnet_nsg" {
  name                = "app-vnet-nsg-${var.app_stage}"
  location            = var.azure_location
  resource_group_name = var.azure_rg_name

  security_rule {
    name                       = "allow-inter-subnet-traffic"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = tolist(azurerm_virtual_network.app_vnet.address_space)[0]
    destination_address_prefix = tolist(azurerm_virtual_network.app_vnet.address_space)[0]
  }

  security_rule {
    name                       = "allow-all-icmp-inbound"
    priority                   = 500
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

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
}

resource "azurerm_virtual_network" "app_vnet" {
  name                = "app-vnet-${var.app_stage}"
  location            = var.azure_location
  resource_group_name = var.azure_rg_name
  address_space       = ["172.19.0.0/16"]
}

# Create a DNS zone for all private link connections
resource "azurerm_private_dns_zone" "private_endpoints_dns" {
  # name                = "privatelink-${var.app_stage}.azure.net"
  name = 	"privatelink.vaultcore.azure.net" # TODO: check if privatelink also supports Storage accounts in the current configuration
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
