locals {
  vm_zones = {
    az104-vm1 = "1"
    az104-vm2 = "2"
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "az104-vm-vnet"
  address_space       = ["10.81.0.0/20"]
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet0"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.81.0.0/24"]
}

resource "azurerm_network_interface" "nic" {
  for_each = local.vm_zones

  name                = "${each.key}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  for_each = local.vm_zones

  name                = each.key
  resource_group_name = var.resource_group_name
  location            = var.location
  zone                = each.value
  size                = each.key == "az104-vm1" ? "Standard_D2ds_v4" : "Standard_D2s_v3"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.nic[each.key].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = var.windows_image_sku
    version   = "latest"
  }
}

resource "azurerm_managed_disk" "vm1_data" {
  name                 = "vm1-disk1"
  location             = var.location
  resource_group_name  = var.resource_group_name
  zone                 = "1"
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32
}

resource "azurerm_virtual_machine_data_disk_attachment" "vm1_data" {
  managed_disk_id    = azurerm_managed_disk.vm1_data.id
  virtual_machine_id = azurerm_windows_virtual_machine.vm["az104-vm1"].id
  lun                = 0
  caching            = "ReadWrite"
}

output "vm_names" {
  value = keys(azurerm_windows_virtual_machine.vm)
}

output "data_disk_name" {
  value = azurerm_managed_disk.vm1_data.name
}
