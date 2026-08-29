resource "azurerm_virtual_network" "this" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "web" {
  name                 = "${var.prefix}-web-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.web_subnet_prefix]
}

# Delegated to the Flexible Server so it can be deployed with private access
# inside the VNet instead of requiring a public endpoint.
resource "azurerm_subnet" "db" {
  name                 = "${var.prefix}-db-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.db_subnet_prefix]

  delegation {
    name = "fs-delegation"

    service_delegation {
      name = var.db_engine == "postgresql" ? "Microsoft.DBforPostgreSQL/flexibleServers" : "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_private_dns_zone" "db" {
  name                = var.db_engine == "postgresql" ? "${var.prefix}.postgres.database.azure.com" : "${var.prefix}.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "db" {
  name                  = "${var.prefix}-db-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.db.name
  virtual_network_id    = azurerm_virtual_network.this.id
  resource_group_name   = azurerm_resource_group.this.name
  tags                  = var.tags
}
