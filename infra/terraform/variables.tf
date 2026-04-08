# ---------------------------------------------------------------------------
# AI Infrastructure CSA Reference — Input Variables
# ---------------------------------------------------------------------------

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus2"
}

variable "environment_name" {
  description = "Environment name used for naming and tagging."
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment_name)
    error_message = "environment_name must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Project name prefix for resource naming."
  type        = string
  default     = "ai-infra-ref"
}

variable "resource_group_name" {
  description = "Name of the resource group. Created externally or by CI."
  type        = string
}

variable "cost_center" {
  description = "Cost center tag value."
  type        = string
  default     = ""
}

variable "owner" {
  description = "Owner tag value."
  type        = string
  default     = ""
}

variable "data_classification" {
  description = "Data classification for tagging."
  type        = string
  default     = "general"
  validation {
    condition     = contains(["general", "confidential", "highly-confidential"], var.data_classification)
    error_message = "data_classification must be one of: general, confidential, highly-confidential."
  }
}

# --- Networking ---

variable "enable_private_networking" {
  description = "Enable private networking (VNet, PEs, Private DNS Zones)."
  type        = bool
  default     = false
}

variable "vnet_address_prefix" {
  description = "VNet address prefix (used when enable_private_networking=true)."
  type        = string
  default     = "10.0.0.0/16"
}

variable "aca_subnet_prefix" {
  description = "ACA subnet prefix (minimum /23)."
  type        = string
  default     = "10.0.0.0/23"
}

variable "pe_subnet_prefix" {
  description = "Private Endpoint subnet prefix."
  type        = string
  default     = "10.0.2.0/24"
}

# --- APIM ---

variable "apim_sku_name" {
  description = "APIM SKU name."
  type        = string
  default     = "Consumption_0"
  validation {
    condition     = contains(["Consumption_0", "Developer_1", "StandardV2_1"], var.apim_sku_name)
    error_message = "apim_sku_name must be one of: Consumption_0, Developer_1, StandardV2_1."
  }
}

variable "apim_publisher_email" {
  description = "APIM publisher email (required)."
  type        = string
}

variable "apim_publisher_name" {
  description = "APIM publisher display name."
  type        = string
  default     = "AI Infra CSA Reference"
}

# --- Observability ---

variable "log_retention_days" {
  description = "Log Analytics retention in days."
  type        = number
  default     = 30
  validation {
    condition     = var.log_retention_days >= 7 && var.log_retention_days <= 730
    error_message = "log_retention_days must be between 7 and 730."
  }
}

# --- ACA ---

variable "aca_min_replicas" {
  description = "ACA minimum replicas (0 = scale to zero)."
  type        = number
  default     = 0
}

variable "aca_max_replicas" {
  description = "ACA maximum replicas."
  type        = number
  default     = 5
}

variable "container_image" {
  description = "Container image for the chatbot app."
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}

# --- AI Foundry ---

variable "ai_foundry_endpoint" {
  description = "Real Azure AI Foundry endpoint URL. Leave empty to use stub."
  type        = string
  default     = ""
}
