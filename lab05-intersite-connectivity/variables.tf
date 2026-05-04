variable "resource_group_name" {
  description = "Name of the resource group"
  default     = "az104-rg5"
}

variable "location" {
  description = "Azure region for resources"
  default     = "Poland Central"
}

variable "admin_username" {
  description = "Admin username for virtual machines"
  default     = "localadmin"
}

variable "admin_password" {
  description = "Admin password for virtual machines"
  type        = string
  default     = "Pa55w.rd1234!"
  sensitive   = true
}
