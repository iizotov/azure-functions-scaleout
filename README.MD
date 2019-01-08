# Experiment. Azure Functions and Event Hubs: optimising for throughput
[![Build Status](https://dev.azure.com/igizotov/azure-functions-scaleout/_apis/build/status/Prepare%20Azure%20Function%20Packages?branchName=master)](https://dev.azure.com/igizotov/azure-functions-scaleout/_build/latest?definitionId=10?branchName=master)

> Note: Best consumed ~~chilled~~ with my [blog](https://aka.ms/AA3qsxf) discusssing this experiment in detail

## Summary
A Terraform-automated series of independent experiments empirically measuring throughput and latency of an Event Hub-triggered Azure Function on a Consumption Plan for different combinations of:
- number of Partitions in the Event Hub
- `maxBatchSize` setting in `host.json`
- `prefetchCount` setting in `host.json`

## Prerequisites
1. Owner access to an Azure [subscription](https://azure.microsoft.com/en-us/free/)
2. Linux box with [Terraform](https://learn.hashicorp.com/terraform/getting-started/install.html) and [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) in $PATH

## Running
1. `git clone https://github.com/iizotov/azure-functions-scaleout && cd azure-functions-scaleout`
1. Create a Service Principal for Terraform by following these [instructions](https://www.terraform.io/docs/providers/azurerm/auth/service_principal_client_secret.html#creating-a-service-principal)
  - (Option A) create `./terraform/credentials.auto.tfvars` with the SP credentials as below:
	```bash
	cat << 'EOF' > ./terraform/credentials.auto.tfvars
	"subscription_id" = "<REPLACE_ME>"
	"client_id" = "<REPLACE_ME>"
	"client_secret" = "<REPLACE_ME>"
	"tenant_id" = "<REPLACE_ME>"
	"region" = "West US 2"
	EOF
	```
  - (Option B) create environmental variables with the SP credentials:
    ```bash
	export TF_VAR_subscription_id="<REPLACE_ME>"
	export TF_VAR_client_id="<REPLACE_ME>"
	export TF_VAR_client_secret="<REPLACE_ME>"
	export TF_VAR_tenant_id="<REPLACE_ME>"
	export TF_VAR_region="West US 2"
	```
	> Note 1: Terraform will be calling `az` from time to time, hence Azure credentials can not be passed via a [more familiar](https://www.terraform.io/docs/providers/azurerm/auth/service_principal_client_certificate.html#configuring-the-service-principal-in-terraform) `ARM_*` env variables method 
	
	> Note 2: by default, all Azure service will be provisioned in West US 2, to choose a different region, modify the `region` or `TF_VAR_region` setting accordingly, **ensuring the chosen region can run both Application Insights and Log Analytics**. At the time of writing, `West US 2` and `Southeast Asia` were the two good candidates

2. Edit `./terraform/run.sh` to adjust the settings below. By default, 60 iterations will be performed covering every combination of array values (60=1x3x5x4x1x1), executed in parallel in batches of 12, 15 minutes per batch.
    ```bash
	## Adjustable Parameters
	ITERATION_SLEEP=15m 			# Duration for each iteration
	MAX_PARALLEL_EXPERIMENTS=12 		# Parallel iterations to run

	LANGUAGES=( node )			# Azure Function consumer lang
	PARTITIONS=( 4 8 32 )			# Event Hub Partition Count
	BATCH_SIZES=( 1 16 64 256 512 )		# maxBatchSize values
	PREFETCH_SIZES=( 0 128 512 2048 )	# prefetchCount values
	CHECKPOINT_SIZES=( 10 )			# batchCheckpointFrequency values
	THROUGHPUT_UNITS=( 20 )			# Event Hub Throughput Units
	```
3. Run `nohup /bin/bash ./terraform/run.sh > output.out 2>&1 &`

## Experiment Detail
The experiment will iterate through every possible combination of the following arrays' values as defined in `run.sh`:
- `$LANGUAGES`
- `$PARTITIONS`
- `$BATCH_SIZES`
- `$PREFETCH_SIZES`
- `$CHECKPOINT_SIZES`
- `$THROUGHPUT_UNITS`

### Preparation Phase

A new resource group `rg-telemetry-<suffix>` is created with these services and will be shared by all iterations:
  - Azure Application Insights for Azure Functions metrics
  - Log Analytics Workspace for Event Hub metrics
  - Consumption Plan Azure Function: deployment helper with the following application settings:
	```
	WEBSITE_RUN_FROM_PACKAGE = "https://github.com/iizotov/azure-functions-scaleout/releases/download/latest/deploymenthelper.zip"
    NODEJS_TEMPLATE_URL      = "https://github.com/iizotov/azure-functions-scaleout/releases/download/latest/nodejs-template.zip"
    DOTNET_TEMPLATE_URL      = "https://github.com/iizotov/azure-functions-scaleout/releases/download/latest/dotnet-template.zip"
	```
    > The purpose of this helper is to be able dynamically generate a zipdeploy file with the correct `host.json` settings for every iteration of the experiment

### Iteration Phase

Iterations are deployed in parallel, in batches of `$MAX_PARALLEL_EXPERIMENTS`. Each iteration:
   1. ...creates a new resource group `exp-<experiment_id>-<language>-<partition_count>-<TUs>-<batch_size>-<prefetch_count>-<checkpoint_freq>-<suffix>`
   2. ...provisions a Standard Event Hub Namespace with `$THROUGHPUT_UNITS` TUs with a single Event Hub with `$PARTITIONS` partitions, enables monitoring via the provisioned Log Analytics Workspace
   3. ...provisions a Consumption plan Azure Function v2 consumer bound to that event hub with `host.json` configured acccordingly. The function consumes messages from the event hub and stores latency as a custom metric in the provisioned Application Insights instance
      1. nodejs consumer [template](https://github.com/iizotov/azure-functions-scaleout/releases/download/latest/nodejs-template.zip)
      2. dotnet core consumer [template](https://github.com/iizotov/azure-functions-scaleout/releases/download/latest/dotnet-template.zip)
   4. ...provisions a load generator as an [Azure Container Instance] (https://azure.microsoft.com/en-us/services/container-instances/) instance running 5 container images of `iizotov/azure-sb-loadgenerator-dotnetcore:latest` flooding the Event Hub with messages saturating the ingress
   5. ...sleeps for `$ITERATION_SLEEP` and tears down the `exp-...` resource group

The process is repeated until there are no more iterations left.

### Analysis Time!

To join the collected Event Hub metrics in the Log Analytics Workspace to the Azure Function custom metrics in Appplication Insights, the following [Kusto](https://docs.microsoft.com/en-us/azure/azure-monitor/log-query/log-query-overview) query can be used:
```csharp
// Application Insights instance, grab all custom metrics
let ai_raw_metrics = app("ai-33rl7yxp").customMetrics;

// derive instance counts from "cloud_RoleInstance" metric in AI, summarize by iteration and P1M
let ai_P1M_instance_count=ai_raw_metrics
| where name in ("batchSize")
| summarize 
        Value=round(dcount(cloud_RoleInstance))
        by TimeStamp=bin(timestamp, 1m), Experiment=tolower(tostring(customDimensions.experiment)), MetricName="InstanceCount";

// summarize batchSize and batchAverageLatency custom metrics in AI by iteration and P1M
let ai_P1M_metrics = ai_raw_metrics
| where name in ("batchSize", "batchAverageLatency")
| project MetricName=name, TimeStamp=timestamp, Value=value, Experiment=tolower(tostring(customDimensions.experiment))
| summarize 
        Value=avg(Value) 
        by bin(TimeStamp, 1m), Experiment, MetricName;

// extract OutgoingMessages and IncomingMessages EH metrics, summarize by iteration and P1M
let eh_P1M_metrics = AzureMetrics
| where ResourceProvider == "MICROSOFT.EVENTHUB"
| where TimeGrain == "PT1M" 
| where MetricName in ("OutgoingMessages", "IncomingMessages")
| project Value=Total, Count, Maximum, Minimum, TimeStamp=TimeGenerated, MetricName, Experiment=tolower(Resource)
| summarize 
        Value=avg(Value) 
        by bin(TimeStamp, 1m), Experiment, MetricName;

// now that every metric is a P1M metric, union them all  
ai_P1M_metrics 
| union eh_P1M_metrics
| union ai_P1M_instance_count
```
This can be analysed directly or [exported to Power BI](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/powerbi) for a more interactive slicing and dicing experiment 

## Disclaimers
The code included in this sample is not intended to be a set of best practices on how to build scalable enterprise grade applications. This is beyond the scope of this educational experiment.

## Related Links
- My blog interpreting the results [here](https://aka.ms/AA3qsxf) 
- [Results](https://aka.ms/AA3qwza) published to in Power BI
- Documentation on `host.json` [parameters](https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-event-hubs#trigger---hostjson-properties)
- [Jeff Hollan's blog on Azure Functions](https://medium.com/@jeffhollan)