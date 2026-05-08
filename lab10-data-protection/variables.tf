variable "resource_group_name" {
  description = "Name of the primary resource group."
  default     = "az104-rg-region1"
}

variable "location" {
  description = "Primary Azure region for the virtual machine and backup vault."
  default     = "Poland Central"
}

variable "secondary_resource_group_name" {
  description = "Name of the secondary resource group used by Azure Site Recovery."
  default     = "az104-rg-region2"
}

variable "secondary_location" {
  description = "Secondary Azure region used by Azure Site Recovery."
  default     = "UAE North"
}

variable "admin_username" {
  description = "Local administrator username for the Windows virtual machine."
  type        = string
  default     = "localadmin"
}

variable "admin_password" {
  description = "Local administrator password for the Windows virtual machine."
  type        = string
  sensitive   = true
}

variable "vm_size" {
  description = "Size of the lab virtual machine."
  type        = string
  default     = "Standard_B2s"
}

variable "windows_image_sku" {
  description = "Windows Server image SKU."
  type        = string
  default     = "2019-Datacenter"
}

variable "backup_timezone" {
  description = "Timezone used by the VM backup policy. FLE Standard Time maps to Europe/Kyiv."
  type        = string
  default     = "FLE Standard Time"
}

variable "backup_daily_retention_days" {
  description = "Number of daily VM recovery points to retain."
  type        = number
  default     = 7
}

variable "enable_site_recovery" {
  description = "When true, configures Azure Site Recovery replication for the lab VM."
  type        = bool
  default     = true
}
