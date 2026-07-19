resource "azurerm_storage_account" "tfstatefk" {
  lifecycle {
    prevent_destroy = true
  }
  name                     = "tfstatefk"
  resource_group_name      = data.azurerm_resource_group.rg_fk.name
  location                 = data.azurerm_resource_group.rg_fk.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_nested_items_to_be_public = false
}

resource "azurerm_private_endpoint" "example" {
  name                = "example-endpoint"
  location            = data.azurerm_resource_group.rg_fk.location
  resource_group_name = data.azurerm_resource_group.rg_fk.name
  subnet_id           = azurerm_subnet.endpoint.id

  private_service_connection {
    name                           = "example-privateserviceconnection"
    private_connection_resource_id = azurerm_private_link_service.example.id
    is_manual_connection           = false
  }
}