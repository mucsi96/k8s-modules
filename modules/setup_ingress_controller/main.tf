data "azurerm_kubernetes_cluster" "kubernetes_cluster" {
  name                = var.resource_group_name
  resource_group_name = var.resource_group_name
}

data "azurerm_public_ip" "public_ip" {
  resource_group_name = data.azurerm_kubernetes_cluster.kubernetes_cluster.node_resource_group
  name                = var.resource_group_name
}
