# Variables
variable "region" {
  default = "Southeast Asia"
}

# Providers
provider "random" {
  version = "2.0"
}

resource "random_string" "suffix" {
  length  = 8
  upper   = false
  lower   = true
  special = false
}

# Resource Group - telemetry
resource "azurerm_resource_group" "telemetry" {
  name     = "rg-telemetry-${random_string.suffix.result}"
  location = "${var.region}"
}

# Log Management Workspace
resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = "oms-${random_string.suffix.result}"
  location            = "${azurerm_resource_group.telemetry.location}"
  resource_group_name = "${azurerm_resource_group.telemetry.name}"
  sku                 = "Standalone"
  retention_in_days   = 30
}

# App Insights - nodejs
resource "azurerm_application_insights" "application_insights" {
  name                = "ai"
  location            = "${azurerm_resource_group.telemetry.location}"
  resource_group_name = "${azurerm_resource_group.telemetry.name}"
  application_type    = "Web"
}

output "appinsights_instrumentationkey" {
  value = "${azurerm_application_insights.application_insights.instrumentation_key}"
}

output "log_analytics_workspace_id" {
  value = "${azurerm_log_analytics_workspace.log_analytics.id}"
}
