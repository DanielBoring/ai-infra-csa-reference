# ---------------------------------------------------------------------------
# Dev Environment Variables
# ---------------------------------------------------------------------------

location            = "eastus2"
environment_name    = "dev"
project_name        = "ai-infra-ref"
resource_group_name = "rg-ai-infra-ref-dev"
cost_center         = "development"
owner               = "infra-csa-team"
data_classification = "general"

# Networking: public baseline
enable_private_networking = false

# APIM: Consumption for dev (ADR-005)
apim_sku_name        = "Consumption_0"
apim_publisher_email = "admin@contoso.com"
apim_publisher_name  = "AI Infra CSA Reference"

# Observability
log_retention_days = 30

# ACA: scale to zero (ADR-008)
aca_min_replicas = 0
aca_max_replicas = 3
container_image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"

# AI Foundry: empty = stub (ADR-002)
ai_foundry_endpoint = ""
