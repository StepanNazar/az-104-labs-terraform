variable "resource_group_name" {
  description = "Name of the resource group"
  default     = "az104-rg9"
}

variable "location" {
  description = "Azure region for resources"
  default     = "Poland Central"
}

variable "container_app_environment_name" {
  description = "Name of the Azure Container Apps environment"
  default     = "my-environment"
}

variable "container_app_name" {
  description = "Name of the Azure Container App"
  default     = "my-app"
}

variable "image" {
  description = "Quickstart Docker image used by the container app"
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "target_port" {
  description = "Target port exposed by the container app"
  default     = 80
}

variable "cpu" {
  description = "CPU cores allocated to the container app"
  default     = 0.5
}

variable "memory" {
  description = "Memory allocated to the container app"
  default     = "1Gi"
}

variable "min_replicas" {
  description = "Minimum number of container app replicas"
  default     = 1
}

variable "max_replicas" {
  description = "Maximum number of container app replicas"
  default     = 1
}
