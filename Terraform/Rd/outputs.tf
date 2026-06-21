output "resource_group_name" {
  description = "Nom du Resource Group créé"
  value       = azurerm_resource_group.rg_rd.name
}

output "vm_name" {
  description = "Nom de la VM"
  value       = azurerm_linux_virtual_machine.vm_datascience.name
}

output "vm_public_ip" {
  description = "IP publique de la VM"
  value       = azurerm_public_ip.pip_rd.ip_address
}

output "vm_private_ip" {
  description = "IP privée de la VM"
  value       = azurerm_network_interface.nic_rd.private_ip_address
}

output "vm_size" {
  description = "Taille de la VM"
  value       = azurerm_linux_virtual_machine.vm_datascience.size
}