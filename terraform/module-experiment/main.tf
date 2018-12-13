# Secrets
variable "subscription_id" {}

variable "client_id" {}

variable "client_secret" {}

variable "tenant_id" {}

# Variables
variable "eventhub_partition_count" {
  default = 32
}

variable "eventhub_namespace_capacity" {
  default = 20
}

variable "region" {
  default = "Southeast Asia"
}

variable "function_app_prefetch_count" {
  default = 0
}

variable "function_app_max_batch_size" {
  default = 64
}
variable "function_app_batch_checkpoint_frequency" {
  default = 10
}
variable "language" {
  default = "nodejs"
}

# Providers
provider "azurerm" {
  version         = ">=1.19.0"
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}

provider "random" {
  version = "2.0"
}

resource "random_string" "suffix" {
  length  = 8
  upper   = false
  lower   = true
  special = false
}

# Common tags
locals {
  common_tags = {
    eventhub_partition_count                = "${var.eventhub_partition_count}"
    eventhub_namespace_capacity             = "${var.eventhub_namespace_capacity}"
    function_app_max_batch_size             = "${var.function_app_max_batch_size}"
    function_app_prefetch_count             = "${var.function_app_prefetch_count}"
    function_app_batch_checkpoint_frequency = "${var.function_app_batch_checkpoint_frequency}"
    language                                = "${var.language}"
  }

  connection_string = "${azurerm_eventhub_namespace.experiment.default_primary_connection_string};TransportType=Amqp;EntityPath=${azurerm_eventhub.experiment.name}"
}

# Resource Group - helper
resource "azurerm_resource_group" "telemetry" {
  name     = "rg-telemetry"
  location = "${var.region}"
}

# Log Management Workspace
resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = "oms-${var.language}-${var.eventhub_namespace_capacity}-${var.eventhub_partition_count}-${var.function_app_max_batch_size}-${var.function_app_prefetch_count}-${var.function_app_batch_checkpoint_frequency}"
  location            = "${azurerm_resource_group.telemetry.location}"
  resource_group_name = "${azurerm_resource_group.telemetry.name}"
  sku                 = "Standalone"
  retention_in_days   = 30
  tags                = "${local.common_tags}"
}

# App Insights - nodejs
resource "azurerm_application_insights" "application_insights" {
  name                = "ai-${var.language}-${var.eventhub_namespace_capacity}-${var.eventhub_partition_count}-${var.function_app_max_batch_size}-${var.function_app_prefetch_count}-${var.function_app_batch_checkpoint_frequency}"
  location            = "${azurerm_resource_group.telemetry.location}"
  resource_group_name = "${azurerm_resource_group.telemetry.name}"
  application_type    = "Web"
  tags                = "${local.common_tags}"
}

# Resource Group
resource "azurerm_resource_group" "experiment" {
  name     = "rg-experiment"
  location = "${var.region}"
  tags     = "${local.common_tags}"
}

# Event Hub
resource "azurerm_eventhub_namespace" "experiment" {
  name                = "eh-ns-${var.language}-${random_string.suffix.result}"
  location            = "${azurerm_resource_group.experiment.location}"
  resource_group_name = "${azurerm_resource_group.experiment.name}"
  sku                 = "Standard"
  capacity            = "${var.eventhub_namespace_capacity}"
  tags                = "${local.common_tags}"
}

resource "azurerm_eventhub" "experiment" {
  name                = "eh"
  namespace_name      = "${azurerm_eventhub_namespace.experiment.name}"
  resource_group_name = "${azurerm_resource_group.experiment.name}"
  partition_count     = "${var.eventhub_partition_count}"
  message_retention   = 1
}

# Diagnostic Setting for Event Hub
resource "azurerm_monitor_diagnostic_setting" "diagnostics_eh" {
  name                       = "diag_eh_${var.language}_${random_string.suffix.result}"
  target_resource_id         = "${azurerm_eventhub_namespace.experiment.id}"
  log_analytics_workspace_id = "${azurerm_log_analytics_workspace.log_analytics.id}"

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = true
      days    = 0
    }
  }
}

# Diagnostic Setting for Function App
resource "azurerm_monitor_diagnostic_setting" "diagnostics_fa" {
  name                       = "diag_fa_${var.language}_${random_string.suffix.result}"
  target_resource_id         = "${azurerm_function_app.experiment.id}"
  log_analytics_workspace_id = "${azurerm_log_analytics_workspace.log_analytics.id}"

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = true
      days    = 0
    }
  }
}

# Diagnostic Setting for App Service Plan
resource "azurerm_monitor_diagnostic_setting" "diagnostics_asp" {
  name                       = "diag_asp_${var.language}_${random_string.suffix.result}"
  target_resource_id         = "${azurerm_app_service_plan.experiment.id}"
  log_analytics_workspace_id = "${azurerm_log_analytics_workspace.log_analytics.id}"

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = true
      days    = 0
    }
  }
}

# Azure Function
resource "azurerm_storage_account" "experiment" {
  name                     = "sa${var.language}${random_string.suffix.result}"
  location                 = "${azurerm_resource_group.experiment.location}"
  resource_group_name      = "${azurerm_resource_group.experiment.name}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"
  account_kind             = "StorageV2"
  tags                     = "${local.common_tags}"
}

