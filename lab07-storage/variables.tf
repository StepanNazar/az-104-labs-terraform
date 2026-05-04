variable "resource_group_name" {
  description = "Name of the resource group"
  default     = "az104-rg7"
}

variable "location" {
  description = "Azure region for resources"
  default     = "Poland Central"
}

variable "storage_account_name" {
  description = "Optional globally unique name for the storage account. If null, a deterministic name is generated from the subscription ID."
  type        = string
  default     = null
}

variable "blob_container_name" {
  description = "Blob container name"
  default     = "data"
}

variable "file_share_name" {
  description = "Azure file share name"
  default     = "share1"
}

variable "file_share_quota_gb" {
  description = "Quota for the Azure file share in GiB"
  default     = 100
}

variable "client_ipv4_cidrs" {
  description = "Optional public IPv4 CIDR ranges to keep client access after the storage firewall is applied."
  type        = list(string)
  default     = []
}
