# ---------------------------------------------------------------------------
# Module: Container App (Chatbot)
# ---------------------------------------------------------------------------

variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tags" { type = map(string) }
variable "environment_id" { type = string }
variable "identity_id" { type = string }
variable "identity_client_id" { type = string }
variable "container_image" { type = string }
variable "min_replicas" {
  type    = number
  default = 0
}
variable "max_replicas" {
  type    = number
  default = 5
}
variable "apim_gateway_url" { type = string }
variable "app_insights_connection_string" {
  type      = string
  sensitive = true
}

resource "azurerm_container_app" "this" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.environment_id
  tags                         = var.tags
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "chatbot"
      image  = var.container_image
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "APIM_ENDPOINT"
        value = var.apim_gateway_url
      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = var.identity_client_id
      }
      env {
        name        = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        secret_name = "appinsights-cs"
      }
      env {
        name  = "NODE_ENV"
        value = "production"
      }
      env {
        name  = "PORT"
        value = "3000"
      }
    }

    http_scale_rule {
      name                = "http-scaling"
      concurrent_requests = "10"
    }
  }

  secret {
    name  = "appinsights-cs"
    value = var.app_insights_connection_string
  }

  ingress {
    target_port      = 3000
    external_enabled = true
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

output "id" { value = azurerm_container_app.this.id }
output "name" { value = azurerm_container_app.this.name }
output "fqdn" { value = azurerm_container_app.this.ingress[0].fqdn }