resource "azurerm_app_service_plan" "experiment" {
  name                = "asp-${var.language}-${random_string.suffix.result}"
  location            = "${azurerm_resource_group.experiment.location}"
  resource_group_name = "${azurerm_resource_group.experiment.name}"
  kind                = "FunctionApp"
  tags                = "${local.common_tags}"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "experiment" {
  name                      = "af-${var.language}-${random_string.suffix.result}"
  location                  = "${azurerm_resource_group.experiment.location}"
  resource_group_name       = "${azurerm_resource_group.experiment.name}"
  app_service_plan_id       = "${azurerm_app_service_plan.experiment.id}"
  storage_connection_string = "${azurerm_storage_account.experiment.primary_connection_string}"
  version                   = "~2"
  tags                      = "${local.common_tags}"
  enable_builtin_logging    = false

  app_settings {
    APPINSIGHTS_INSTRUMENTATIONKEY = "${azurerm_application_insights.application_insights.instrumentation_key}"
    EVENT_HUB_CONNECTION_STRING    = "${azurerm_eventhub_namespace.experiment.default_primary_connection_string}"
    FUNCTIONS_WORKER_RUNTIME       = "${var.language}"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
  }

  site_config {
    use_32_bit_worker_process = false
  }

  provisioner "local-exec" {
    command = "az login --service-principal -u ${var.client_id} -p ${var.client_secret} --tenant ${var.tenant_id}"
  }

  provisioner "local-exec" {
    command = "az account set --subscription ${var.subscription_id}"
  }

  provisioner "local-exec" {
    command = "curl -o ./${random_string.suffix.result}.zip -G ${azurerm_function_app.deployment_helper.default_hostname}/deploy -d language=${var.language} -d batch=${var.function_app_max_batch_size} -d prefetch=${var.function_app_prefetch_count} -d checkpoint=${var.function_app_batch_checkpoint_frequency}"
  }

  provisioner "local-exec" {
    command = "az functionapp deployment source config-zip --ids ${azurerm_function_app.experiment.id} --src ./${random_string.suffix.result}.zip"
  }
}

# Azure Function - deployment helper
resource "azurerm_storage_account" "deployment_helper" {
  name                     = "sahelper${random_string.suffix.result}"
  location                 = "${azurerm_resource_group.experiment.location}"
  resource_group_name      = "${azurerm_resource_group.experiment.name}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"
  account_kind             = "StorageV2"
  tags                     = "${local.common_tags}"
}

resource "azurerm_app_service_plan" "deployment_helper" {
  name                = "asp-helper-${random_string.suffix.result}"
  location            = "${azurerm_resource_group.experiment.location}"
  resource_group_name = "${azurerm_resource_group.experiment.name}"
  kind                = "FunctionApp"
  tags                = "${local.common_tags}"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "deployment_helper" {
  name                      = "af-helper-${random_string.suffix.result}"
  location                  = "${azurerm_resource_group.experiment.location}"
  resource_group_name       = "${azurerm_resource_group.experiment.name}"
  app_service_plan_id       = "${azurerm_app_service_plan.deployment_helper.id}"
  storage_connection_string = "${azurerm_storage_account.deployment_helper.primary_connection_string}"
  version                   = "~2"
  tags                      = "${local.common_tags}"

  app_settings {
    WEBSITE_RUN_FROM_PACKAGE = "https://github.com/iizotov/azure-functions-scaleout/releases/download/latest/deploymenthelper.zip"
    NODEJS_TEMPLATE_URL      = "https://github.com/iizotov/azure-functions-scaleout/releases/download/latest/nodejs-template.zip"
    DOTNET_TEMPLATE_URL      = "https://github.com/iizotov/azure-functions-scaleout/releases/download/latest/dotnet-template.zip"
    FUNCTIONS_WORKER_RUNTIME = "dotnet"
  }
}

# Azure Container Instance - workload generator
resource "azurerm_container_group" "aci" {
  name                = "aci-${var.language}-${random_string.suffix.result}-${count.index}"
  location            = "${azurerm_resource_group.experiment.location}"
  resource_group_name = "${azurerm_resource_group.experiment.name}"
  dns_name_label      = "aci-${var.language}-${random_string.suffix.result}-${count.index}"
  os_type             = "Linux"
  restart_policy      = "Never"
  tags                = "${local.common_tags}"
  ip_address_type     = "Public"
  count               = 5

  container {
    name   = "loadgen-${var.language}"
    image  = "iizotov/azure-sb-loadgenerator-dotnetcore:latest"
    cpu    = "2"
    memory = "7"
    port   = "80"

    environment_variables {
      NUM_ITERATIONS      = "4"
      CONNECTION_STRING_1 = "${local.connection_string}"
      CONNECTION_STRING_3 = "${local.connection_string}"
      CONNECTION_STRING_4 = "${local.connection_string}"
      CONNECTION_STRING_2 = "${local.connection_string}"
      INITIAL_SLEEP       = "5m"
      TERMINATE_AFTER_1   = "3600"
      TERMINATE_AFTER_2   = "3600"
      TERMINATE_AFTER_3   = "3600"
      TERMINATE_AFTER_4   = "3600"
      BATCH_1             = "1"
      BATCH_2             = "1"
      BATCH_3             = "10"
      BATCH_4             = "50"
      THROUGHPUT_1        = "5"
      THROUGHPUT_2        = "0"
      THROUGHPUT_3        = "0"
      THROUGHPUT_4        = "0"
      SIZE_1              = "35"
      SIZE_2              = "35"
      SIZE_3              = "35"
      SIZE_4              = "35"
      SERVICE_1           = "eh"
      SERVICE_2           = "eh"
      SERVICE_3           = "eh"
      SERVICE_4           = "eh"
    }

    commands = ["/bin/bash", "./run.sh"]
  }
}
