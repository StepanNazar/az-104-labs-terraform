data "azurerm_client_config" "current" {}

locals {
  vm_name = "az104-10-vm0"

  diagnostic_storage_account_name = "az104diag${substr(md5(data.azurerm_client_config.current.subscription_id), 0, 14)}"
  asr_cache_storage_account_name  = "az104asr${substr(md5(data.azurerm_client_config.current.subscription_id), 0, 14)}"

  recovery_services_diagnostic_categories = [
    "Azure Backup Reporting Data",
    "Addon Azure Backup Job Data",
    "Addon Azure Backup Alert Data",
    "Azure Site Recovery Jobs",
    "Azure Site Recovery Events",
  ]
}

resource "azurerm_resource_group" "primary" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_resource_group" "secondary" {
  count = var.enable_site_recovery ? 1 : 0

  name     = var.secondary_resource_group_name
  location = var.secondary_location
}

resource "azurerm_virtual_network" "primary" {
  name                = "az104-10-vnet0"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name
}

resource "azurerm_subnet" "primary" {
  name                 = "subnet0"
  resource_group_name  = azurerm_resource_group.primary.name
  virtual_network_name = azurerm_virtual_network.primary.name
  address_prefixes     = ["10.10.0.0/24"]
}

resource "azurerm_virtual_network" "secondary" {
  count = var.enable_site_recovery ? 1 : 0

  name                = "az104-10-vnet0-asr"
  address_space       = ["10.20.0.0/16"]
  location            = azurerm_resource_group.secondary[0].location
  resource_group_name = azurerm_resource_group.secondary[0].name
}

resource "azurerm_subnet" "secondary" {
  count = var.enable_site_recovery ? 1 : 0

  name                 = "subnet0"
  resource_group_name  = azurerm_resource_group.secondary[0].name
  virtual_network_name = azurerm_virtual_network.secondary[0].name
  address_prefixes     = ["10.20.0.0/24"]
}

resource "azurerm_network_interface" "vm" {
  name                = "az104-10-nic0"
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.primary.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                = local.vm_name
  computer_name       = local.vm_name
  resource_group_name = azurerm_resource_group.primary.name
  location            = azurerm_resource_group.primary.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.vm.id,
  ]

  os_disk {
    name                 = "${local.vm_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = var.windows_image_sku
    version   = "latest"
  }
}

data "azurerm_managed_disk" "vm_os_disk" {
  count = var.enable_site_recovery ? 1 : 0

  name                = azurerm_windows_virtual_machine.vm.os_disk[0].name
  resource_group_name = azurerm_resource_group.primary.name

  depends_on = [azurerm_windows_virtual_machine.vm]
}

resource "azurerm_recovery_services_vault" "backup" {
  name                = "az104-rsv-region1"
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name
  sku                 = "Standard"
  storage_mode_type   = "GeoRedundant"
}

resource "azurerm_backup_policy_vm" "vm" {
  name                           = "az104-backup"
  resource_group_name            = azurerm_resource_group.primary.name
  recovery_vault_name            = azurerm_recovery_services_vault.backup.name
  timezone                       = var.backup_timezone
  policy_type                    = "V1"
  instant_restore_retention_days = 2

  backup {
    frequency = "Daily"
    time      = "00:00"
  }

  retention_daily {
    count = var.backup_daily_retention_days
  }
}

resource "azurerm_backup_protected_vm" "vm" {
  resource_group_name = azurerm_resource_group.primary.name
  recovery_vault_name = azurerm_recovery_services_vault.backup.name
  source_vm_id        = azurerm_windows_virtual_machine.vm.id
  backup_policy_id    = azurerm_backup_policy_vm.vm.id
}

