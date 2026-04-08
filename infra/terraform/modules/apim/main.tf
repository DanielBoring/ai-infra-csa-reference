# ---------------------------------------------------------------------------
# Module: API Management (ADR-005: Consumption default)
# ---------------------------------------------------------------------------

variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tags" { type = map(string) }
variable "sku_name" {
  type    = string
  default = "Consumption_0"
}
variable "publisher_email" { type = string }
variable "publisher_name" {
  type    = string
  default = "AI Infra CSA Reference"
}
variable "identity_ids" {
  type    = list(string)
  default = []
}
variable "use_stub" {
  type    = bool
  default = true
}
variable "ai_foundry_endpoint" {
  type    = string
  default = ""
}

resource "azurerm_api_management" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
  publisher_email     = var.publisher_email
  publisher_name      = var.publisher_name
  sku_name            = var.sku_name

  identity {
    type         = length(var.identity_ids) > 0 ? "SystemAssigned, UserAssigned" : "SystemAssigned"
    identity_ids = var.identity_ids
  }
}

resource "azurerm_api_management_api" "chat" {
  name                = "chat-api"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.this.name
  revision            = "1"
  display_name        = "Chat API"
  path                = "chat"
  protocols           = ["https"]
  service_url         = var.use_stub ? null : var.ai_foundry_endpoint
}

output "id" { value = azurerm_api_management.this.id }
output "name" { value = azurerm_api_management.this.name }
output "gateway_url" { value = azurerm_api_management.this.gateway_url }
