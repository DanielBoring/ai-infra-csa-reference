# ---------------------------------------------------------------------------
# Module: Virtual Network + Subnets (Private Networking)
# ---------------------------------------------------------------------------

variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tags" { type = map(string) }
variable "address_prefix" {
  type    = string
  default = "10.0.0.0/16"
}
variable "aca_subnet_prefix" {
  type    = string
  default = "10.0.0.0/23"
}
variable "pe_subnet_prefix" {
  type    = string
  default = "10.0.2.0/24"
}

resource "azurerm_virtual_network" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
  address_space       = [var.address_prefix]
}

resource "azurerm_subnet" "aca" {
  name                 = "snet-aca"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.aca_subnet_prefix]

  delegation {
    name = "aca-delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "pe" {
  name                 = "snet-pe"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.pe_subnet_prefix]
}

output "id" { value = azurerm_virtual_network.this.id }
output "name" { value = azurerm_virtual_network.this.name }
output "aca_subnet_id" { value = azurerm_subnet.aca.id }
output "pe_subnet_id" { value = azurerm_subnet.pe.id }
