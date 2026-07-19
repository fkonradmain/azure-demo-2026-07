# Unique random string to allow collission free keyvault generation
resource "random_string" "app_suffix" {
  length  = 5
  special = false
  upper   = false
}

resource "azurerm_kubernetes_cluster" "workload_aks" {
  lifecycle {
    ignore_changes = [
      # default_node_pool[0].node_count # uncomment for autoscaler
      default_node_pool[0].upgrade_settings
    ]
  }

  name                = "app-workload-aks-${var.app_stage}-${random_string.app_suffix.result}"
  location            = var.azure_location
  resource_group_name = var.azure_rg_name
  dns_prefix          = "app-workload-aks-${var.app_stage}-${random_string.app_suffix.result}"
  # TODO: check if we should limit the cluster api to internal ips only - i.e. private cluster
  # dns_prefix_private_cluster = "app-workload-aks-${var.app_stage}"
  private_cluster_enabled = true

  default_node_pool {
    name       = "default"
    temporary_name_for_rotation = "rotating"
    node_count = 1
    vm_size    = "Standard_d2_v5"
    # os_sku = ""
    # vnet_subnet_id = var.subnets.aks_node.id # TODO: documentation notes that for an aks node subnet, we need to assign a route table to that subnet
  }

  # TODO: Check if we actually need a user assigned identity, we probably do not since we assign identities to pods in a later position
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_identity.id]
  }
  # identity {
  #   type = "SystemAssigned"
  # }

  # optional parameters

  # Access profile to limit api server access
  # api_server_access_profile {
  #   # authorized_ip_ranges = azurerm_virtual_network.app_vnet.address_space
  #   subnet_id            = var.subnets.aks_api.id
  #   virtual_network_integration_enabled = true # whatever this is, probably determines, that an IP address of the subnet is going to be used
  # }

  # TODO: evaluate Active directory based access control
  azure_active_directory_role_based_access_control {
    admin_group_object_ids = [
      # "5be015b7-7f09-4082-870c-b43ee3588529", # FK
      "90bab22c-b512-44b9-aff4-9b787893291a"  # All users (only group available)
    ]                                         # TODO: use variable here
    azure_rbac_enabled = true                 # User Azure RBAC instead of Kubernetes RBAC
  }
  oidc_issuer_enabled = true # mandatory for azure ad rbac

  # TODO: evaluate azure policy
  # azure_policy_enabled = true

  # TODO: evaluate ingress application gateway
  # ingress_application_gateway {} # See https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster#gateway_id-3

  # TODO: evaluate key management service
  # See here: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster#key_vault_key_id-3
  # key_management_service {}

  # Use key vault secrets provider in the cluster
  # See here: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster#secret_rotation_enabled-3
  key_vault_secrets_provider {
    secret_rotation_enabled = false
  }

  # TODO: Disable break glass access
  # local_account_disabled = true

  # TODO: evaluate setting node and other profiles
  # kubelet_config {}
  # kubelet_identity {}
  # linux_os_config {}
  # linux_profile {}
  # monitor_metrics {}
  # network_profile {} # see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster#network_plugin-3
  network_profile {
    load_balancer_sku = "standard"
    # network_plugin = "azure"
    network_plugin = "kubenet"
    # network_plugin_mode = "overlay"
    # dns_service_ip = "10.2.0.10"
    # service_cidr = "10.2.0.0/24"
    # outbound_type = "managedNATGateway"
  }
  # bootstrap_profile {}
  # node_provisioning_profile {}
  # web_app_routing {}

  # TODO: evaluate setting a node upgrade channel
  # node_os_upgrade_channel = 

  # TODO: check if we need workload identitiy for kubernetes clusters
  # Run workloads with a specified workload identity
  workload_identity_enabled = true
}

