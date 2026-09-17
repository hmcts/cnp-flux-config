#!/usr/bin/env bash
set -euo pipefail

files=()
while IFS= read -r file; do
  files+=("$file")
done < <(rg -l 'case_data_logstash_queue' apps/ccd -g '*.yaml' -g '*.yml')
[[ ${#files[@]} -gt 0 ]] || { echo 'No Logstash queue pipeline was found.' >&2; exit 1; }

for file in "${files[@]}"; do
  statement="$(rg 'statement => .*case_data_logstash_queue' "$file")"
  for required in 'WITH candidates AS' 'ORDER BY q.id' 'LIMIT 1000' \
      'DELETE FROM case_data_logstash_queue q' 'RETURNING q.id AS version' \
      'q.case_data_id = cd.id'; do
    [[ "$statement" == *"$required"* ]] || {
      echo "$file is missing: $required" >&2; exit 1;
    }
  done
  if [[ "$statement" == *'JOIN case_data'* ]]; then
    [[ "$statement" == *'FOR UPDATE OF q SKIP LOCKED'* ]] || {
      echo "$file must lock only queue rows." >&2; exit 1;
    }
  else
    [[ "$statement" == *'FOR UPDATE SKIP LOCKED'* ]] || {
      echo "$file is missing SKIP LOCKED." >&2; exit 1;
    }
  fi
  [[ "$statement" != *'marked_by_logstash'* ]] || {
    echo "$file still uses marked_by_logstash." >&2; exit 1;
  }
done
