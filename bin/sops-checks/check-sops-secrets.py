#!/usr/bin/env python3
"""Fail if any Kubernetes Secret has data/stringData values that are not SOPS encrypted."""
import os
import re
import sys

import yaml

SOPS_VALUE = re.compile(r"^ENC\[AES256_GCM,data:.*,iv:.*,tag:.*,type:\w+\]$")
DATA_KEYS = ("data", "stringData")
# Loaded from alongside the script so CI uses master's copy, not the PR's.
EXCLUSIONS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "check-sops-secrets-exclusions.yaml")


def load_excluded_paths():
    with open(EXCLUSIONS_FILE, encoding="utf-8") as f:
        paths = (yaml.safe_load(f) or {}).get("excluded_paths") or []
    if not isinstance(paths, list) or not all(isinstance(p, str) and p for p in paths):
        sys.exit(f"ERROR: 'excluded_paths' in {EXCLUSIONS_FILE} must be a list of non-empty strings")
    return tuple(paths)


EXCLUDED_PATHS = load_excluded_paths()


class Loader(yaml.SafeLoader):
    pass


# Treat a bare "=" value (e.g. NeuVector criteria ops) as a plain string.
Loader.add_constructor("tag:yaml.org,2002:value", Loader.construct_scalar)


def check_file(path):
    errors = []
    # Paths are resolved relative to the working directory, which must be the repo root.
    if os.path.relpath(path).replace(os.sep, "/").startswith(EXCLUDED_PATHS):
        return errors
    try:
        with open(path, encoding="utf-8") as f:
            docs = list(yaml.load_all(f, Loader=Loader))
    except (yaml.YAMLError, UnicodeDecodeError) as e:
        print(f"WARNING: skipping {path}, could not parse YAML: {e}", file=sys.stderr)
        return errors

    for doc in docs:
        if not isinstance(doc, dict) or doc.get("kind") != "Secret":
            continue
        metadata = doc.get("metadata") or {}
        name = metadata.get("name", "<unnamed>")
        for key in DATA_KEYS:
            values = doc.get(key) or {}
            if not isinstance(values, dict):
                errors.append(f"{path}: Secret '{name}' has non-mapping '{key}'")
                continue
            for item, value in values.items():
                if not isinstance(value, str) or not SOPS_VALUE.match(value):
                    errors.append(f"{path}: Secret '{name}' {key}.{item} is not SOPS encrypted")
        if any(doc.get(k) for k in DATA_KEYS) and "sops" not in doc:
            errors.append(f"{path}: Secret '{name}' is missing SOPS metadata")
    return errors


def main(paths):
    errors = [e for p in paths for e in check_file(p)]
    for e in errors:
        print(e, file=sys.stderr)
    if errors:
        print("\nEncrypt with: sops --encrypt --in-place <file>", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
