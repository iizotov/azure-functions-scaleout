# Secrets
variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}



module "experiment_one" {
  source = "./module-experiment"

  region                                  = "Southeast Asia"
  subscription_id                         = "${var.subscription_id}"
  client_id                               = "${var.client_id}"
  client_secret                           = "${var.client_secret}"
  tenant_id                               = "${var.tenant_id}"
  eventhub_partition_count                = 32
  eventhub_namespace_capacity             = 20
  function_app_prefetch_count             = 64
  function_app_max_batch_size             = 128
  function_app_batch_checkpoint_frequency = 10
}

module "experiment_two" {
  source = "./module-experiment"

  region                                  = "Southeast Asia"
  subscription_id                         = "${var.subscription_id}"
  client_id                               = "${var.client_id}"
  client_secret                           = "${var.client_secret}"
  tenant_id                               = "${var.tenant_id}"
  eventhub_partition_count                = 32
  eventhub_namespace_capacity             = 20
  function_app_prefetch_count             = 256
  function_app_max_batch_size             = 128
  function_app_batch_checkpoint_frequency = 10
}

