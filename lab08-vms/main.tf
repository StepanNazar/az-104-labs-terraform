locals {
  enabled_lab_groups = toset(var.lab_groups)
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

module "zone_vms" {
  count  = contains(local.enabled_lab_groups, "zone_vms") ? 1 : 0
  source = "./modules/zone-vms"

  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  windows_image_sku   = var.windows_image_sku
}

module "vmss" {
  count  = contains(local.enabled_lab_groups, "vmss") ? 1 : 0
  source = "./modules/vmss"

  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  windows_image_sku   = var.windows_image_sku
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "enabled_lab_groups" {
  value = var.lab_groups
}

output "zone_vm_names" {
  value = try(module.zone_vms[0].vm_names, [])
}

output "vmss_name" {
  value = try(module.vmss[0].vmss_name, null)
}

output "vmss_public_ip_address" {
  value = try(module.vmss[0].public_ip_address, null)
}
