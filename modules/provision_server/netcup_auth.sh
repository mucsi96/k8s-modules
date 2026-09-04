#!/bin/bash
set -euo pipefail

for command in curl jq; do
  command -v "$command" >/dev/null || {
    echo "$command is required by provision_server" >&2
    exit 1
  }
done

query=$(jq -e 'select(type == "object")' < /dev/stdin)
refresh_token=$(jq -er '.refresh_token | select(type == "string" and length > 0)' <<<"$query")
token_url=$(jq -er '.token_url | select(type == "string" and length > 0)' <<<"$query")
client_id=$(jq -er '.client_id | select(type == "string" and length > 0)' <<<"$query")

response=$(curl --fail-with-body --silent --show-error \
  --request POST "$token_url" \
  --data-urlencode 'grant_type=refresh_token' \
  --data-urlencode "client_id=$client_id" \
  --data-urlencode "refresh_token=$refresh_token")

access_token=$(jq -er '.access_token | select(type == "string" and length > 0)' <<<"$response")
expires_in=$(jq -er '.expires_in | numbers | floor | tostring' <<<"$response")
rotated_refresh_token=$(jq -r '
  if .refresh_token == null then ""
  elif (.refresh_token | type) == "string" then .refresh_token
  else error("refresh_token must be a string")
  end
' <<<"$response")
if [[ -n "$rotated_refresh_token" ]]; then
  refresh_token=$rotated_refresh_token
fi

refresh_after=$((expires_in > 60 ? expires_in - 30 : expires_in / 2))
refresh_at=$(($(date +%s) + refresh_after))

jq -n \
  --arg access_token "$access_token" \
  --arg expires_in "$expires_in" \
  --arg refresh_at "$refresh_at" \
  --arg refresh_token "$refresh_token" \
  '{access_token: $access_token, expires_in: $expires_in, refresh_at: $refresh_at, refresh_token: $refresh_token}'
