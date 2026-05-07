data "azurerm_client_config" "current" {}

locals {
  web_app_name = coalesce(
    var.web_app_name,
    "az104lab09a${substr(md5(data.azurerm_client_config.current.subscription_id), 0, 13)}"
  )
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_service_plan" "plan" {
  name                = var.app_service_plan_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = var.sku_name
}

resource "azurerm_linux_web_app" "webapp" {
  name                = local.web_app_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.plan.id

  site_config {
    application_stack {
      php_version = var.php_version
    }
  }
}

resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.webapp.id

  site_config {
    application_stack {
      php_version = var.php_version
    }
  }
}

resource "azurerm_app_service_source_control_slot" "staging" {
  slot_id                = azurerm_linux_web_app_slot.staging.id
  repo_url               = var.repository_url
  branch                 = var.repository_branch
  use_manual_integration = true
}

resource "azurerm_web_app_active_slot" "production" {
  count = var.swap_staging_to_production ? 1 : 0

  slot_id = azurerm_linux_web_app_slot.staging.id

  depends_on = [azurerm_app_service_source_control_slot.staging]
}

resource "azurerm_monitor_autoscale_setting" "app_service_plan" {
  name                = "az104-autoscale-webapp"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_service_plan.plan.id
  enabled             = true

  profile {
    name = "default"

    capacity {
      minimum = tostring(var.autoscale_minimum_capacity)
      default = tostring(var.autoscale_default_capacity)
      maximum = tostring(var.autoscale_maximum_capacity)
    }
  }
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "app_service_plan_name" {
  value = azurerm_service_plan.plan.name
}

output "web_app_name" {
  value = azurerm_linux_web_app.webapp.name
}

output "production_default_domain" {
  value = azurerm_linux_web_app.webapp.default_hostname
}

output "production_url" {
  value = "https://${azurerm_linux_web_app.webapp.default_hostname}"
}

output "staging_default_domain" {
  value = azurerm_linux_web_app_slot.staging.default_hostname
}

output "staging_url" {
  value = "https://${azurerm_linux_web_app_slot.staging.default_hostname}"
}
