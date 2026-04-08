# ---------------------------------------------------------------------------
# AI Infrastructure CSA Reference — Outputs
# ---------------------------------------------------------------------------

output "aca_fqdn" {
  description = "FQDN of the Container App."
  value       = module.container_app.fqdn
}

output "apim_gateway_url" {
  description = "APIM gateway URL."
  value       = module.apim.gateway_url
}

output "app_insights_name" {
  description = "Application Insights resource name."
  value       = module.app_insights.name
}

output "key_vault_name" {
  description = "Key Vault name."
  value       = module.key_vault.name
}

output "log_analytics_name" {
  description = "Log Analytics workspace name."
  value       = module.log_analytics.name
}

output "managed_identity_client_id" {
  description = "Managed Identity client ID."
  value       = module.managed_identity.client_id
}

output "use_stub" {
  description = "Whether the Foundry stub is being used."
  value       = local.use_stub
}
