# Secrets
variable "subscription_id" {}

variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}

variable "region" {
  default = "East US"
}

provider "azurerm" {
  version         = ">=1.19.0"
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}

module "telemetry" {
  source = "module-telemetry"
  region = "${var.region}"
}

## GENERATE BELOW
module "experiment_0" {
  source                                  = "module-experiment"
  language                                = "node"
  log_analytics_workspace_id              = "${module.telemetry.log_analytics_workspace_id}"
  appinsights_instrumentationkey          = "${module.telemetry.appinsights_instrumentationkey}"
  sa_telemetry_account_id                 = "${module.telemetry.sa_telemetry_account_id}"
  deployment_helper_hostname              = "${module.telemetry.deployment_helper_hostname}"
  region                                  = "${var.region}"
  client_secret                           = "${var.client_secret}"
  eventhub_partition_count                = 4
  eventhub_namespace_capacity             = 20
  function_app_max_batch_size             = 16
  function_app_prefetch_count             = 0
  function_app_batch_checkpoint_frequency = 10
}

module "experiment_1" {
  source                                  = "module-experiment"
  language                                = "node"
  log_analytics_workspace_id              = "${module.telemetry.log_analytics_workspace_id}"
  appinsights_instrumentationkey          = "${module.telemetry.appinsights_instrumentationkey}"
  sa_telemetry_account_id                 = "${module.telemetry.sa_telemetry_account_id}"
  deployment_helper_hostname              = "${module.telemetry.deployment_helper_hostname}"
  region                                  = "${var.region}"
  client_secret                           = "${var.client_secret}"
  eventhub_partition_count                = 4
  eventhub_namespace_capacity             = 20
  function_app_max_batch_size             = 16
  function_app_prefetch_count             = 16
  function_app_batch_checkpoint_frequency = 10
}

module "experiment_2" {
  source                                  = "module-experiment"
  language                                = "node"
  log_analytics_workspace_id              = "${module.telemetry.log_analytics_workspace_id}"
  appinsights_instrumentationkey          = "${module.telemetry.appinsights_instrumentationkey}"
  sa_telemetry_account_id                 = "${module.telemetry.sa_telemetry_account_id}"
  deployment_helper_hostname              = "${module.telemetry.deployment_helper_hostname}"
  region                                  = "${var.region}"
  client_secret                           = "${var.client_secret}"
  eventhub_partition_count                = 4
  eventhub_namespace_capacity             = 20
  function_app_max_batch_size             = 16
  function_app_prefetch_count             = 32
  function_app_batch_checkpoint_frequency = 10
}

module "experiment_3" {
  source                                  = "module-experiment"
  language                                = "node"
  log_analytics_workspace_id              = "${module.telemetry.log_analytics_workspace_id}"
  appinsights_instrumentationkey          = "${module.telemetry.appinsights_instrumentationkey}"
  sa_telemetry_account_id                 = "${module.telemetry.sa_telemetry_account_id}"
  deployment_helper_hostname              = "${module.telemetry.deployment_helper_hostname}"
  region                                  = "${var.region}"
  client_secret                           = "${var.client_secret}"
  eventhub_partition_count                = 4
  eventhub_namespace_capacity             = 20
  function_app_max_batch_size             = 16
  function_app_prefetch_count             = 64
  function_app_batch_checkpoint_frequency = 10
}

module "experiment_4" {
  source                                  = "module-experiment"
  language                                = "node"
  log_analytics_workspace_id              = "${module.telemetry.log_analytics_workspace_id}"
  appinsights_instrumentationkey          = "${module.telemetry.appinsights_instrumentationkey}"
  sa_telemetry_account_id                 = "${module.telemetry.sa_telemetry_account_id}"
  deployment_helper_hostname              = "${module.telemetry.deployment_helper_hostname}"
  region                                  = "${var.region}"
  client_secret                           = "${var.client_secret}"
  eventhub_partition_count                = 4
  eventhub_namespace_capacity             = 20
  function_app_max_batch_size             = 16
  function_app_prefetch_count             = 128
  function_app_batch_checkpoint_frequency = 10
}

