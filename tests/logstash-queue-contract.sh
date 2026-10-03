#!/usr/bin/env bash
set -euo pipefail

files=()
while IFS= read -r file; do
  files+=("$file")
done < <(find apps/ccd -type f \( -name '*.yaml' -o -name '*.yml' \) -exec grep -l 'case_data_logstash_queue' {} +)
[[ ${#files[@]} -gt 0 ]] || { echo 'No Logstash queue pipeline was found.' >&2; exit 1; }
expected_returning='q.id AS version, cd.id, created_date, last_modified, jurisdiction, case_type_id, state, last_state_modified_date, data::TEXT as json_data, data_classification::TEXT as json_data_classification, reference, security_classification, supplementary_data::TEXT as json_supplementary_data'

normalise_whitespace() {
  printf '%s' "$1" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//'
}

for file in "${files[@]}"; do
  statement="$(grep 'statement => .*case_data_logstash_queue' "$file")"
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
  returning="${statement#*RETURNING }"
  returning="${returning%%\"*}"
  [[ "$(normalise_whitespace "$returning")" == "$expected_returning" ]] || {
    echo "$file has an unexpected queue poll RETURNING projection." >&2; exit 1;
  }
done

for file in apps/ccd/ccd-logstash/ccd-logstash.yaml \
    apps/ccd/ccd-logstash-intdemo/ccd-logstash-intdemo.yaml; do
  rename='rename => { "version" => "[@metadata][queue_version]" }'
  filter="$(sed -n '/02_filter.conf: |/,/03_output.conf: |/p' "$file")"
  [[ "$filter" == *"$rename"* ]] || {
    echo "$file must move the queue version into metadata." >&2; exit 1;
  }
  [[ "$(printf '%s' "$filter" | sed '/clone {/,$d')" == *"$rename"* ]] || {
    echo "$file must move the queue version before cloning." >&2; exit 1;
  }
  output="$(grep -F -A 8 'document_id => "%{id}"' "$file")"
  for required in 'document_id => "%{id}"' 'version => "%{[@metadata][queue_version]}"' 'version_type => "external"'; do
    [[ "$output" == *"$required"* ]] || {
      echo "$file is missing Elasticsearch external-version output: $required" >&2; exit 1;
    }
  done
done

# Bulk indexers must override the shared queue-version output.
for file in apps/ccd/ccd-logstash-indexer*/ccd-logstash-indexer*.yaml; do
  output="$(sed -n '/03_output.conf: |/,$p' "$file")"
  [[ "$output" == *'document_id => "%{id}"'* ]] || {
    echo "$file must provide its own bulk indexing output." >&2; exit 1;
  }
  if [[ "$output" == *'version =>'* || "$output" == *'version_type =>'* ]]; then
    echo "$file must not require queue versions absent from its bulk query." >&2; exit 1;
  fi
done
