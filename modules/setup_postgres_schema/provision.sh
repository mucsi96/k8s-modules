#!/usr/bin/env bash
set -euo pipefail
set +x

: "${SSH_HOST:?}" "${SSH_PORT:?}" "${SSH_USERNAME:?}" "${SSH_AUTH_SOCK:?}"
: "${DB_NAMESPACE:?}" "${DB_DEPLOYMENT:?}" "${APP_SCHEMA:?}" "${APP_PASSWORD:?}"

if [[ "$APP_PASSWORD" == *$'\n'* ]]; then
  printf 'The generated database password must be a single line.\n' >&2
  exit 1
fi

ssh=(ssh -T -o BatchMode=yes -o ConnectTimeout=5
  -o ServerAliveInterval=15 -o ServerAliveCountMax=3
  -o StrictHostKeyChecking=accept-new -o ForwardAgent=no
  -p "$SSH_PORT" "$SSH_USERNAME@$SSH_HOST")

# Only non-secret arguments enter the remote command. Admin credentials stay
# inside PostgreSQL's container; the application password travels over stdin.
printf -v kubectl 'sudo -n /usr/local/bin/k3s kubectl --request-timeout=30s -n %q' "$DB_NAMESPACE"
ready='export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -X -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "SELECT 1"'
printf -v ready_command '%s exec deployment/%q -c %q -- sh -ceu %q' \
  "$kubectl" "$DB_DEPLOYMENT" "$DB_DEPLOYMENT" "$ready"

for attempt in {1..60}; do
  if "${ssh[@]}" "$ready_command" </dev/null >/dev/null 2>&1; then
    break
  fi
  if (( attempt == 60 )); then
    printf 'PostgreSQL did not become reachable over SSH. Check host trust, agent, sudo, and database readiness.\n' >&2
    exit 1
  fi
  sleep 2
done

provision='APP_SCHEMA=$1; export APP_SCHEMA; IFS= read -r APP_PASSWORD; export APP_PASSWORD; export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -X --single-transaction -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f -'
printf -v provision_command '%s exec -i deployment/%q -c %q -- sh -ceu %q -- %q' \
  "$kubectl" "$DB_DEPLOYMENT" "$DB_DEPLOYMENT" "$provision" "$APP_SCHEMA"

{
  printf '%s\n' "$APP_PASSWORD"
  cat "$(dirname "$0")/init.sql"
} | "${ssh[@]}" "$provision_command"
