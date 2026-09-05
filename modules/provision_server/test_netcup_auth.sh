#!/bin/bash
set -euo pipefail

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf -- "$temporary_directory"' EXIT
mkdir "$temporary_directory/bin"

cat >"$temporary_directory/bin/curl" <<'EOF'
#!/bin/bash
set -euo pipefail

refresh_token=
while (($#)); do
  if [[ $1 == --data-urlencode ]]; then
    shift
    if [[ $1 == refresh_token@- ]]; then
      refresh_token=$(</dev/stdin)
    fi
  fi
  shift
done

case "$refresh_token" in
  initial-refresh-token)
    printf '%s\n' '{"access_token":"first-access-token","expires_in":300,"refresh_token":"rotated-refresh-token"}'
    ;;
  rotated-refresh-token)
    printf '%s\n' '{"access_token":"second-access-token","expires_in":300}'
    ;;
  *)
    echo "unexpected refresh token: $refresh_token" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$temporary_directory/bin/curl"

query=$(jq -cn \
  --arg refresh_token 'initial-refresh-token' \
  '{refresh_token: $refresh_token, token_url: "https://example.test/token", client_id: "scp"}')

result=$(PATH="$temporary_directory/bin:$PATH" bash "$script_directory/netcup_auth.sh" <<<"$query")
[[ $(jq -r .access_token <<<"$result") == first-access-token ]]
[[ $(jq -r .refresh_token <<<"$result") == rotated-refresh-token ]]

query=$(jq -cn \
  --arg refresh_token "$(jq -r .refresh_token <<<"$result")" \
  '{refresh_token: $refresh_token, token_url: "https://example.test/token", client_id: "scp"}')
result=$(PATH="$temporary_directory/bin:$PATH" bash "$script_directory/netcup_auth.sh" <<<"$query")
[[ $(jq -r .access_token <<<"$result") == second-access-token ]]
[[ $(jq -r .refresh_token <<<"$result") == rotated-refresh-token ]]
