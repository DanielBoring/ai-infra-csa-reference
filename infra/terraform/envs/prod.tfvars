# ---------------------------------------------------------------------------
# Production Environment Variables
# ---------------------------------------------------------------------------

location            = "eastus2"
environment_name    = "prod"
project_name        = "ai-infra-ref"
resource_group_name = "rg-ai-infra-ref-prod"
cost_center         = "production"
owner               = "infra-csa-team"
data_classification = "confidential"

# Networking: private for production
enable_private_networking = true
vnet_address_prefix       = "10.0.0.0/16"
aca_subnet_prefix         = "10.0.0.0/23"
pe_subnet_prefix          = "10.0.2.0/24"

# APIM: Standard v2 for production (VNet support, no cold starts)
apim_sku_name        = "StandardV2_1"
apim_publisher_email = "admin@contoso.com"
apim_publisher_name  = "AI Infra CSA Reference"

# Observability: longer retention
log_retention_days = 90

# ACA: min 1 for production (no cold starts)
aca_min_replicas = 1
aca_max_replicas = 10
container_image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"

# AI Foundry: set real endpoint for production
# ai_foundry_endpoint = "https://<your-foundry>.openai.azure.com/openai/deployments/<deployment>"
ai_foundry_endpoint = ""
