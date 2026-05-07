variable "resource_group_name" {
  description = "Name of the existing resource group."
  type        = string
}

variable "location" {
  description = "Azure region for resources."
  type        = string
}

variable "admin_username" {
  description = "Local administrator username."
  type        = string
}

variable "admin_password" {
  description = "Local administrator password."
  type        = string
  sensitive   = true
}

variable "windows_image_sku" {
  description = "Windows Server image SKU."
  type        = string
}
