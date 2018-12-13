# Secrets
variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}

provider "azurerm" {
  version         = ">=1.19.0"
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}

module "telemetry" {
  source = "./module-telemetry"
  region = "Southeast Asia"
}

## GENERATE BELOW
module "experiment_32_20_128_256_10" {
  source                                  = "./module-experiment"
  language                                = "node"
  log_analytics_workspace_id              = "${module.telemetry.log_analytics_workspace_id}"
  appinsights_instrumentationkey          = "${module.telemetry.appinsights_instrumentationkey}"
  region                                  = "Southeast Asia"
  client_secret                           = "${var.client_secret}"
  eventhub_partition_count                = 32
  eventhub_namespace_capacity             = 20
  function_app_max_batch_size             = 128
  function_app_prefetch_count             = 256
  function_app_batch_checkpoint_frequency = 10
}

module "experiment_4_20_128_256_10" {
  source                                  = "./module-experiment"
  language                                = "node"
  log_analytics_workspace_id              = "${module.telemetry.log_analytics_workspace_id}"
  appinsights_instrumentationkey          = "${module.telemetry.appinsights_instrumentationkey}"
  region                                  = "Southeast Asia"
  client_secret                           = "${var.client_secret}"
  eventhub_partition_count                = 4
  eventhub_namespace_capacity             = 20
  function_app_max_batch_size             = 128
  function_app_prefetch_count             = 256
  function_app_batch_checkpoint_frequency = 10
}

# TODO:
#bash script, logic: generate experiment, apply, taint, wait, update config
#insert wait in event hub loadgen

