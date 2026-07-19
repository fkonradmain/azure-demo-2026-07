module "network" {
    source = "./modules/network"
    azure_rg_name = data.azurerm_resource_group.app_rg.name # check if the submodule can pull it from tfvars as well
    azure_location = data.azurerm_resource_group.app_rg.location
    app_stage = var.app_stage
}

module "keyvault" {
    source = "./modules/keyvault"
    depends_on = [
        module.network
    ]
    
    azure_rg_name = data.azurerm_resource_group.app_rg.name
    azure_location = data.azurerm_resource_group.app_rg.location
    app_stage = var.app_stage

    private_endpoints_dns_zone_id = module.network.private_endpoints_dns_zone_id
    subnets = module.network.subnets
}

module "aks" {
    source = "./modules/aks"
    depends_on = [
        module.network,
        # module.keyvault
    ]

    azure_rg_name = data.azurerm_resource_group.app_rg.name
    azure_location = data.azurerm_resource_group.app_rg.location
    app_stage = var.app_stage

    aks_keyvault_id = module.keyvault.aks_keyvault_id
    subnets = module.network.subnets
    # private_endpoints_dns_zone_id = 
}

module "storage" {
    source = "./modules/storage"
    depends_on = [
        module.network
    ]
    
    azure_rg_name = data.azurerm_resource_group.app_rg.name
    azure_location = data.azurerm_resource_group.app_rg.location
    app_stage = var.app_stage


    private_endpoints_dns_zone_id = module.network.private_endpoints_dns_zone_id
    aks_keyvault_id = module.keyvault.aks_keyvault_id
    subnets = module.network.subnets
}
