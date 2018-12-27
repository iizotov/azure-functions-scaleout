# Secrets
variable "client_secret" {}

data "azurerm_client_config" "current" {}

# Variables
variable "log_analytics_workspace_id" {}

variable "experiment_id" {}

variable "appinsights_instrumentationkey" {}

variable "sa_telemetry_account_id" {}

variable "deployment_helper_hostname" {}

variable "eventhub_partition_count" {
  default = 32
}

variable "enabled" {
  default = 1
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
    experiment_id                           = "${var.experiment_id}"
  }
  full_name         = "exp-${var.experiment_id}-${var.language}-${var.eventhub_partition_count}-${var.eventhub_namespace_capacity}-${var.function_app_max_batch_size}-${var.function_app_prefetch_count}-${var.function_app_batch_checkpoint_frequency}-${random_string.suffix.result}"
}

# Resource Group
resource "azurerm_resource_group" "experiment" {
  name     = "${local.full_name}"
  location = "${var.region}"
  tags     = "${local.common_tags}"
  count    = "${var.enabled == 1 ? 1 : 0}"
}

# Event Hub
resource "azurerm_eventhub_namespace" "experiment" {
  name                = "${local.full_name}"
  location            = "${azurerm_resource_group.experiment.location}"
  resource_group_name = "${azurerm_resource_group.experiment.name}"
  sku                 = "Standard"
  capacity            = "${var.eventhub_namespace_capacity}"
  tags                = "${local.common_tags}"
  count               = "${var.enabled == 1 ? 1 : 0}"
}

resource "azurerm_eventhub" "experiment" {
  name                = "eh"
  namespace_name      = "${azurerm_eventhub_namespace.experiment.name}"
  resource_group_name = "${azurerm_resource_group.experiment.name}"
  partition_count     = "${var.eventhub_partition_count}"
  message_retention   = 1
  count               = "${var.enabled == 1 ? 1 : 0}"
}

# Diagnostic Setting for Event Hub 
resource "azurerm_monitor_diagnostic_setting" "diagnostics_eh" {
  name                       = "diag_eh_${local.full_name}"
  target_resource_id         = "${azurerm_eventhub_namespace.experiment.id}"
  log_analytics_workspace_id = "${var.log_analytics_workspace_id}"
  storage_account_id         = "${var.sa_telemetry_account_id}"
  count                      = "${var.enabled == 1 ? 1 : 0}"

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
    }
  }

  provisioner "local-exec" {
    command = "az login --service-principal -u ${data.azurerm_client_config.current.client_id} -p ${var.client_secret} --tenant ${data.azurerm_client_config.current.tenant_id}"
  }

  # Feels like a bug but only after the metrics have been requested at least once they begin to flow into Log Analytics...
  provisioner "local-exec" {
    command = " az monitor metrics list --resource ${azurerm_eventhub_namespace.experiment.id}"
  }
}

# Azure Function
resource "azurerm_storage_account" "experiment" {
  name                     = "sa${var.experiment_id}${var.language}${random_string.suffix.result}"
  location                 = "${azurerm_resource_group.experiment.location}"
  resource_group_name      = "${azurerm_resource_group.experiment.name}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"
  account_kind             = "StorageV2"
  tags                     = "${local.common_tags}"
  count                    = "${var.enabled == 1 ? 1 : 0}"
}

