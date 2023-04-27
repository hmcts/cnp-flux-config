#!/usr/bin/env bash

# Script to check if apiVersion is present in all yaml files in apps/

for FILE in $(find apps/* -type f -name "*.yaml"); do
    
    API_VERSION_CHECK=$(yq eval -N '.apiVersion' $FILE -N)
    
    if [ "$API_VERSION_CHECK" == "null" ]
    then
        echo "apiVersion: missing in $FILE" && exit 1
    fi

done
