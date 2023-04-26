#!/usr/bin/env bash

# Script to check if apiVersion is present in all yaml files in apps/

for FILE in $(find apps/* -type f -name "*.yaml"); do

    if [ $(yq eval '.apiVersion' $FILE -N) == "test" ]
    then
        echo "apiVersion: missing in $FILE" && exit 1
    fi

done
