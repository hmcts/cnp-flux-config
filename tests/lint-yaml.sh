#!/usr/bin/env bash
set -ex

sudo apt-get install yamllint

yamllint . -c .yamllint.yaml