#!/bin/bash

INTERATION_SLEEP=5h
# LANGUAGES=( node dotnet )
LANGUAGES=( node )
PARTITIONS=( 4 8 16 32 )
BATCH_SIZES=( 16 32 64 128 256 512 )
PREFETCH_SIZES=( 0 16 32 64 128 256 512 1024 )
CHECKPOINT_SIZES=( 10 )
THROUGHPUTS=( 20 )

TOTAL_ITERATIONS=$((${#LANGUAGES[@]}*${#PARTITIONS[@]}*${#BATCH_SIZES[@]}*${#PREFETCH_SIZES[@]}*${#CHECKPOINT_SIZES[@]}*${#THROUGHPUTS[@]}-1))
ITERATION_COUNTER=0
EXPERIMENT=0
MAX_PARALLEL_EXPERIMENTS=10

cp ./main.tf.template ./main.tf

for LANGUAGE in "${LANGUAGES[@]}"
do
    for PARTITION in "${PARTITIONS[@]}"
    do
        for BATCH_SIZE in "${BATCH_SIZES[@]}"
        do
            for PREFETCH_SIZE in "${PREFETCH_SIZES[@]}"
            do
                for THROUGHPUT in "${THROUGHPUTS[@]}"
                do
                    for CHECKPOINT in "${CHECKPOINT_SIZES[@]}"
                    do
                        echo "Iteration: $ITERATION_COUNTER / $TOTAL_ITERATIONS, Language: $LANGUAGE, Partitions: $PARTITION, Batch: $BATCH_SIZE, Prefetch: $PREFETCH_SIZE, Throughput: $THROUGHPUT, Checkpoint $CHECKPOINT"
                        
                        if [ $EXPERIMENT -le $((MAX_PARALLEL_EXPERIMENTS-1)) ]
                        then
                            sed -e "s/%%EXPERIMENT%%/$EXPERIMENT/g" -e "s/%%LANGUAGE%%/$LANGUAGE/g" \
                            -e "s/%%PARTITION%%/$PARTITION/g" -e "s/%%THROUGHPUT%%/$THROUGHPUT/g" \
                            -e "s/%%BATCH_SIZE%%/$BATCH_SIZE/g" -e "s/%%PREFETCH_SIZE%%/$PREFETCH_SIZE/g" \
                            -e "s/%%CHECKPOINT%%/$CHECKPOINT/g" ./experiment.template >> ./main.tf
                            EXPERIMENT=$((EXPERIMENT+1))
                        else
                            echo "Deploying $MAX_PARALLEL_EXPERIMENTS parallel experiments"
                            terraform init
                            terraform apply -auto-approve -parallelism=100
                            echo "Finished deploying, waiting for $INTERATION_SLEEP"
                            sleep $INTERATION_SLEEP
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
    terraform init
    terraform apply -auto-approve -parallelism=100
    
fi

rm -rf ./main.tf
rm -rf ./*.zip