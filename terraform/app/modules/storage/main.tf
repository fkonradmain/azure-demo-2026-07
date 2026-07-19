# Unique random string to allow collission free storageaccount generation
resource "random_string" "app_suffix" {
 length  = 5
 special = false
 upper   = false
}

resource "azurerm_storage_account" "app_storage" {
  name                     = "appstorage${var.app_stage}${random_string.app_suffix.result}"
  location            = var.azure_location
  resource_group_name = var.azure_rg_name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_nested_items_to_be_public = false
}

resource "azurerm_private_endpoint" "blob_storage_endpoint" {
  name                = "storage-endpoint-${var.app_stage}"
  location            = var.azure_location
  resource_group_name = var.azure_rg_name
  subnet_id           = var.subnets.private_endpoints.id

  private_service_connection {
    name              = "storage-psc-${var.app_stage}"
    subresource_names = ["blob"]
    # private_connection_resource_alias = azurerm_private_link_service.keyvault_privatelink.alias
    private_connection_resource_id = azurerm_storage_account.app_storage.id
    is_manual_connection           = false #TODO: we might actually need manual approval, in that case set to true
  }


  private_dns_zone_group {
    name                 = "storage-dns-zone-group-${var.app_stage}"
    private_dns_zone_ids = [var.private_endpoints_dns_zone_id]
  }
}
