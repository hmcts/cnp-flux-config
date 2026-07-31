#!/usr/bin/env bash

set -eu

dir=$(dirname ${0})
filepath=${1}
filename=$(basename ${filepath})
uploadFilename="$(date +"%Y%m%d-%H%M%S")-${filename}"
echo filepath =$filepath

if [ -z "${USER_TOKEN:-}" ]; then
  echo Get User token
  userToken=$(${dir}/idam-lease-user-token.sh ${CCD_CONFIGURER_IMPORTER_USERNAME} ${CCD_CONFIGURER_IMPORTER_PASSWORD})
else
  echo Use cache User token
  userToken=${USER_TOKEN}
fi

if [ -z "${SERVICE_TOKEN:-}" ]; then
  echo Get Service token
  serviceToken=$(${dir}/idam-lease-service-token.sh ccd_gw $(docker run --rm hmctsprod.azurecr.io/imported/toolbelt/oathtool --totp -b ${API_GATEWAY_S2S_KEY:-AAAAAAAAAAAAAAAA}))
else
  echo Use cache Service token
  serviceToken=${SERVICE_TOKEN}
fi

echo CCD_DEFINITION_STORE_API_BASE_URL = $CCD_DEFINITION_STORE_API_BASE_URL

max_upload_attempts=3
upload_retry_delay=5
attempt=1

while true; do
  echo "Uploading ${filename} (${uploadFilename}) - attempt ${attempt}/${max_upload_attempts}"

  uploadResponse=$(curl --insecure --silent -w "\n%{http_code}" --show-error -X POST \
    ${CCD_DEFINITION_STORE_API_BASE_URL:-http://localhost:4451}/import \
    -H "Authorization: Bearer ${userToken}" \
    -H "ServiceAuthorization: Bearer ${serviceToken}" \
    -F "file=@${filepath};filename=${uploadFilename}")

  upload_http_code=$(echo "${uploadResponse}" | tail -n1)
  upload_response_content=$(echo "${uploadResponse}" | sed '$d')
  # Only retry if the HTTP code is 409 (Conflict). For other codes, break the loop and handle accordingly
  if [[ "${upload_http_code}" != "409" ]]; then
    break
  fi

  if [[ "${attempt}" -ge "${max_upload_attempts}" ]]; then
    break
  fi

  echo "Upload returned HTTP 409. Retrying in ${upload_retry_delay} seconds..."
  sleep "${upload_retry_delay}"
  attempt=$((attempt + 1))
done

if [[ "${upload_http_code}" == '504' || "${upload_http_code}" == '502' ]]; then
  for try in {1..20}
  do
    sleep 5
    echo "Checking status of ${filename} (${uploadFilename}) upload (Try ${try})"
    audit_response=$(curl --insecure --silent --show-error -X GET \
      ${CCD_DEFINITION_STORE_API_BASE_URL:-http://localhost:4451}/api/import-audits \
      -H "Authorization: Bearer ${userToken}" \
      -H "ServiceAuthorization: Bearer ${serviceToken}")

    if [[ ${audit_response} == *"${uploadFilename}"* ]]; then
      echo "${filename} (${uploadFilename}) uploaded"
      exit 0
    fi
  done
elif [[ "${upload_response_content}" == 'Case Definition data successfully imported' ]]; then
  echo "${filename} (${uploadFilename}) uploaded"
  exit 0
fi

echo "${filename} (${uploadFilename}) upload failed after ${attempt} attempt(s): HTTP ${upload_http_code} (${upload_response_content})"
exit 1;