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
  # sku                 = "Standalone"
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# App Insights - nodejs
resource "azurerm_application_insights" "application_insights" {
  name                = "ai-${random_string.suffix.result}"
  location            = "${azurerm_resource_group.telemetry.location}"
  resource_group_name = "${azurerm_resource_group.telemetry.name}"
  application_type    = "Web"
}

resource "azurerm_storage_account" "sa_telemetry" {
  name                     = "satelemetry${random_string.suffix.result}"
  location                 = "${azurerm_resource_group.telemetry.location}"
  resource_group_name      = "${azurerm_resource_group.telemetry.name}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"
  account_kind             = "StorageV2"
}

# Azure Function - deployment helper
resource "azurerm_storage_account" "deployment_helper" {
  name                     = "sahelper${random_string.suffix.result}"
  location                 = "${azurerm_resource_group.telemetry.location}"
  resource_group_name      = "${azurerm_resource_group.telemetry.name}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"
  account_kind             = "StorageV2"
}

#Deployment Helper
resource "azurerm_app_service_plan" "deployment_helper" {
  name                = "asp-helper-${random_string.suffix.result}"
  location            = "${azurerm_resource_group.telemetry.location}"
  resource_group_name = "${azurerm_resource_group.telemetry.name}"
  kind                = "FunctionApp"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "deployment_helper" {
  name                      = "af-helper-${random_string.suffix.result}"
  location                  = "${azurerm_resource_group.telemetry.location}"
  resource_group_name       = "${azurerm_resource_group.telemetry.name}"
  app_service_plan_id       = "${azurerm_app_service_plan.deployment_helper.id}"
  storage_connection_string = "${azurerm_storage_account.deployment_helper.primary_connection_string}"
  version                   = "~2"

  app_settings {
    WEBSITE_RUN_FROM_PACKAGE = "https://github.com/iizotov/azure-functions-scaleout/releases/download/latest/deploymenthelper.zip"
    NODEJS_TEMPLATE_URL      = "https://github.com/iizotov/azure-functions-scaleout/releases/download/latest/nodejs-template.zip"
    DOTNET_TEMPLATE_URL      = "https://github.com/iizotov/azure-functions-scaleout/releases/download/latest/dotnet-template.zip"
    FUNCTIONS_WORKER_RUNTIME = "dotnet"
  }
}

output "appinsights_instrumentationkey" {
  value = "${azurerm_application_insights.application_insights.instrumentation_key}"
}

output "log_analytics_workspace_id" {
  value = "${azurerm_log_analytics_workspace.log_analytics.id}"
}

output "sa_telemetry_account_id" {
  value = "${azurerm_storage_account.sa_telemetry.id}"
}

output "deployment_helper_hostname" {
  value = "${azurerm_function_app.deployment_helper.default_hostname}"
}

