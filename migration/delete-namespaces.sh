#!/usr/bin/env bash
set -e

 for file in  $(find k8s/namespaces/ -name namespace.yaml); do
 rm $file
done