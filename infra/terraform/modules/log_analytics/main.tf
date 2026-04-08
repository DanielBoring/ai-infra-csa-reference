# ---------------------------------------------------------------------------
# Module: Log Analytics Workspace
# ---------------------------------------------------------------------------

variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tags" { type = map(string) }
variable "retention_in_days" {
  type    = number
  default = 30
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
}

output "id" { value = azurerm_log_analytics_workspace.this.id }
output "name" { value = azurerm_log_analytics_workspace.this.name }
output "workspace_id" { value = azurerm_log_analytics_workspace.this.workspace_id }
output "primary_shared_key" {
  value     = azurerm_log_analytics_workspace.this.primary_shared_key
  sensitive = true
}
