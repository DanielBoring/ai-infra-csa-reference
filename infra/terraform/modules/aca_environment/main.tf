# ---------------------------------------------------------------------------
# Module: ACA Environment (ADR-008: Consumption plan)
# ---------------------------------------------------------------------------

variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tags" { type = map(string) }
variable "log_analytics_id" { type = string }
variable "log_analytics_key" {
  type      = string
  sensitive = true
}
variable "enable_vnet" {
  type    = bool
  default = false
}
variable "infrastructure_subnet_id" {
  type    = string
  default = null
}

resource "azurerm_container_app_environment" "this" {
  name                           = var.name
  location                       = var.location
  resource_group_name            = var.resource_group_name
  tags                           = var.tags
  log_analytics_workspace_id     = var.log_analytics_id
  infrastructure_subnet_id       = var.enable_vnet ? var.infrastructure_subnet_id : null
  internal_load_balancer_enabled = var.enable_vnet
  zone_redundancy_enabled        = false
}

output "id" { value = azurerm_container_app_environment.this.id }
output "name" { value = azurerm_container_app_environment.this.name }
output "default_domain" { value = azurerm_container_app_environment.this.default_domain }
