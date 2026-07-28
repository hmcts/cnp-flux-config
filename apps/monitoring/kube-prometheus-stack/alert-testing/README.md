# Prometheus alert unit tests

## Purpose

These tests prove alert behavior before deploy, not only YAML syntax.

Why this matters:

- Prevent false positives and false negatives from rule edits.
- Verify thresholds, `for` windows, labels, and annotations.
- Catch regressions in CI before Flux applies changes to clusters.

## Setup

### Option 1: local tools

Install both tools on your PATH:

- `yq`
- `promtool`

### Option 2: mixed mode (recommended on macOS)

- Install `yq` locally.
- Use Docker for `promtool` (script auto-falls back when local `promtool` is missing).

Helper script:

```bash
./setup-tools-macos.sh
```

## File usage

- `tests.yaml`
  - Source of truth for rule/test pairs.
  - Each item under `prometheus-rules` maps one `rules_file` to one `tests_file`.

- `npd-alerts-rules.yaml`
  - PrometheusRule CRD under test.
  - Script extracts `.spec` into native Prometheus rules format.

- `npd-rule-tests.yaml`
  - promtool unit test definitions.
  - Contains synthetic series, evaluation times, and expected alerts.

- `test.sh`
  - Test runner.
  - Reads `tests.yaml`, extracts each CRD, runs `promtool check rules`, then `promtool test rules` per pair.
  - Uses local `promtool` if present, else Docker image `prom/prometheus:latest`.

- `.generated/`
  - Temporary extracted native rules and generated test files.
  - Safe to delete; recreated on each run.
  - .gitignored

## Run

From this directory:

```bash
./test.sh
```

Expected success:

```text
==> Processing <n> rule/test pair(s) from .../tests.yaml
==> promtool mode: local|docker
==> [0] Extracting ...
Checking ...rules.yaml
  SUCCESS: <m> rules found
==> [0] Running promtool tests from ...
  SUCCESS
==> All rule/test pairs passed
```
