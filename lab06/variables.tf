variable "resource_group_name" {
  description = "Name of the resource group for Lab 06."
  default     = "az104-rg6"
}

variable "location" {
  description = "Azure region for Lab 06 resources."
  default     = "Poland Central"
}

variable "admin_username" {
  description = "Admin username for the Lab 06 virtual machines."
  default     = "localadmin"
}

variable "admin_password" {
  description = "Admin password for the Lab 06 virtual machines."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 12
    error_message = "admin_password must contain at least 12 characters."
  }
}

variable "vm_size" {
  description = "VM size for the Lab 06 virtual machines. Change this if the default SKU is unavailable in your subscription."
  default     = "Standard_B2as_v2"
}

variable "application_gateway_public_ip_zones" {
  description = "Availability zones for the Application Gateway public IP. Set to [] if the selected region does not support zones."
  type        = list(string)
  default     = ["1"]
}
