#!/usr/bin/env bash
#
# test.sh
# -------------------
# Proof-of-concept for DTSPO-33474: unit testing Prometheus alerts that are
# deployed as PrometheusRule CRDs via Flux.
#
# promtool's `test rules` command only understands NATIVE Prometheus rule files
# (a top-level `groups:` document). Our alerts live inside PrometheusRule CRDs
# (apiVersion: monitoring.coreos.com/v1) where the rules are nested under
# `.spec.groups`. This script bridges the two:
#
#   1. Read rule/test pairs from tests.yaml.
#   2. Extract each PrometheusRule `.spec` into .generated/ using yq.
#   3. Run `promtool test rules` for each extracted-rule + test-file pair.
#
# Everything runs offline - promtool builds a simulated TSDB from the
# `input_series` in each test, so NO cluster, VPN or Key Vault access is needed.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/tests.yaml"
GEN_DIR="${SCRIPT_DIR}/.generated"
PROMTOOL_IMAGE="${PROMTOOL_IMAGE:-prom/prometheus:latest}"

command -v yq >/dev/null       || { echo "ERROR: yq not found on PATH" >&2; exit 1; }

[[ -f "${CONFIG_FILE}" ]] || { echo "ERROR: config not found: ${CONFIG_FILE}" >&2; exit 1; }

mkdir -p "${GEN_DIR}"

PROMTOOL_MODE=""
if command -v promtool >/dev/null 2>&1; then
  PROMTOOL_MODE="local"
elif command -v docker >/dev/null 2>&1; then
  PROMTOOL_MODE="docker"
  docker info >/dev/null 2>&1 || {
    echo "ERROR: docker found but daemon not running. Start Docker Desktop and retry." >&2
    exit 1
  }
  docker image inspect "${PROMTOOL_IMAGE}" >/dev/null 2>&1 || docker pull "${PROMTOOL_IMAGE}" >/dev/null
else
  echo "ERROR: promtool not found and docker not found. Install promtool or docker." >&2
  exit 1
fi

run_promtool() {
  if [[ "${PROMTOOL_MODE}" == "local" ]]; then
    promtool "$@"
  else
    docker run --rm -v "${GEN_DIR}:/work" -w /work --entrypoint promtool "${PROMTOOL_IMAGE}" "$@"
  fi
}

promtool_file_arg() {
  local file_path="$1"
  if [[ "${PROMTOOL_MODE}" == "local" ]]; then
    printf '%s\n' "${file_path}"
  else
    printf '%s\n' "$(basename "${file_path}")"
  fi
}

resolve_path() {
  local path="$1"
  if [[ "${path}" = /* ]]; then
    printf '%s\n' "${path}"
  else
    printf '%s\n' "${SCRIPT_DIR}/${path}"
  fi
}

pairs_count="$(yq eval '."prometheus-rules" | length' "${CONFIG_FILE}")"
if [[ "${pairs_count}" == "0" || "${pairs_count}" == "null" ]]; then
  echo "ERROR: no rule/test pairs found in ${CONFIG_FILE}" >&2
  exit 1
fi

echo "==> Processing ${pairs_count} rule/test pair(s) from ${CONFIG_FILE}"
echo "==> promtool mode: ${PROMTOOL_MODE}"
for ((i=0; i<pairs_count; i++)); do
  rules_file_rel="$(yq eval ".\"prometheus-rules\"[${i}].rules_file" "${CONFIG_FILE}")"
  tests_file_rel="$(yq eval ".\"prometheus-rules\"[${i}].tests_file" "${CONFIG_FILE}")"

  if [[ "${rules_file_rel}" == "null" || -z "${rules_file_rel}" ]]; then
    echo "ERROR: missing rules_file at index ${i} in ${CONFIG_FILE}" >&2
    exit 1
  fi
  if [[ "${tests_file_rel}" == "null" || -z "${tests_file_rel}" ]]; then
    echo "ERROR: missing tests_file at index ${i} in ${CONFIG_FILE}" >&2
    exit 1
  fi

  rules_file="$(resolve_path "${rules_file_rel}")"
  tests_file="$(resolve_path "${tests_file_rel}")"

  [[ -f "${rules_file}" ]] || { echo "ERROR: rules file not found: ${rules_file}" >&2; exit 1; }
  [[ -f "${tests_file}" ]] || { echo "ERROR: test file not found: ${tests_file}" >&2; exit 1; }

  base="$(basename "${rules_file}")"
  base="${base%.yaml}"
  out="${GEN_DIR}/${base}.rules.yaml"

  echo "==> [${i}] Extracting ${rules_file}"
  kind="$(yq eval '.kind' "${rules_file}")"
  if [[ "${kind}" != "PrometheusRule" ]]; then
    echo "ERROR: ${rules_file} kind=${kind}; expected PrometheusRule" >&2
    exit 1
  fi

  yq eval '.spec' "${rules_file}" > "${out}"
  run_promtool check rules "$(promtool_file_arg "${out}")"

  tmp_test="$(mktemp "${GEN_DIR}/tmp-test.${i}.XXXXXX")"
  RULE_FILE_PATH="$(basename "${out}")" yq eval '.rule_files = [strenv(RULE_FILE_PATH)]' "${tests_file}" > "${tmp_test}"
  chmod 644 "${tmp_test}"

  echo "==> [${i}] Running promtool tests from ${tests_file}"
  run_promtool test rules "$(promtool_file_arg "${tmp_test}")"
  rm -f "${tmp_test}"
done

echo "==> All rule/test pairs passed"
