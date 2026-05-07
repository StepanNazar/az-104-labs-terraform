data "azurerm_client_config" "current" {}

locals {
  dns_name_label = coalesce(
    var.dns_name_label,
    "az104lab09b${substr(md5(data.azurerm_client_config.current.subscription_id), 0, 13)}"
  )
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_container_group" "aci" {
  name                = var.container_group_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  ip_address_type     = "Public"
  dns_name_label      = local.dns_name_label

  container {
    name   = var.container_group_name
    image  = var.image
    cpu    = var.cpu
    memory = var.memory_in_gb

    ports {
      port     = 80
      protocol = "TCP"
    }
  }
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "container_group_name" {
  value = azurerm_container_group.aci.name
}

output "container_image" {
  value = var.image
}

output "fqdn" {
  value = azurerm_container_group.aci.fqdn
}

output "url" {
  value = "http://${azurerm_container_group.aci.fqdn}"
}
