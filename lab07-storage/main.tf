data "azurerm_client_config" "current" {}

locals {
  storage_account_name = coalesce(
    var.storage_account_name,
    "az104lab07${substr(md5(data.azurerm_client_config.current.subscription_id), 0, 14)}"
  )

  sample_file_name = "security-notice.txt"
  sample_file_path = "${path.module}/files/${local.sample_file_name}"
  sample_blob_name = "securitytest/${local.sample_file_name}"
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "storage" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_management_policy" "move_to_cool" {
  storage_account_id = azurerm_storage_account.storage.id

  rule {
    name    = "Movetocool"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 30
      }
    }
  }
}

resource "azurerm_storage_container" "data" {
  name                  = var.blob_container_name
  storage_account_id    = azurerm_storage_account.storage.id
  container_access_type = "private"
}

resource "azurerm_storage_container_immutability_policy" "data" {
  storage_container_resource_manager_id = azurerm_storage_container.data.id
  immutability_period_in_days           = 180
}

resource "azurerm_storage_blob" "sample" {
  name                   = local.sample_blob_name
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.data.name
  type                   = "Block"
  source                 = local.sample_file_path
  access_tier            = "Hot"
  content_type           = "text/plain"
}

data "azurerm_storage_account_blob_container_sas" "read_only" {
  connection_string = azurerm_storage_account.storage.primary_connection_string
  container_name    = azurerm_storage_container.data.name
  https_only        = true
  start             = timeadd(timestamp(), "-24h")
  expiry            = timeadd(timestamp(), "24h")

  permissions {
    read = true
  }

  depends_on = [azurerm_storage_blob.sample]
}

resource "azurerm_storage_share" "share" {
  name               = var.file_share_name
  storage_account_id = azurerm_storage_account.storage.id
  quota              = var.file_share_quota_gb
}

resource "azurerm_storage_share_file" "sample" {
  name              = local.sample_file_name
  storage_share_url = azurerm_storage_share.share.url
  source            = local.sample_file_path
  content_type      = "text/plain"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet1"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "default" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
}

resource "azurerm_storage_account_network_rules" "storage" {
  storage_account_id         = azurerm_storage_account.storage.id
  default_action             = "Deny"
  bypass                     = []
  virtual_network_subnet_ids = [azurerm_subnet.default.id]
  ip_rules                   = var.client_ipv4_cidrs

  depends_on = [
    azurerm_storage_blob.sample,
    azurerm_storage_share_file.sample
  ]
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "storage_account_name" {
  value = azurerm_storage_account.storage.name
}

output "blob_url" {
  value = azurerm_storage_blob.sample.url
}

output "blob_sas_url" {
  value     = "${azurerm_storage_blob.sample.url}?${trimprefix(data.azurerm_storage_account_blob_container_sas.read_only.sas, "?")}"
  sensitive = true
}

output "file_share_url" {
  value = azurerm_storage_share.share.url
}