resource "azurerm_app_service_plan" "experiment" {
  name                = "${local.full_name}"
  location            = "${azurerm_resource_group.experiment.location}"
  resource_group_name = "${azurerm_resource_group.experiment.name}"
  kind                = "FunctionApp"
  tags                = "${local.common_tags}"
  count               = "${var.enabled == 1 ? 1 : 0}"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "experiment" {
  name                      = "${local.full_name}"
  location                  = "${azurerm_resource_group.experiment.location}"
  resource_group_name       = "${azurerm_resource_group.experiment.name}"
  app_service_plan_id       = "${azurerm_app_service_plan.experiment.id}"
  storage_connection_string = "${azurerm_storage_account.experiment.primary_connection_string}"
  version                   = "~2"
  tags                      = "${local.common_tags}"
  enable_builtin_logging    = false
  count                     = "${var.enabled == 1 ? 1 : 0}"

  app_settings {
    APPINSIGHTS_INSTRUMENTATIONKEY = "${var.appinsights_instrumentationkey}"
    EVENT_HUB_CONNECTION_STRING    = "${azurerm_eventhub_namespace.experiment.default_primary_connection_string}"
    FUNCTIONS_WORKER_RUNTIME       = "${var.language}"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    WEBSITE_NODE_DEFAULT_VERSION   = "10.6.0"
    EXPERIMENT                     = "${local.full_name}"
    WEBSITE_RUN_FROM_PACKAGE       = "${var.deployment_helper_hostname}/deploy?language=${var.language}&batch=${var.function_app_max_batch_size}&prefetch=${var.function_app_prefetch_count}&checkpoint=${var.function_app_batch_checkpoint_frequency}"
  }

  site_config {
    use_32_bit_worker_process = false
  }

  # provisioner "local-exec" {
  #   command = "az login --service-principal -u ${data.azurerm_client_config.current.client_id} -p ${var.client_secret} --tenant ${data.azurerm_client_config.current.tenant_id}"
  # }

  # provisioner "local-exec" {
  #   command = "az account set --subscription ${data.azurerm_client_config.current.subscription_id}"
  # }

  # provisioner "local-exec" {
  #   command = "curl -o ./${random_string.suffix.result}.zip -G ${var.deployment_helper_hostname}/deploy -d language=${var.language} -d batch=${var.function_app_max_batch_size} -d prefetch=${var.function_app_prefetch_count} -d checkpoint=${var.function_app_batch_checkpoint_frequency}"
  # }

  # provisioner "local-exec" {
  #   command = "az functionapp deployment source config-zip --ids ${azurerm_function_app.experiment.id} --src ./${random_string.suffix.result}.zip"
  # }
}

# Azure Container Instance - workload generator
resource "azurerm_container_group" "aci" {
  name                = "${local.full_name}-${count.index}"
  location            = "${azurerm_resource_group.experiment.location}"
  resource_group_name = "${azurerm_resource_group.experiment.name}"
  dns_name_label      = "${local.full_name}-${count.index}"
  os_type             = "Linux"
  restart_policy      = "Never"
  tags                = "${local.common_tags}"
  ip_address_type     = "Public"
  count               = "${var.enabled == 1 ? 5 : 0}"

  container {
    name   = "${local.full_name}"
    image  = "iizotov/azure-sb-loadgenerator-dotnetcore:latest"
    cpu    = "2"
    memory = "7"
    port   = "80"

    environment_variables {
      NUM_ITERATIONS      = "4"
      CONNECTION_STRING_1 = "${azurerm_eventhub_namespace.experiment.default_primary_connection_string};TransportType=Amqp;EntityPath=${azurerm_eventhub.experiment.name}"
      CONNECTION_STRING_2 = "${azurerm_eventhub_namespace.experiment.default_primary_connection_string};TransportType=Amqp;EntityPath=${azurerm_eventhub.experiment.name}"
      CONNECTION_STRING_3 = "${azurerm_eventhub_namespace.experiment.default_primary_connection_string};TransportType=Amqp;EntityPath=${azurerm_eventhub.experiment.name}"
      CONNECTION_STRING_4 = "${azurerm_eventhub_namespace.experiment.default_primary_connection_string};TransportType=Amqp;EntityPath=${azurerm_eventhub.experiment.name}"
      INITIAL_SLEEP       = "5m"
      SLEEP_1             = "0m"
      SLEEP_2             = "0m"
      SLEEP_3             = "0m"
      SLEEP_4             = "5m"
      TERMINATE_AFTER_1   = "1200"
      TERMINATE_AFTER_2   = "1200"
      TERMINATE_AFTER_3   = "1200"
      TERMINATE_AFTER_4   = "1200"
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
