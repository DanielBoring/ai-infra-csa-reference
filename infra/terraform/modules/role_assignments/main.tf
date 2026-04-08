# ---------------------------------------------------------------------------
# Module: Role Assignments (ADR-003: least-privilege RBAC)
# ---------------------------------------------------------------------------

variable "principal_id" {
  description = "Principal ID of the Managed Identity."
  type        = string
}
variable "key_vault_id" {
  description = "Key Vault resource ID."
  type        = string
}
variable "apim_id" {
  description = "APIM resource ID."
  type        = string
}

# Key Vault Secrets User
resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.principal_id
}

# Reader on APIM
resource "azurerm_role_assignment" "apim_reader" {
  scope                = var.apim_id
  role_definition_name = "Reader"
  principal_id         = var.principal_id
}
