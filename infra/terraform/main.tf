# ---------------------------------------------------------------------------
# AI Infrastructure CSA Reference — Root Module
# ---------------------------------------------------------------------------
# Orchestrates all child modules. Equivalent to infra/bicep/main.bicep.
# ---------------------------------------------------------------------------

locals {
  name_suffix = "${var.project_name}-${var.environment_name}"
  use_stub    = var.ai_foundry_endpoint == ""

  tags = {
    environment         = var.environment_name
    project             = var.project_name
    cost-center         = var.cost_center
    owner               = var.owner
    data-classification = var.data_classification
    managed-by          = "terraform"
  }
}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# ---------------------------------------------------------------------------
# Module: User-Assigned Managed Identity
# ---------------------------------------------------------------------------

module "managed_identity" {
  source = "./modules/managed_identity"

  name                = "id-${local.name_suffix}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.tags
}

# ---------------------------------------------------------------------------
# Module: Log Analytics Workspace
# ---------------------------------------------------------------------------

module "log_analytics" {
  source = "./modules/log_analytics"

  name                = "law-${local.name_suffix}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.tags
  retention_in_days   = var.log_retention_days
}

# ---------------------------------------------------------------------------
# Module: Application Insights
# ---------------------------------------------------------------------------

module "app_insights" {
  source = "./modules/app_insights"

  name                = "appi-${local.name_suffix}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.tags
  workspace_id        = module.log_analytics.id
}

# ---------------------------------------------------------------------------
# Module: Key Vault
# ---------------------------------------------------------------------------

module "key_vault" {
  source = "./modules/key_vault"

  name                = "kv${replace(local.name_suffix, "-", "")}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.tags
}

# ---------------------------------------------------------------------------
# Module: API Management
# ---------------------------------------------------------------------------

module "apim" {
  source = "./modules/apim"

  name                = "apim-${local.name_suffix}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.tags
  sku_name            = var.apim_sku_name
  publisher_email     = var.apim_publisher_email
  publisher_name      = var.apim_publisher_name
  identity_ids        = [module.managed_identity.id]
  use_stub            = local.use_stub
  ai_foundry_endpoint = var.ai_foundry_endpoint
}

# ---------------------------------------------------------------------------
# Module: ACA Environment
# ---------------------------------------------------------------------------

module "aca_environment" {
  source = "./modules/aca_environment"

  name                   = "acaenv-${local.name_suffix}"
  location               = var.location
  resource_group_name    = data.azurerm_resource_group.main.name
  tags                   = local.tags
  log_analytics_id       = module.log_analytics.id
  log_analytics_key      = module.log_analytics.primary_shared_key
  enable_vnet            = var.enable_private_networking
  infrastructure_subnet_id = var.enable_private_networking ? module.vnet[0].aca_subnet_id : null
}

# ---------------------------------------------------------------------------
# Module: Container App (Chatbot)
# ---------------------------------------------------------------------------

module "container_app" {
  source = "./modules/container_app"

  name                          = "app-${local.name_suffix}"
  location                      = var.location
  resource_group_name           = data.azurerm_resource_group.main.name
  tags                          = local.tags
  environment_id                = module.aca_environment.id
  identity_id                   = module.managed_identity.id
  identity_client_id            = module.managed_identity.client_id
  container_image               = var.container_image
  min_replicas                  = var.aca_min_replicas
  max_replicas                  = var.aca_max_replicas
  apim_gateway_url              = module.apim.gateway_url
  app_insights_connection_string = module.app_insights.connection_string
}

# ---------------------------------------------------------------------------
# Module: Role Assignments
# ---------------------------------------------------------------------------

module "role_assignments" {
  source = "./modules/role_assignments"

  principal_id   = module.managed_identity.principal_id
  key_vault_id   = module.key_vault.id
  apim_id        = module.apim.id
}

# ---------------------------------------------------------------------------
# Module: VNet + Private Networking (conditional)
# ---------------------------------------------------------------------------

module "vnet" {
  count  = var.enable_private_networking ? 1 : 0
  source = "./modules/vnet"

  name                = "vnet-${local.name_suffix}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.tags
  address_prefix      = var.vnet_address_prefix
  aca_subnet_prefix   = var.aca_subnet_prefix
  pe_subnet_prefix    = var.pe_subnet_prefix
}
