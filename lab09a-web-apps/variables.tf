variable "resource_group_name" {
  description = "Name of the resource group"
  default     = "az104-rg9"
}

variable "location" {
  description = "Azure region for resources"
  default     = "Poland Central"
}

variable "web_app_name" {
  description = "Optional globally unique name for the Linux web app. If null, a deterministic name is generated from the subscription ID."
  type        = string
  default     = null
}

variable "app_service_plan_name" {
  description = "Name of the App Service plan"
  default     = "az104-asp9"
}

variable "sku_name" {
  description = "App Service plan SKU. Premium V3 P1V3 is required for deployment slots and autoscale features in this lab."
  default     = "P0v4"
}

variable "php_version" {
  description = "PHP runtime version for the web app and staging slot"
  default     = "8.2"
}

variable "repository_url" {
  description = "External Git repository used by the staging slot deployment center"
  default     = "https://github.com/Azure-Samples/php-docs-hello-world"
}

variable "repository_branch" {
  description = "External Git branch used by the staging slot deployment center"
  default     = "master"
}

variable "swap_staging_to_production" {
  description = "When true, swaps the staging slot into production after the GitHub deployment is configured."
  type        = bool
  default     = true
}

variable "autoscale_minimum_capacity" {
  description = "Minimum number of App Service plan instances"
  default     = 1
}

variable "autoscale_default_capacity" {
  description = "Default number of App Service plan instances"
  default     = 1
}

variable "autoscale_maximum_capacity" {
  description = "Maximum number of App Service plan instances. Matches the lab maximum burst value of 2."
  default     = 2
}