resource "azurerm_storage_account" "diagnostics" {
  name                     = local.diagnostic_storage_account_name
  resource_group_name      = azurerm_resource_group.primary.name
  location                 = azurerm_resource_group.primary.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_monitor_diagnostic_setting" "recovery_services_vault" {
  name               = "Logs and Metrics to storage"
  target_resource_id = azurerm_recovery_services_vault.backup.id
  storage_account_id = azurerm_storage_account.diagnostics.id

  dynamic "enabled_log" {
    for_each = toset(local.recovery_services_diagnostic_categories)

    content {
      category = enabled_log.value
    }
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_recovery_services_vault" "site_recovery" {
  count = var.enable_site_recovery ? 1 : 0

  name                = "az104-rsv-region2"
  location            = azurerm_resource_group.secondary[0].location
  resource_group_name = azurerm_resource_group.secondary[0].name
  sku                 = "Standard"
  storage_mode_type   = "GeoRedundant"
}

resource "azurerm_storage_account" "asr_cache" {
  count = var.enable_site_recovery ? 1 : 0

  name                     = local.asr_cache_storage_account_name
  resource_group_name      = azurerm_resource_group.primary.name
  location                 = azurerm_resource_group.primary.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_site_recovery_fabric" "primary" {
  count = var.enable_site_recovery ? 1 : 0

  name                = "az104-primary-fabric"
  resource_group_name = azurerm_resource_group.secondary[0].name
  recovery_vault_name = azurerm_recovery_services_vault.site_recovery[0].name
  location            = azurerm_resource_group.primary.location
}

resource "azurerm_site_recovery_fabric" "secondary" {
  count = var.enable_site_recovery ? 1 : 0

  name                = "az104-secondary-fabric"
  resource_group_name = azurerm_resource_group.secondary[0].name
  recovery_vault_name = azurerm_recovery_services_vault.site_recovery[0].name
  location            = azurerm_resource_group.secondary[0].location
}

resource "azurerm_site_recovery_protection_container" "primary" {
  count = var.enable_site_recovery ? 1 : 0

  name                 = "az104-primary-container"
  resource_group_name  = azurerm_resource_group.secondary[0].name
  recovery_vault_name  = azurerm_recovery_services_vault.site_recovery[0].name
  recovery_fabric_name = azurerm_site_recovery_fabric.primary[0].name
}

resource "azurerm_site_recovery_protection_container" "secondary" {
  count = var.enable_site_recovery ? 1 : 0

  name                 = "az104-secondary-container"
  resource_group_name  = azurerm_resource_group.secondary[0].name
  recovery_vault_name  = azurerm_recovery_services_vault.site_recovery[0].name
  recovery_fabric_name = azurerm_site_recovery_fabric.secondary[0].name
}

resource "azurerm_site_recovery_replication_policy" "vm" {
  count = var.enable_site_recovery ? 1 : 0

  name                                                 = "az104-replication-policy"
  resource_group_name                                  = azurerm_resource_group.secondary[0].name
  recovery_vault_name                                  = azurerm_recovery_services_vault.site_recovery[0].name
  recovery_point_retention_in_minutes                  = 24 * 60
  application_consistent_snapshot_frequency_in_minutes = 4 * 60
}

resource "azurerm_site_recovery_protection_container_mapping" "vm" {
  count = var.enable_site_recovery ? 1 : 0

  name                                      = "az104-container-mapping"
  resource_group_name                       = azurerm_resource_group.secondary[0].name
  recovery_vault_name                       = azurerm_recovery_services_vault.site_recovery[0].name
  recovery_fabric_name                      = azurerm_site_recovery_fabric.primary[0].name
  recovery_source_protection_container_name = azurerm_site_recovery_protection_container.primary[0].name
  recovery_target_protection_container_id   = azurerm_site_recovery_protection_container.secondary[0].id
  recovery_replication_policy_id            = azurerm_site_recovery_replication_policy.vm[0].id
}

resource "azurerm_site_recovery_network_mapping" "vm" {
  count = var.enable_site_recovery ? 1 : 0

  name                        = "az104-network-mapping"
  resource_group_name         = azurerm_resource_group.secondary[0].name
  recovery_vault_name         = azurerm_recovery_services_vault.site_recovery[0].name
  source_recovery_fabric_name = azurerm_site_recovery_fabric.primary[0].name
  target_recovery_fabric_name = azurerm_site_recovery_fabric.secondary[0].name
  source_network_id           = azurerm_virtual_network.primary.id
  target_network_id           = azurerm_virtual_network.secondary[0].id
}

resource "azurerm_site_recovery_replicated_vm" "vm" {
  count = var.enable_site_recovery ? 1 : 0

  name                                      = "${local.vm_name}-replication"
  resource_group_name                       = azurerm_resource_group.secondary[0].name
  recovery_vault_name                       = azurerm_recovery_services_vault.site_recovery[0].name
  source_recovery_fabric_name               = azurerm_site_recovery_fabric.primary[0].name
  source_vm_id                              = azurerm_windows_virtual_machine.vm.id
  recovery_replication_policy_id            = azurerm_site_recovery_replication_policy.vm[0].id
  source_recovery_protection_container_name = azurerm_site_recovery_protection_container.primary[0].name
  target_resource_group_id                  = azurerm_resource_group.secondary[0].id
  target_recovery_fabric_id                 = azurerm_site_recovery_fabric.secondary[0].id
  target_recovery_protection_container_id   = azurerm_site_recovery_protection_container.secondary[0].id
  target_network_id                         = azurerm_virtual_network.secondary[0].id
  target_virtual_machine_size               = var.vm_size

  managed_disk {
    disk_id                    = lower(data.azurerm_managed_disk.vm_os_disk[0].id)
    staging_storage_account_id = azurerm_storage_account.asr_cache[0].id
    target_resource_group_id   = azurerm_resource_group.secondary[0].id
    target_disk_type           = azurerm_windows_virtual_machine.vm.os_disk[0].storage_account_type
    target_replica_disk_type   = azurerm_windows_virtual_machine.vm.os_disk[0].storage_account_type
  }

  network_interface {
    source_network_interface_id = azurerm_network_interface.vm.id
    target_subnet_name          = azurerm_subnet.secondary[0].name
  }

  depends_on = [
    azurerm_site_recovery_protection_container_mapping.vm,
    azurerm_site_recovery_network_mapping.vm,
  ]
}

output "primary_resource_group_name" {
  value = azurerm_resource_group.primary.name
}

output "virtual_machine_name" {
  value = azurerm_windows_virtual_machine.vm.name
}

output "backup_vault_name" {
  value = azurerm_recovery_services_vault.backup.name
}

output "backup_policy_name" {
  value = azurerm_backup_policy_vm.vm.name
}

output "diagnostic_storage_account_name" {
  value = azurerm_storage_account.diagnostics.name
}

output "site_recovery_vault_name" {
  value = try(azurerm_recovery_services_vault.site_recovery[0].name, null)
}

output "site_recovery_replication_name" {
  value = try(azurerm_site_recovery_replicated_vm.vm[0].name, null)
}
