variable "prefix" {
  description = "Prefix used to name all resources."
  type        = string
  default     = "webdb"
}

variable "location" {
  description = "Azure region to deploy into. centralus is used by default because it is one of the few regions where this subscription has PostgreSQL Flexible Server capability and open (non-restricted) VM SKUs."
  type        = string
  default     = "centralus"
}

variable "vnet_address_space" {
  description = "Address space for the VNet."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "web_subnet_prefix" {
  description = "Address prefix for the web subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "db_subnet_prefix" {
  description = "Address prefix for the DB subnet."
  type        = string
  default     = "10.0.2.0/24"
}

variable "vm_count" {
  description = "Number of web tier VMs."
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "VM size for the web tier. Standard_B1s/B-series and D-series-v3 are blocked subscription-wide on this Free Subscription (NotAvailableForSubscription), so a newer-generation size that is actually open is used instead."
  type        = string
  default     = "Standard_D2als_v7"
}

variable "admin_username" {
  description = "Admin username for the web tier VMs."
  type        = string
  default     = "azureadmin"
}

variable "allowed_ssh_source_cidr" {
  description = "CIDR allowed to SSH into the web VMs (lock this down to your IP in production)."
  type        = string
  default     = "0.0.0.0/0"
}

variable "db_engine" {
  description = "Database engine to deploy: 'postgresql' or 'mysql'."
  type        = string
  default     = "postgresql"

  validation {
    condition     = contains(["postgresql", "mysql"], var.db_engine)
    error_message = "db_engine must be either 'postgresql' or 'mysql'."
  }
}

variable "db_sku_name" {
  description = "SKU name for the Azure Database Flexible Server."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "db_storage_mb" {
  description = "Storage size in MB for the database server."
  type        = number
  default     = 32768
}

variable "db_version" {
  description = "Engine version. Defaults chosen per engine if left empty."
  type        = string
  default     = ""
}

variable "db_admin_username" {
  description = "Administrator login for the database server."
  type        = string
  default     = "dbadmin"
}

variable "db_name" {
  description = "Name of the default database/schema to create."
  type        = string
  default     = "appdb"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default = {
    Project     = "web-db-tier"
    Environment = "dev"
  }
}
