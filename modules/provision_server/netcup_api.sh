#!/bin/bash
set -euo pipefail

for command in curl jq; do
  command -v "$command" >/dev/null || {
    echo "$command is required by provision_server" >&2
    exit 1
  }
done

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

refresh_access_token() {
  local auth_result expires_in refresh_after
  auth_result=$(jq -cn \
    --arg refresh_token "$NETCUP_REFRESH_TOKEN" \
    --arg token_url "$NETCUP_TOKEN_URL" \
    --arg client_id "$NETCUP_CLIENT_ID" \
    '{refresh_token: $refresh_token, token_url: $token_url, client_id: $client_id}' | \
    bash "$script_directory/netcup_auth.sh")
  NETCUP_TOKEN=$(jq -er '.access_token' <<<"$auth_result")
  NETCUP_REFRESH_TOKEN=$(jq -er '.refresh_token' <<<"$auth_result")
  expires_in=$(jq -er '.expires_in | tonumber' <<<"$auth_result")
  refresh_after=$((expires_in > 60 ? expires_in - 30 : expires_in / 2))
  NETCUP_TOKEN_REFRESH_AT=$(($(date +%s) + refresh_after))
}

ensure_access_token() {
  if [[ -z "${NETCUP_TOKEN:-}" || $(date +%s) -ge ${NETCUP_TOKEN_REFRESH_AT:-0} ]]; then
    refresh_access_token
  fi
}

api_request() {
  local method=$1
  local path=$2
  local body=${3:-}
  local header_file request_succeeded response
  ensure_access_token

  header_file=$(mktemp)
  chmod 600 "$header_file"
  printf 'Authorization: Bearer %s\n' "$NETCUP_TOKEN" >"$header_file"

  local -a args=(
    --fail-with-body --silent --show-error
    --connect-timeout 10
    --max-time 30
    --request "$method"
    --header "Accept: application/json"
    --header "@$header_file"
  )
  if [[ -n "$body" ]]; then
    args+=(--header "Content-Type: application/json" --data-binary @-)
  fi

  if [[ -n "$body" ]]; then
    if response=$(printf '%s' "$body" | curl "${args[@]}" "$NETCUP_API_URL$path"); then
      request_succeeded=true
    else
      request_succeeded=false
    fi
  elif response=$(curl "${args[@]}" "$NETCUP_API_URL$path"); then
    request_succeeded=true
  else
    request_succeeded=false
  fi
  rm -f "$header_file"

  if [[ $request_succeeded != true ]]; then
    printf '%s\n' "$response" >&2
    return 1
  fi
  API_RESPONSE=$response
}

wait_for_task() {
  local uuid=$1
  local task state
  [[ -n "$uuid" ]] || return 0

  for _ in $(seq 1 180); do
    ensure_access_token
    if ! api_request GET "/api/v1/tasks/$uuid"; then
      sleep 5
      continue
    fi
    task=$API_RESPONSE
    state=$(jq -r '.state' <<<"$task")
    case "$state" in
      FINISHED) return 0 ;;
      ERROR|CANCELED)
        echo "Netcup task $uuid ended in state $state: $(jq -r '.message // .responseError.message // "no details"' <<<"$task")" >&2
        return 1
        ;;
      PENDING|RUNNING|WAITING_FOR_CANCEL|ROLLBACK) sleep 5 ;;
      *) echo "Netcup task $uuid returned unknown state: $state" >&2; return 1 ;;
    esac
  done
  echo "Timed out waiting for Netcup task $uuid" >&2
  return 1
}

ensure_access_token

case "${1:-}" in
  install)
    api_request GET "/api/v1/users/$NETCUP_USER_ID/ssh-keys"
    keys=$API_RESPONSE
    key_name=$(jq -r '.name' <<<"$SSH_KEY_BODY")
    key_value=$(jq -r '.key' <<<"$SSH_KEY_BODY")
    matches=$(jq --arg name "$key_name" '[.[] | select(.name == $name)]' <<<"$keys")
    if [[ $(jq 'length' <<<"$matches") -gt 1 ]]; then
      echo "Multiple Netcup SSH keys are named $key_name" >&2
      exit 1
    fi
    if [[ $(jq 'length' <<<"$matches") -eq 0 ]]; then
      api_request POST "/api/v1/users/$NETCUP_USER_ID/ssh-keys" "$SSH_KEY_BODY"
      key=$API_RESPONSE
    else
      key=$(jq '.[0]' <<<"$matches")
      [[ $(jq -r '.key' <<<"$key") == "$key_value" ]] || {
        echo "Netcup SSH key $key_name exists with different key material" >&2
        exit 1
      }
    fi
    key_id=$(jq -r '.id' <<<"$key")
    approval_matches=$(jq --arg name "$INSTALL_APPROVAL_NAME" '[.[] | select(.name == $name)]' <<<"$keys")
    if [[ $(jq 'length' <<<"$approval_matches") -ne 0 ]]; then
      echo "Netcup reinstall approval $INSTALL_APPROVAL_NAME was already consumed. Inspect the server and SCP task history, then use a new reinstall_generation only if another disk erase is intended." >&2
      exit 1
    fi
    api_request POST "/api/v1/users/$NETCUP_USER_ID/ssh-keys" "$INSTALL_APPROVAL_BODY"
    install_body=$(jq --argjson key_id "$key_id" '. + {sshKeyIds: [$key_id]}' <<<"$IMAGE_BODY")
    api_request POST "/api/v1/servers/$SERVER_ID/image" "$install_body"
    task=$API_RESPONSE
    wait_for_task "$(jq -r '.uuid' <<<"$task")"
    ;;

  firewall)
    api_request GET "/api/v1/users/$NETCUP_USER_ID/firewall-policies?limit=500"
    policies=$API_RESPONSE
    matches=$(jq --arg name "$FIREWALL_POLICY_NAME" '[.[] | select(.name == $name)]' <<<"$policies")
    if [[ $(jq 'length' <<<"$matches") -gt 1 ]]; then
      echo "Multiple Netcup firewall policies are named $FIREWALL_POLICY_NAME" >&2
      exit 1
    fi
    if [[ $(jq 'length' <<<"$matches") -eq 0 ]]; then
      api_request POST "/api/v1/users/$NETCUP_USER_ID/firewall-policies" "$FIREWALL_POLICY_BODY"
      policy=$API_RESPONSE
      policy_id=$(jq -r '.id' <<<"$policy")
    else
      policy_id=$(jq -r '.[0].id' <<<"$matches")
      api_request PUT "/api/v1/users/$NETCUP_USER_ID/firewall-policies/$policy_id" "$FIREWALL_POLICY_BODY"
      result=$API_RESPONSE
      wait_for_task "$(jq -r '.taskInfo.uuid // empty' <<<"$result")"
    fi
    api_request GET "/api/v1/servers/$SERVER_ID/interfaces/$INTERFACE_MAC/firewall"
    current_firewall=$API_RESPONSE
    copied_policies=$(jq '[.copiedPolicies[]? | {id}]' <<<"$current_firewall")
    assignment=$(jq -n --argjson id "$policy_id" --argjson copied "$copied_policies" \
      '{copiedPolicies: $copied, userPolicies: [{id: $id}], active: true}')
    api_request PUT "/api/v1/servers/$SERVER_ID/interfaces/$INTERFACE_MAC/firewall" "$assignment"
    task=$API_RESPONSE
    wait_for_task "$(jq -r '.uuid' <<<"$task")"
    ;;

  *)
    echo "usage: $0 install|firewall" >&2
    exit 2
    ;;
esac
