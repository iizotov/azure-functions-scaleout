#!/bin/bash

echo script name: $0
echo arguments: $# 

if [ $# -ne 1 ]; 
    then echo "usage: $0 <folder_name>"
    exit 1
fi

if [ ! -d "$1" ]; then
    echo "directory $1 does not exist"
    exit 1
fi


declare -a PREFETCH_ARRAY=(0 32 64 128 256 512 1024)
declare -a BATCH_ARRAY=(1 4 16 32 64 128 256 512 1024 2048)
declare -a CHECKPOINT_ARRAY=(1 10 100)

mkdir -p output/

for PREFETCH in "${PREFETCH_ARRAY[@]}"
do
    for BATCH in "${BATCH_ARRAY[@]}"
    do
        for CHECKPOINT in "${CHECKPOINT_ARRAY[@]}"
        do
            echo "$PREFETCH $BATCH $CHECKPOINT"
            sed -e "s/\${PREFETCH}/$PREFETCH/" -e "s/\${BATCH}/$BATCH/" -e "s/\${CHECKPOINT}/$CHECKPOINT/" $1/host.template.json > $1/host.json
            ZIP_FILENAME="../output/$1-$BATCH-$PREFETCH-$CHECKPOINT.zip"
            cd $1; zip -r $ZIP_FILENAME .; cd ..
        done
    done
done

exit 0