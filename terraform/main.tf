# Secrets
variable "subscription_id" {}

variable "client_id" {}

variable "client_secret" {}

variable "tenant_id" {}

# Variables
variable "eventhub_partition_count" {}

variable "eventhub_namespace_capacity" {}

variable "region" {}

variable "function_app_prefetch_count" {}

variable "function_app_max_batch_size" {}

variable "function_app_batch_checkpoint_frequency" {}

# Providers
provider "random" {
  version = "2.0"
}

provider "azurerm" {
  version         = ">=1.19.0"
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
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
  }

  dotnet_connection_string = "${azurerm_eventhub_namespace.experiment_dotnet.default_primary_connection_string};TransportType=Amqp;EntityPath=${azurerm_eventhub.experiment_dotnet.name}"
  nodejs_connection_string = "${azurerm_eventhub_namespace.experiment_nodejs.default_primary_connection_string};TransportType=Amqp;EntityPath=${azurerm_eventhub.experiment_nodejs.name}"
}

# App Insights - shared across all experiments
resource "azurerm_resource_group" "application_insights" {
  name     = "rg-appinsights"
  location = "${var.region}"

  lifecycle {
    ignore_changes = "*"
  }
}

resource "azurerm_application_insights" "application_insights" {
  name                = "appinsights"
  location            = "Southeast Asia"
  resource_group_name = "${azurerm_resource_group.application_insights.name}"
  application_type    = "Web"

  lifecycle {
    ignore_changes = "*"
  }
}

# Resource Group per experiment
resource "azurerm_resource_group" "experiment" {
  name     = "rg-eh-${var.eventhub_namespace_capacity}-${var.eventhub_partition_count}-${var.function_app_max_batch_size}-${var.function_app_prefetch_count}-${var.function_app_batch_checkpoint_frequency}-${random_string.suffix.result}"
  location = "${var.region}"
  tags     = "${local.common_tags}"
}

# Event Hub - nodejs
resource "azurerm_eventhub_namespace" "experiment_nodejs" {
  name                = "eh-ns-nodejs-${random_string.suffix.result}"
  location            = "${azurerm_resource_group.experiment.location}"
  resource_group_name = "${azurerm_resource_group.experiment.name}"
  sku                 = "Standard"
  capacity            = "${var.eventhub_namespace_capacity}"
  tags                = "${local.common_tags}"
}

resource "azurerm_eventhub" "experiment_nodejs" {
  name                = "eh-nodejs"
  namespace_name      = "${azurerm_eventhub_namespace.experiment_nodejs.name}"
  resource_group_name = "${azurerm_resource_group.experiment.name}"
  partition_count     = "${var.eventhub_partition_count}"
  message_retention   = 1
}

# Event Hub - dotnet
resource "azurerm_eventhub_namespace" "experiment_dotnet" {
  name                = "eh-ns-dotnet-${random_string.suffix.result}"
  location            = "${azurerm_resource_group.experiment.location}"
  resource_group_name = "${azurerm_resource_group.experiment.name}"
  sku                 = "Standard"
  capacity            = "${var.eventhub_namespace_capacity}"
  tags                = "${local.common_tags}"
}

resource "azurerm_eventhub" "experiment_dotnet" {
  name                = "eh-dotnet"
  namespace_name      = "${azurerm_eventhub_namespace.experiment_dotnet.name}"
  resource_group_name = "${azurerm_resource_group.experiment.name}"
  partition_count     = "${var.eventhub_partition_count}"
  message_retention   = 1
}

# Azure Function - nodejs
resource "azurerm_storage_account" "experiment_nodejs" {
  name                     = "sanodejs${random_string.suffix.result}"
  location                 = "${azurerm_resource_group.experiment.location}"
  resource_group_name      = "${azurerm_resource_group.experiment.name}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"
  account_kind             = "StorageV2"
  tags                     = "${local.common_tags}"
}

