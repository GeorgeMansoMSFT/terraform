output "admin_username" {
  description = "The admin username for the virtual machine"
  value       = var.admin_username
}

output "vm_public_ip" {
  description = "Public IP address of the deployed virtual machine"
  value       = azurerm_windows_virtual_machine.avd_vm[*].public_ip_address
}

output "workspace_id" {
  description = "ID of the Azure Virtual Desktop Workspace"
  value       = azurerm_virtual_desktop_workspace.workspace.id
}

output "host_pool_id" {
  description = "ID of the Azure Virtual Desktop Host Pool"
  value       = azurerm_virtual_desktop_host_pool.hostpool.id
}