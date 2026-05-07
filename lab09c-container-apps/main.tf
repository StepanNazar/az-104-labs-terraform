resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_resource_provider_registration" "app" {
  name = "Microsoft.App"
}

resource "azurerm_container_app_environment" "env" {
  name                = var.container_app_environment_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  depends_on = [azurerm_resource_provider_registration.app]
}

resource "azurerm_container_app" "app" {
  name                         = var.container_app_name
  resource_group_name          = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.env.id
  revision_mode                = "Single"

  ingress {
    external_enabled = true
    target_port      = var.target_port
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = var.container_app_name
      image  = var.image
      cpu    = var.cpu
      memory = var.memory
    }
  }
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "container_app_environment_name" {
  value = azurerm_container_app_environment.env.name
}

output "container_app_name" {
  value = azurerm_container_app.app.name
}

output "container_image" {
  value = var.image
}

output "application_fqdn" {
  value = azurerm_container_app.app.ingress[0].fqdn
}

output "application_url" {
  value = "https://${azurerm_container_app.app.ingress[0].fqdn}"
}
