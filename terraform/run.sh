#!/bin/bash

## Adjustable Parameters
ITERATION_SLEEP=15m 				# Duration of each iteration
MAX_PARALLEL_EXPERIMENTS=12 		# How iteration to execute in parallel

LANGUAGES=( node )					# Language of Azure Function consumer
PARTITIONS=( 4 8 32 ) 				# Event Hub Partition Count
BATCH_SIZES=( 1 16 64 256 512 )		# maxBatchSize values
PREFETCH_SIZES=( 0 128 512 2048 )	# prefetchCount values
CHECKPOINT_SIZES=( 10 )				# batchCheckpointFrequency values
THROUGHPUT_UNITS=( 20 )				# Event Hub Throughput Units
# Examples
# LANGUAGES=( node dotnet )
# CHECKPOINT_SIZES=( 1 10 )
# THROUGHPUT_UNITS=( 1 10 20 )

##Main Body
TOTAL_ITERATIONS=$((${#LANGUAGES[@]}*${#PARTITIONS[@]}*${#BATCH_SIZES[@]}*${#PREFETCH_SIZES[@]}*${#CHECKPOINT_SIZES[@]}*${#THROUGHPUT_UNITS[@]}-1))
ITERATION_COUNTER=0
EXPERIMENT=0

# Functions Block
function deploy_and_sleep {
    echo "Deploying $MAX_PARALLEL_EXPERIMENTS parallel experiments"
    terraform init
    terraform apply -auto-approve -parallelism=100
	echo "Waiting 30 sec before re-deploying in case there were transient issues"
    sleep 30s
    echo "re-deploying in case there were transient failures"
    terraform apply -auto-approve -parallelism=100
    echo "Finished deploying, waiting for $ITERATION_SLEEP"
    sleep $ITERATION_SLEEP
}
# Main code

cp ./main.tf.template ./main.tf


for PARTITION in "${PARTITIONS[@]}"
do
    for BATCH_SIZE in "${BATCH_SIZES[@]}"
    do
        for PREFETCH_SIZE in "${PREFETCH_SIZES[@]}"
        do
            for THROUGHPUT in "${THROUGHPUT_UNITS[@]}"
            do
                for CHECKPOINT in "${CHECKPOINT_SIZES[@]}"
                do
                    for LANGUAGE in "${LANGUAGES[@]}"
                    do
                        echo "Iteration: $ITERATION_COUNTER / $TOTAL_ITERATIONS, Language: $LANGUAGE, Partitions: $PARTITION, Batch: $BATCH_SIZE, Prefetch: $PREFETCH_SIZE, Throughput: $THROUGHPUT, Checkpoint $CHECKPOINT"
                        
                        sed -e "s/%%EXPERIMENT%%/$EXPERIMENT/g" -e "s/%%LANGUAGE%%/$LANGUAGE/g" \
                        -e "s/%%PARTITION%%/$PARTITION/g" -e "s/%%THROUGHPUT%%/$THROUGHPUT/g" \
                        -e "s/%%BATCH_SIZE%%/$BATCH_SIZE/g" -e "s/%%PREFETCH_SIZE%%/$PREFETCH_SIZE/g" \
                        -e "s/%%CHECKPOINT%%/$CHECKPOINT/g" -e "s/%%EXPERIMENTID%%/$ITERATION_COUNTER/g" \
                        -e "s/%%ENABLED%%/1/g" ./experiment.template >> ./main.tf
                        EXPERIMENT=$((EXPERIMENT+1))
                        if [ $EXPERIMENT -eq $MAX_PARALLEL_EXPERIMENTS ]
                        then
                            deploy_and_sleep
                            cp ./main.tf.template ./main.tf
                            EXPERIMENT=0
                        fi
                        ITERATION_COUNTER=$((ITERATION_COUNTER+1))
                    done
                done
            done
        done
    done
done

if [ $EXPERIMENT -gt 0 ]
then
    echo "provisioning final batch..."
    while [ $EXPERIMENT -lt $MAX_PARALLEL_EXPERIMENTS ]; do
        echo "Iteration: $ITERATION_COUNTER / $TOTAL_ITERATIONS, Language: $LANGUAGE, Partitions: $PARTITION, Batch: $BATCH_SIZE, Prefetch: $PREFETCH_SIZE, Throughput: $THROUGHPUT, Checkpoint $CHECKPOINT"
        
        sed -e "s/%%EXPERIMENT%%/$EXPERIMENT/g" -e "s/%%LANGUAGE%%/$LANGUAGE/g" \
        -e "s/%%PARTITION%%/$PARTITION/g" -e "s/%%THROUGHPUT%%/$THROUGHPUT/g" \
        -e "s/%%BATCH_SIZE%%/$BATCH_SIZE/g" -e "s/%%PREFETCH_SIZE%%/$PREFETCH_SIZE/g" \
        -e "s/%%CHECKPOINT%%/$CHECKPOINT/g" -e "s/%%EXPERIMENTID%%/$ITERATION_COUNTER/g" \
        -e "s/%%ENABLED%%/0/g" ./experiment.template >> ./main.tf
        EXPERIMENT=$((EXPERIMENT+1))
        ITERATION_COUNTER=$((ITERATION_COUNTER+1))
    done
    deploy_and_sleep
fi

echo "cleaning up experiment resource groups, leaving the telemetry RG for analysis..."

for GROUP in `az group list --query '[?tags.experiment_id].name' --output tsv`
do
    echo "deleting resource group $GROUP"
    # can run az without az login 'safely' here since terraform would've used az already (local-exec is used in a couple of places)
    az group delete --yes --no-wait --name "$GROUP"
done

rm -rf ./main.tf
rm -rf ./*.zip
rm -rf ./*.tfstate
rm -rf ./*.tfstate.backup

echo "Done!"
