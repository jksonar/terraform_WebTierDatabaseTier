output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "load_balancer_public_ip" {
  description = "Public IP address to reach the web tier through the load balancer."
  value       = azurerm_public_ip.lb.ip_address
}

output "web_vm_names" {
  value = azurerm_linux_virtual_machine.web[*].name
}

output "web_vm_private_ips" {
  value = azurerm_network_interface.web[*].private_ip_address
}

output "vm_ssh_private_key_path" {
  description = "Path to the generated SSH private key for the web VMs (used for SSH via bastion/VPN; VMs have no public IP)."
  value       = local_sensitive_file.vm_ssh_private_key.filename
}

output "database_engine" {
  value = var.db_engine
}

output "database_fqdn" {
  value = var.db_engine == "postgresql" ? azurerm_postgresql_flexible_server.this[0].fqdn : azurerm_mysql_flexible_server.this[0].fqdn
}

output "database_admin_username" {
  value = var.db_admin_username
}

output "database_admin_password" {
  value     = random_password.db_admin.result
  sensitive = true
}
