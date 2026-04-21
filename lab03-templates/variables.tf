variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "az104-rg3"
}

variable "location" {
  description = "Location of the resources"
  type        = string
  default     = "Poland Central"
}

variable "disk1_name" {
  description = "Name of the first managed disk"
  type        = string
  default     = "az104-disk1"
}

variable "disk2_name" {
  description = "Name of the second managed disk"
  type        = string
  default     = "az104-disk2"
}