resource "azurerm_app_service_plan" "experiment_nodejs" {
  name                = "asp-nodejs-${random_string.suffix.result}"
  location            = "${azurerm_resource_group.experiment.location}"
  resource_group_name = "${azurerm_resource_group.experiment.name}"
  kind                = "FunctionApp"
  tags                = "${local.common_tags}"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "experiment_nodejs" {
  name                      = "af-nodejs-${random_string.suffix.result}"
  location                  = "${azurerm_resource_group.experiment.location}"
  resource_group_name       = "${azurerm_resource_group.experiment.name}"
  app_service_plan_id       = "${azurerm_app_service_plan.experiment_nodejs.id}"
  storage_connection_string = "${azurerm_storage_account.experiment_nodejs.primary_connection_string}"
  version                   = "~2"
  tags                      = "${local.common_tags}"

  app_settings {
    APPINSIGHTS_INSTRUMENTATIONKEY = "${azurerm_application_insights.application_insights.instrumentation_key}"
    WEBSITE_RUN_FROM_PACKAGE       = "https://github.com/iizotov/azure-functions-scaleout/releases/download/latest/azure-function-nodejs-${var.function_app_max_batch_size}-${var.function_app_prefetch_count}-${var.function_app_batch_checkpoint_frequency}.zip"
    EVENT_HUB_CONNECTION_STRING    = "${local.nodejs_connection_string}"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    FUNCTIONS_WORKER_RUNTIME       = "node"
    AzureWebJobsDashboard          = "/"
  }

  site_config {
    use_32_bit_worker_process = false
  }
}

# Azure Function - dotnet
resource "azurerm_storage_account" "experiment_dotnet" {
  name                     = "sadotnet${random_string.suffix.result}"
  location                 = "${azurerm_resource_group.experiment.location}"
  resource_group_name      = "${azurerm_resource_group.experiment.name}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"
  account_kind             = "StorageV2"
  tags                     = "${local.common_tags}"
}

resource "azurerm_app_service_plan" "experiment_dotnet" {
  name                = "asp-dotnet-${random_string.suffix.result}"
  location            = "${azurerm_resource_group.experiment.location}"
  resource_group_name = "${azurerm_resource_group.experiment.name}"
  kind                = "FunctionApp"
  tags                = "${local.common_tags}"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "experiment_dotnet" {
  name                      = "af-dotnet-${random_string.suffix.result}"
  location                  = "${azurerm_resource_group.experiment.location}"
  resource_group_name       = "${azurerm_resource_group.experiment.name}"
  app_service_plan_id       = "${azurerm_app_service_plan.experiment_dotnet.id}"
  storage_connection_string = "${azurerm_storage_account.experiment_dotnet.primary_connection_string}"
  version                   = "~2"
  tags                      = "${local.common_tags}"

  app_settings {
    APPINSIGHTS_INSTRUMENTATIONKEY = "${azurerm_application_insights.application_insights.instrumentation_key}"

    # WEBSITE_RUN_FROM_PACKAGE       = "https://github.com/lmolotii/azure-functions-playgroud/raw/master/scenario1_hop2_node.zip"
    EVENT_HUB_CONNECTION_STRING    = "${local.dotnet_connection_string}"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    FUNCTIONS_WORKER_RUNTIME       = "dotnet"
    AzureWebJobsDashboard          = "/"
  }

  site_config {
    use_32_bit_worker_process = false
  }
}

# Azure Container Instance - workload for dotnet experiment
resource "azurerm_container_group" "aci-dotnet" {
  name                = "aci-dotnet-${random_string.suffix.result}"
  location            = "${azurerm_resource_group.experiment.location}"
  resource_group_name = "${azurerm_resource_group.experiment.name}"
  dns_name_label      = "aci-dotnet-${random_string.suffix.result}"
  os_type             = "Linux"
  restart_policy      = "Never"
  tags                = "${local.common_tags}"
  ip_address_type     = "Public"

  container {
    name   = "loadgen-dotnet"
    image  = "iizotov/azure-sb-loadgenerator-dotnetcore:latest"
    cpu    = "2"
    memory = "7"
    port   = "80"

    environment_variables {
      NUM_ITERATIONS      = "4"
      CONNECTION_STRING_1 = "${local.dotnet_connection_string}"
      CONNECTION_STRING_2 = "${local.dotnet_connection_string}"
      CONNECTION_STRING_3 = "${local.dotnet_connection_string}"
      CONNECTION_STRING_4 = "${local.dotnet_connection_string}"
      INITIAL_SLEEP       = "1m"
      TERMINATE_AFTER_1   = "60"
      TERMINATE_AFTER_2   = "3600"
      TERMINATE_AFTER_3   = "3600"
      TERMINATE_AFTER_4   = "3600"
      BATCH_1             = "1"
      BATCH_2             = "1"
      BATCH_3             = "100"
      BATCH_4             = "1000"
      THROUGHPUT_1        = "10"
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

    # commands = ["/bin/sleep", "99h"]
  }
}

resource "azurerm_container_group" "aci-nodejs" {
  name                = "aci-nodejs-${random_string.suffix.result}"
  location            = "${azurerm_resource_group.experiment.location}"
  resource_group_name = "${azurerm_resource_group.experiment.name}"
  dns_name_label      = "aci-nodejs-${random_string.suffix.result}"
  os_type             = "Linux"
  restart_policy      = "Never"
  tags                = "${local.common_tags}"
  ip_address_type     = "Public"

  container {
    name   = "loadgen-nodejs"
    image  = "iizotov/azure-sb-loadgenerator-dotnetcore:latest"
    cpu    = "2"
    memory = "7"
    port   = "80"

    environment_variables {
      NUM_ITERATIONS      = "4"
      CONNECTION_STRING_1 = "${local.nodejs_connection_string}"
      CONNECTION_STRING_2 = "${local.nodejs_connection_string}"
      CONNECTION_STRING_3 = "${local.nodejs_connection_string}"
      CONNECTION_STRING_4 = "${local.nodejs_connection_string}"
      INITIAL_SLEEP       = "1m"
      TERMINATE_AFTER_1   = "60"
      TERMINATE_AFTER_2   = "3600"
      TERMINATE_AFTER_3   = "3600"
      TERMINATE_AFTER_4   = "3600"
      BATCH_1             = "1"
      BATCH_2             = "1"
      BATCH_3             = "100"
      BATCH_4             = "1000"
      THROUGHPUT_1        = "10"
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

    # commands = ["/bin/sleep", "99h"]
  }
}
