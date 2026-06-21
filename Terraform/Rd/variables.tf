variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "location" {
  description = "Region Azure"
  type        = string
  default     = "West Europe"
}

variable "resource_group_name" {
  description = "Nom du Resource Group"
  type        = string
  default     = "rg-rd-pharma"
}

variable "vm_name" {
  description = "Nom de la VM"
  type        = string
  default     = "vm-ds-pharma"
}

variable "vm_size" {
  description = "Taille de la VM"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Utilisateur admin VM"
  type        = string
  default     = "pharmaadmin"
}

variable "admin_password" {
  description = "Mot de passe admin VM"
  type        = string
  sensitive   = true
}