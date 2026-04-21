variable "resource_group_name" {
  description = "Name of the resource group"
  default     = "az104-rg4"
}

variable "location" {
  description = "Azure region for resources"
  default     = "Poland Central"
}

variable "public_dns_zone_name" {
  description = "Name of the public DNS zone"
  default     = "stepan.com"
}

variable "private_dns_zone_name" {
  description = "Name of the private DNS zone"
  default     = "private.stepan.com"
}
