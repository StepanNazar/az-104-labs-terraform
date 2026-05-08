data "azurerm_client_config" "current" {}

locals {
  vm_name        = "az104-vm0"
  workspace_name = "az104-law11-${substr(md5(data.azurerm_client_config.current.subscription_id), 0, 8)}"
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "az104-11-vnet0"
  address_space       = ["10.11.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet0"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.11.0.0/24"]
}

resource "azurerm_network_interface" "vm" {
  name                = "az104-11-nic0"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                = local.vm_name
  computer_name       = local.vm_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
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

resource "azurerm_log_analytics_workspace" "workspace" {
  name                = local.workspace_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_log_analytics_solution" "vm_insights" {
  solution_name         = "VMInsights"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  workspace_name        = azurerm_log_analytics_workspace.workspace.name
  workspace_resource_id = azurerm_log_analytics_workspace.workspace.id

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/VMInsights"
  }
}

resource "azurerm_virtual_machine_extension" "monitoring_agent" {
  name                       = "MicrosoftMonitoringAgent"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.id
  publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
  type                       = "MicrosoftMonitoringAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    workspaceId = azurerm_log_analytics_workspace.workspace.workspace_id
  })

  protected_settings = jsonencode({
    workspaceKey = azurerm_log_analytics_workspace.workspace.primary_shared_key
  })
}

resource "azurerm_virtual_machine_extension" "dependency_agent" {
  name                       = "DependencyAgentWindows"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.id
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentWindows"
  type_handler_version       = "9.10"
  auto_upgrade_minor_version = true

  depends_on = [azurerm_virtual_machine_extension.monitoring_agent]
}

resource "azurerm_monitor_action_group" "operations" {
  name                = "Alert the operations team"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "AlertOps"
  location            = "global"

  email_receiver {
    name                    = "VM was deleted"
    email_address           = var.operations_email
    use_common_alert_schema = true
  }
}

resource "azurerm_monitor_activity_log_alert" "vm_deleted" {
  name                = "VM was deleted"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "global"
  scopes              = ["/subscriptions/${data.azurerm_client_config.current.subscription_id}"]
  description         = "A VM in your resource group was deleted"
  enabled             = true

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Compute/virtualMachines/delete"
    resource_group = azurerm_resource_group.rg.name
  }

  action {
    action_group_id = azurerm_monitor_action_group.operations.id
  }
}

resource "azurerm_monitor_alert_processing_rule_suppression" "planned_maintenance" {
  name                = "Planned-Maintenance"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = ["/subscriptions/${data.azurerm_client_config.current.subscription_id}"]
  description         = "Suppress notifications during planned maintenance."
  enabled             = true

  condition {
    alert_rule_name {
      operator = "Equals"
      values   = [azurerm_monitor_activity_log_alert.vm_deleted.name]
    }
  }

  schedule {
    effective_from  = var.maintenance_start
    effective_until = var.maintenance_end
    time_zone       = var.maintenance_time_zone
  }
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "virtual_machine_name" {
  value = azurerm_windows_virtual_machine.vm.name
}

output "log_analytics_workspace_name" {
  value = azurerm_log_analytics_workspace.workspace.name
}

output "activity_log_alert_name" {
  value = azurerm_monitor_activity_log_alert.vm_deleted.name
}

output "action_group_name" {
  value = azurerm_monitor_action_group.operations.name
}
