#!/usr/bin/env bash
set -ex

sudo apt-get install yamllint

yamllint k8s -c tests/.yamllint.yaml