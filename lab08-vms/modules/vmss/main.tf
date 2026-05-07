resource "azurerm_virtual_network" "vnet" {
  name                = "vmss-vnet"
  address_space       = ["10.82.0.0/20"]
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet0"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.82.0.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "vmss1-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-http"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "subnet" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_public_ip" "lb" {
  name                = "vmss-lb-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "lb" {
  name                = "vmss-lb"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "backend" {
  name            = "vmss-backend-pool"
  loadbalancer_id = azurerm_lb.lb.id
}

resource "azurerm_lb_probe" "http" {
  name            = "http-probe"
  loadbalancer_id = azurerm_lb.lb.id
  protocol        = "Tcp"
  port            = 80
}

resource "azurerm_lb_rule" "http" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.backend.id]
  probe_id                       = azurerm_lb_probe.http.id
}

resource "azurerm_windows_virtual_machine_scale_set" "vmss" {
  name                = "vmss1"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard_D2s_v3"
  instances           = 2
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  zones               = ["1", "2", "3"]
  upgrade_mode        = "Manual"

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

  network_interface {
    name    = "vmss1-nic"
    primary = true

    ip_configuration {
      name                                   = "ipconfig1"
      primary                                = true
      subnet_id                              = azurerm_subnet.subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.backend.id]

      public_ip_address {
        name = "instance-public-ip"
      }
    }
  }

  depends_on = [azurerm_subnet_network_security_group_association.subnet]
}

resource "azurerm_monitor_autoscale_setting" "vmss" {
  name                = "vmss1-autoscale"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_windows_virtual_machine_scale_set.vmss.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 2
      minimum = 2
      maximum = 10
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
        metric_namespace   = "Microsoft.Compute/virtualMachineScaleSets"
      }

      scale_action {
        direction = "Increase"
        type      = "PercentChangeCount"
        value     = "50"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
        metric_namespace   = "Microsoft.Compute/virtualMachineScaleSets"
      }

      scale_action {
        direction = "Decrease"
        type      = "PercentChangeCount"
        value     = "50"
        cooldown  = "PT5M"
      }
    }
  }
}

output "vmss_name" {
  value = azurerm_windows_virtual_machine_scale_set.vmss.name
}

output "load_balancer_name" {
  value = azurerm_lb.lb.name
}

output "public_ip_address" {
  value = azurerm_public_ip.lb.ip_address
}
