#!/bin/bash
set -euo pipefail

for command in curl jq; do
  command -v "$command" >/dev/null || {
    echo "$command is required by provision_server" >&2
    exit 1
  }
done

api_request() {
  local method=$1
  local path=$2
  local body=${3:-}
  local -a args=(
    --fail-with-body --silent --show-error
    --request "$method"
    --header "Accept: application/json"
    --header "Authorization: Bearer $NETCUP_TOKEN"
  )
  if [[ -n "$body" ]]; then
    args+=(--header "Content-Type: application/json" --data "$body")
  fi
  curl "${args[@]}" "$NETCUP_API_URL$path"
}

wait_for_task() {
  local uuid=$1
  local task state
  [[ -n "$uuid" ]] || return 0

  for _ in $(seq 1 180); do
    task=$(api_request GET "/api/v1/tasks/$uuid")
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

case "${1:-}" in
  install)
    keys=$(api_request GET "/api/v1/users/$NETCUP_USER_ID/ssh-keys")
    key_name=$(jq -r '.name' <<<"$SSH_KEY_BODY")
    key_value=$(jq -r '.key' <<<"$SSH_KEY_BODY")
    matches=$(jq --arg name "$key_name" '[.[] | select(.name == $name)]' <<<"$keys")
    if [[ $(jq 'length' <<<"$matches") -gt 1 ]]; then
      echo "Multiple Netcup SSH keys are named $key_name" >&2
      exit 1
    fi
    if [[ $(jq 'length' <<<"$matches") -eq 0 ]]; then
      key=$(api_request POST "/api/v1/users/$NETCUP_USER_ID/ssh-keys" "$SSH_KEY_BODY")
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
    api_request POST "/api/v1/users/$NETCUP_USER_ID/ssh-keys" "$INSTALL_APPROVAL_BODY" >/dev/null
    install_body=$(jq --argjson key_id "$key_id" '. + {sshKeyIds: [$key_id]}' <<<"$IMAGE_BODY")
    task=$(api_request POST "/api/v1/servers/$SERVER_ID/image" "$install_body")
    wait_for_task "$(jq -r '.uuid' <<<"$task")"
    ;;

  firewall)
    policies=$(api_request GET "/api/v1/users/$NETCUP_USER_ID/firewall-policies?limit=500")
    matches=$(jq --arg name "$FIREWALL_POLICY_NAME" '[.[] | select(.name == $name)]' <<<"$policies")
    if [[ $(jq 'length' <<<"$matches") -gt 1 ]]; then
      echo "Multiple Netcup firewall policies are named $FIREWALL_POLICY_NAME" >&2
      exit 1
    fi
    if [[ $(jq 'length' <<<"$matches") -eq 0 ]]; then
      policy=$(api_request POST "/api/v1/users/$NETCUP_USER_ID/firewall-policies" "$FIREWALL_POLICY_BODY")
      policy_id=$(jq -r '.id' <<<"$policy")
    else
      policy_id=$(jq -r '.[0].id' <<<"$matches")
      result=$(api_request PUT "/api/v1/users/$NETCUP_USER_ID/firewall-policies/$policy_id" "$FIREWALL_POLICY_BODY")
      wait_for_task "$(jq -r '.taskInfo.uuid // empty' <<<"$result")"
    fi
    current_firewall=$(api_request GET "/api/v1/servers/$SERVER_ID/interfaces/$INTERFACE_MAC/firewall")
    copied_policies=$(jq '[.copiedPolicies[]? | {id}]' <<<"$current_firewall")
    assignment=$(jq -n --argjson id "$policy_id" --argjson copied "$copied_policies" \
      '{copiedPolicies: $copied, userPolicies: [{id: $id}], active: true}')
    task=$(api_request PUT "/api/v1/servers/$SERVER_ID/interfaces/$INTERFACE_MAC/firewall" "$assignment")
    wait_for_task "$(jq -r '.uuid' <<<"$task")"
    ;;

  *)
    echo "usage: $0 install|firewall" >&2
    exit 2
    ;;
esac
