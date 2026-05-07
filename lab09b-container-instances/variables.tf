variable "resource_group_name" {
  description = "Name of the resource group"
  default     = "az104-rg9"
}

variable "location" {
  description = "Azure region for resources"
  default     = "Poland Central"
}

variable "container_group_name" {
  description = "Name of the Azure Container Instance container group"
  default     = "az104-c1"
}

variable "dns_name_label" {
  description = "Optional globally unique DNS name label for the container group. If null, a deterministic label is generated from the subscription ID."
  type        = string
  default     = null
}

variable "image" {
  description = "Docker image used by the container instance"
  default     = "mcr.microsoft.com/azuredocs/aci-helloworld:latest"
}

variable "cpu" {
  description = "CPU cores allocated to the container"
  default     = 1
}

variable "memory_in_gb" {
  description = "Memory allocated to the container in GiB"
  default     = 1.5
}
