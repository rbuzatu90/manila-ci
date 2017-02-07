#!/bin/bash

source /home/ubuntu/keystonerc

MAX_RETRIES=${1:-60}
RETRY_INTERVAL=${2:-20}
TIMEOUT=$((MAX_RETRIES * RETRY_INTERVAL))

TRIES=0
MANILA_SV_COUNT=0

echo "Ensuring there are manila-share backends available."

while [ $TRIES -lt $MAX_RETRIES -a $MANILA_SV_COUNT -lt 1 ]; do
    MANILA_SV_COUNT=$(manila service-list | grep manila-share | grep -c -w up)
    let TRIES=TRIES+1

    if [ "$MANILA_SV_COUNT" -lt 1  ]
    then
        echo "Could not find any available m-shr service."
        if [ $TRIES -eq $MAX_RETRIES ]
        then
            echo "Reached the $TIMEOUT seconds timeout."
            exit 1
        else
            echo "Retrying in $RETRY_INTERVAL seconds."
            echo "Manila services:"
            manila service-list
            sleep $RETRY_INTERVAL
        fi
    fi
done
