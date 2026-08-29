resource "random_password" "db_admin" {
  length      = 20
  special     = true
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
  # Flexible Server rejects a handful of punctuation characters in passwords.
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_postgresql_flexible_server" "this" {
  count = var.db_engine == "postgresql" ? 1 : 0

  name                = "${var.prefix}-psql-${local.name_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  version             = local.db_version

  administrator_login    = var.db_admin_username
  administrator_password = random_password.db_admin.result

  storage_mb = var.db_storage_mb
  sku_name   = var.db_sku_name

  delegated_subnet_id           = azurerm_subnet.db.id
  private_dns_zone_id           = azurerm_private_dns_zone.db.id
  public_network_access_enabled = false

  zone = "1"

  tags = var.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.db]
}

resource "azurerm_postgresql_flexible_server_database" "this" {
  count     = var.db_engine == "postgresql" ? 1 : 0
  name      = var.db_name
  server_id = azurerm_postgresql_flexible_server.this[0].id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

resource "azurerm_mysql_flexible_server" "this" {
  count = var.db_engine == "mysql" ? 1 : 0

  name                = "${var.prefix}-mysql-${local.name_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  version             = local.db_version

  administrator_login    = var.db_admin_username
  administrator_password = random_password.db_admin.result

  storage {
    size_gb = ceil(var.db_storage_mb / 1024)
  }

  sku_name = var.db_sku_name

  delegated_subnet_id = azurerm_subnet.db.id
  private_dns_zone_id = azurerm_private_dns_zone.db.id

  zone = "1"

  tags = var.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.db]
}

resource "azurerm_mysql_flexible_database" "this" {
  count               = var.db_engine == "mysql" ? 1 : 0
  name                = var.db_name
  resource_group_name = azurerm_resource_group.this.name
  server_name         = azurerm_mysql_flexible_server.this[0].name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}
