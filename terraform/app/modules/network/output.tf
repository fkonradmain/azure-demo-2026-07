output "app_vnet_id" {
  value = azurerm_virtual_network.app_vnet.id
}

output "private_endpoints_dns_zone_id" {
    value = azurerm_private_dns_zone.private_endpoints_dns.id
}

output "subnets" {
    value = local.subnets
}