terraform {
  backend "azurerm" {
    resource_group_name  = "TfState"
    storage_account_name = "tfstatefile2026"
    container_name       = "tfstate"
    key                  = "rd-pipeline/terraform.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Resource Group
resource "azurerm_resource_group" "rg_rd" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "vnet_rd" {
  name                = "vnet-rd-pharma"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.rg_rd.location
  resource_group_name = azurerm_resource_group.rg_rd.name
}

# Subnet workloads
resource "azurerm_subnet" "snet_rd" {
  name                 = "snet-rd-workloads"
  resource_group_name  = azurerm_resource_group.rg_rd.name
  virtual_network_name = azurerm_virtual_network.vnet_rd.name
  address_prefixes     = ["10.10.1.0/24"]
}

# Subnet Bastion (nom fixe imposé par Azure)
resource "azurerm_subnet" "snet_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg_rd.name
  virtual_network_name = azurerm_virtual_network.vnet_rd.name
  address_prefixes     = ["10.10.2.0/26"]
}

# NSG — SSH restreint GitHub Actions + accès Bastion
resource "azurerm_network_security_group" "nsg_rd" {
  name                = "nsg-rd-pharma"
  location            = azurerm_resource_group.rg_rd.location
  resource_group_name = azurerm_resource_group.rg_rd.name

  security_rule {
    name                       = "AllowSSHFromGitHubActions"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "4.148.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowBastionInbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefix      = "10.10.2.0/26"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenySSHFromInternet"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Association NSG -> Subnet workloads
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.snet_rd.id
  network_security_group_id = azurerm_network_security_group.nsg_rd.id
}

# IP Publique VM (pour Ansible via GitHub Actions)
resource "azurerm_public_ip" "pip_rd" {
  name                = "pip-vm-ds-pharma"
  location            = azurerm_resource_group.rg_rd.location
  resource_group_name = azurerm_resource_group.rg_rd.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# IP Publique Bastion
resource "azurerm_public_ip" "pip_bastion" {
  name                = "pip-bastion-pharma"
  location            = azurerm_resource_group.rg_rd.location
  resource_group_name = azurerm_resource_group.rg_rd.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Azure Bastion
resource "azurerm_bastion_host" "bastion_rd" {
  name                = "bastion-rd-pharma"
  location            = azurerm_resource_group.rg_rd.location
  resource_group_name = azurerm_resource_group.rg_rd.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.snet_bastion.id
    public_ip_address_id = azurerm_public_ip.pip_bastion.id
  }
}

# Network Interface
resource "azurerm_network_interface" "nic_rd" {
  name                = "nic-vm-ds-pharma"
  location            = azurerm_resource_group.rg_rd.location
  resource_group_name = azurerm_resource_group.rg_rd.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_rd.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip_rd.id
  }
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "vm_datascience" {
  name                            = var.vm_name
  resource_group_name             = azurerm_resource_group.rg_rd.name
  location                        = azurerm_resource_group.rg_rd.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic_rd.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    projet      = "PharmaLink-PFE"
    pipeline    = "R&D"
    environment = "simulation"
  }
}
# Récupération du contexte client (tenant_id, object_id)
data "azurerm_client_config" "current" {}

# Azure Key Vault — secrets R&D
resource "azurerm_key_vault" "kv_rd" {
  name                       = "kv-pharma-devsecops"
  location                   = azurerm_resource_group.rg_rd.location
  resource_group_name        = azurerm_resource_group.rg_rd.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  tags = {
    projet      = "PharmaLink-PFE"
    pipeline    = "R&D"
    compliance  = "gmp"
  }
}

# Politique d'accès pour le Service Principal du pipeline
resource "azurerm_key_vault_access_policy" "pipeline_sp" {
  key_vault_id = azurerm_key_vault.kv_rd.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "List", "Set", "Delete", "Purge", "Recover"]
}

# Politique d'accès en lecture seule pour la Managed Identity de la VM
resource "azurerm_key_vault_access_policy" "vm_mi" {
  key_vault_id = azurerm_key_vault.kv_rd.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_virtual_machine.vm_datascience.identity[0].principal_id

  secret_permissions = ["Get", "List"]
}

# Secret — mot de passe admin de la VM
resource "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "vm-admin-password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.kv_rd.id

  depends_on = [azurerm_key_vault_access_policy.pipeline_sp]
}

# Secret — nom d'utilisateur admin
resource "azurerm_key_vault_secret" "vm_admin_username" {
  name         = "vm-admin-username"
  value        = var.admin_username
  key_vault_id = azurerm_key_vault.kv_rd.id

  depends_on = [azurerm_key_vault_access_policy.pipeline_sp]
}