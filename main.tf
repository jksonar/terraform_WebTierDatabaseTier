resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  name_suffix = random_id.suffix.hex
  db_version  = var.db_version != "" ? var.db_version : (var.db_engine == "postgresql" ? "16" : "8.0.21")
}

resource "azurerm_resource_group" "this" {
  name     = "${var.prefix}-rg"
  location = var.location
  tags     = var.tags
}
