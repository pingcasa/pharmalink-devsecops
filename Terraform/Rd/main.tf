terraform {
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

# Subnet
resource "azurerm_subnet" "snet_rd" {
  name                 = "snet-rd-workloads"
  resource_group_name  = azurerm_resource_group.rg_rd.name
  virtual_network_name = azurerm_virtual_network.vnet_rd.name
  address_prefixes     = ["10.10.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "nsg_rd" {
  name                = "nsg-rd-pharma"
  location            = azurerm_resource_group.rg_rd.location
  resource_group_name = azurerm_resource_group.rg_rd.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
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

# Association NSG -> Subnet
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.snet_rd.id
  network_security_group_id = azurerm_network_security_group.nsg_rd.id
}

# IP Publique
resource "azurerm_public_ip" "pip_rd" {
  name                = "pip-vm-ds-pharma"
  location            = azurerm_resource_group.rg_rd.location
  resource_group_name = azurerm_resource_group.rg_rd.name
  allocation_method   = "Static"
  sku                 = "Standard"
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