locals {
  vnet_name = "az104-06-vnet1"
  nsg_name  = "az104-06-nsg1"

  subnets = {
    subnet0 = "10.60.0.0/24"
    subnet1 = "10.60.1.0/24"
    subnet2 = "10.60.2.0/24"
  }

  vms = {
    vm0 = {
      vm_name     = "az104-06-vm0"
      nic_name    = "az104-06-nic0"
      subnet_name = "subnet0"
      private_ip  = "10.60.0.4"
    }
    vm1 = {
      vm_name     = "az104-06-vm1"
      nic_name    = "az104-06-nic1"
      subnet_name = "subnet1"
      private_ip  = "10.60.1.4"
    }
    vm2 = {
      vm_name     = "az104-06-vm2"
      nic_name    = "az104-06-nic2"
      subnet_name = "subnet2"
      private_ip  = "10.60.2.4"
    }
  }

  vm_extension_commands = {
    vm0 = "powershell.exe -Command \"Install-WindowsFeature -Name Web-Server -IncludeManagementTools; Set-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value ('Hello World from ' + $env:COMPUTERNAME)\""
    vm1 = "powershell.exe -Command \"Install-WindowsFeature -Name Web-Server -IncludeManagementTools; Set-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value ('Hello World from ' + $env:COMPUTERNAME); New-Item -Path 'C:\\inetpub\\wwwroot\\image' -ItemType Directory -Force | Out-Null; Set-Content -Path 'C:\\inetpub\\wwwroot\\image\\iisstart.htm' -Value ('Image from: ' + $env:COMPUTERNAME)\""
    vm2 = "powershell.exe -Command \"Install-WindowsFeature -Name Web-Server -IncludeManagementTools; Set-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value ('Hello World from ' + $env:COMPUTERNAME); New-Item -Path 'C:\\inetpub\\wwwroot\\video' -ItemType Directory -Force | Out-Null; Set-Content -Path 'C:\\inetpub\\wwwroot\\video\\iisstart.htm' -Value ('Video from: ' + $env:COMPUTERNAME)\""
  }

  load_balancer_backend_keys = toset(["vm0", "vm1"])
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = local.vnet_name
  address_space       = ["10.60.0.0/22"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "vm" {
  for_each = local.subnets

  name                 = each.key
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [each.value]
}

resource "azurerm_subnet" "appgw" {
  name                 = "subnet-appgw"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.60.3.224/27"]
}

resource "azurerm_network_security_group" "vm" {
  name                = local.nsg_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "default-allow-rdp"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "default-allow-http"
    priority                   = 1100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "vm" {
  for_each = local.vms

  name                = each.value.nic_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.vm[each.value.subnet_name].id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.private_ip
  }
}

resource "azurerm_network_interface_security_group_association" "vm" {
  for_each = azurerm_network_interface.vm

  network_interface_id      = each.value.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

resource "azurerm_windows_virtual_machine" "vm" {
  for_each = local.vms

  name                = each.value.vm_name
  computer_name       = each.value.vm_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.vm[each.key].id,
  ]
  provision_vm_agent        = true
  automatic_updates_enabled = true
  patch_mode                = "AutomaticByOS"

  os_disk {
    name                 = "${each.value.vm_name}_disk1"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 127
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "web" {
  for_each = local.vms

  name                       = "customScriptExtension"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm[each.key].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.7"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    commandToExecute = local.vm_extension_commands[each.key]
  })
}

resource "azurerm_public_ip" "lb" {
  name                = "az104-lbpip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"
}

resource "azurerm_lb" "main" {
  name                = "az104-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "az104-fe"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "main" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "az104-be"
}

resource "azurerm_network_interface_backend_address_pool_association" "lb" {
  for_each = {
    for key, value in azurerm_network_interface.vm : key => value
    if contains(local.load_balancer_backend_keys, key)
  }

  network_interface_id    = each.value.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
}

resource "azurerm_lb_probe" "http" {
  loadbalancer_id     = azurerm_lb.main.id
  name                = "az104-hp"
  protocol            = "Tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "http" {
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "az104-lbrule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "az104-fe"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main.id]
  probe_id                       = azurerm_lb_probe.http.id
  load_distribution              = "Default"
  idle_timeout_in_minutes        = 4
  disable_outbound_snat          = false
  floating_ip_enabled            = false
  tcp_reset_enabled              = false
}

resource "azurerm_public_ip" "appgw" {
  name                = "az104-gwpip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"
  zones               = var.application_gateway_public_ip_zones
}

resource "azurerm_application_gateway" "main" {
  name                = "az104-appgw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  http2_enabled       = false

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "az104-appgw-ipcfg"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_port {
    name = "port_80"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "public-ipv4"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  backend_address_pool {
    name         = "az104-appgwbe"
    ip_addresses = [local.vms.vm1.private_ip, local.vms.vm2.private_ip]
  }

  backend_address_pool {
    name         = "az104-imagebe"
    ip_addresses = [local.vms.vm1.private_ip]
  }

  backend_address_pool {
    name         = "az104-videobe"
    ip_addresses = [local.vms.vm2.private_ip]
  }

  backend_http_settings {
    name                  = "az104-http"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  http_listener {
    name                           = "az104-listener"
    frontend_ip_configuration_name = "public-ipv4"
    frontend_port_name             = "port_80"
    protocol                       = "Http"
  }

  url_path_map {
    name                               = "az104-pathmap"
    default_backend_address_pool_name  = "az104-appgwbe"
    default_backend_http_settings_name = "az104-http"

    path_rule {
      name                       = "images"
      paths                      = ["/image/*"]
      backend_address_pool_name  = "az104-imagebe"
      backend_http_settings_name = "az104-http"
    }

    path_rule {
      name                       = "videos"
      paths                      = ["/video/*"]
      backend_address_pool_name  = "az104-videobe"
      backend_http_settings_name = "az104-http"
    }
  }

  request_routing_rule {
    name               = "az104-gwrule"
    rule_type          = "PathBasedRouting"
    http_listener_name = "az104-listener"
    url_path_map_name  = "az104-pathmap"
    priority           = 10
  }
}

output "load_balancer_public_ip" {
  description = "Public IP address for the Lab 06 public Load Balancer."
  value       = azurerm_public_ip.lb.ip_address
}

output "application_gateway_public_ip" {
  description = "Public IP address for the Lab 06 Application Gateway."
  value       = azurerm_public_ip.appgw.ip_address
}
