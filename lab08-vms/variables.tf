variable "resource_group_name" {
  description = "Name of the resource group"
  default     = "az104-rg8"
}

variable "location" {
  description = "Azure region for resources"
  default     = "Poland Central"
}

variable "lab_groups" {
  description = "Independent lab groups to deploy. [\"zone_vms\"] for Tasks 1-2, [\"vmss\"] for Tasks 3-4."
  type        = list(string)
  default     = ["zone_vms"]

  validation {
    condition     = alltrue([for group in var.lab_groups : contains(["zone_vms", "vmss"], group)])
    error_message = "Allowed lab_groups values are zone_vms and vmss."
  }
}

variable "admin_username" {
  description = "Local administrator username for Windows virtual machines."
  type        = string
  default     = "localadmin"
}

variable "admin_password" {
  description = "Local administrator password for Windows virtual machines."
  type        = string
  sensitive   = true
}

variable "windows_image_sku" {
  description = "Windows Server image SKU. Matches Windows Server 2025 Datacenter - x64 Gen2 from the lab."
  type        = string
  default     = "2025-datacenter-g2"
}
