# ---------------------------------------------------------------------------
# Module: Application Insights
# ---------------------------------------------------------------------------

variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tags" { type = map(string) }
variable "workspace_id" { type = string }

resource "azurerm_application_insights" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
  workspace_id        = var.workspace_id
  application_type    = "web"
}

output "id" { value = azurerm_application_insights.this.id }
output "name" { value = azurerm_application_insights.this.name }
output "instrumentation_key" {
  value     = azurerm_application_insights.this.instrumentation_key
  sensitive = true
}
output "connection_string" {
  value     = azurerm_application_insights.this.connection_string
  sensitive = true
}
