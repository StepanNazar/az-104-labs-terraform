variable "resource_group_name" {
  description = "Name of the resource group used for the monitoring lab."
  default     = "az104-rg11"
}

variable "location" {
  description = "Azure region for lab resources."
  default     = "Poland Central"
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
  default     = "Pas$word1234"
}

variable "vm_size" {
  description = "Size of the lab virtual machine."
  type        = string
  default     = "Standard_B2s_v2"
}

variable "windows_image_sku" {
  description = "Windows Server image SKU."
  type        = string
  default     = "2019-Datacenter"
}

variable "operations_email" {
  description = "Email address that receives Azure Monitor action group notifications."
  type        = string
}

variable "maintenance_start" {
  description = "Start time for planned maintenance notification suppression."
  type        = string
  default     = "2026-05-08T22:00:00"
}

variable "maintenance_end" {
  description = "End time for planned maintenance notification suppression."
  type        = string
  default     = "2026-05-09T07:00:00"
}

variable "maintenance_time_zone" {
  description = "Time zone used by the alert processing rule schedule. FLE Standard Time maps to Europe/Kyiv."
  type        = string
  default     = "FLE Standard Time"
}
