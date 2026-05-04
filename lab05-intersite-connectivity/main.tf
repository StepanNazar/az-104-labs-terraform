resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "core_vnet" {
  name                = "CoreServicesVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "core_subnet" {
  name                 = "Core"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.core_vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "perimeter_subnet" {
  name                 = "perimeter"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.core_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_virtual_network" "mfg_vnet" {
  name                = "ManufacturingVnet"
  address_space       = ["172.16.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "mfg_subnet" {
  name                 = "Manufacturing"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.mfg_vnet.name
  address_prefixes     = ["172.16.0.0/24"]
}


resource "azurerm_virtual_network_peering" "core_to_mfg" {
  name                         = "ManufacturingVnet-to-CoreServicesVnet"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.core_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.mfg_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "mfg_to_core" {
  name                         = "CoreServicesVnet-to-ManufacturingVnet"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.mfg_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.core_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_network_interface" "core_vm_nic" {
  name                = "CoreServicesVM-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.core_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "core_vm" {
  name                = "CoreServicesVM"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2s_v3"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.core_vm_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-g2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = null
  }
}


resource "azurerm_network_interface" "mfg_vm_nic" {
  name                = "ManufacturingVM-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mfg_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "mfg_vm" {
  name                = "ManufacturingVM"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2s_v3"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.mfg_vm_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-g2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = null
  }
}


resource "azurerm_route_table" "rt_core" {
  name                          = "rt-CoreServices"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  bgp_route_propagation_enabled = false
}

resource "azurerm_route" "perimeter_to_core" {
  name                = "PerimetertoCore"
  resource_group_name = azurerm_resource_group.rg.name
  route_table_name    = azurerm_route_table.rt_core.name
  address_prefix      = "10.0.0.0/16"
  next_hop_type       = "VirtualAppliance"
  next_hop_in_ip_address = "10.0.1.7"
}

resource "azurerm_subnet_route_table_association" "perimeter_assoc" {
  subnet_id      = azurerm_subnet.perimeter_subnet.id
  route_table_id = azurerm_route_table.rt_core.id
}
