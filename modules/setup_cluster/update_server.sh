#!/bin/bash

set -uo pipefail

if (( EUID != 0 )); then
  echo "Error: update-server must run as root." >&2
  exit 1
fi

if [[ "${UPDATE_SERVER_BACKGROUND:-}" != 1 ]]; then
  exec systemd-run \
    --unit=update-server \
    --collect \
    --no-block \
    --setenv=UPDATE_SERVER_BACKGROUND=1 \
    /usr/local/sbin/update-server
fi

if [[ ! -r /etc/os-release ]]; then
  echo "Error: unable to identify the operating system." >&2
  exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release
if [[ "$ID" != debian || "$VERSION_ID" != 13 ]]; then
  printf 'Error: expected Debian 13, found %s.\n' "${PRETTY_NAME:-unknown}" >&2
  exit 1
fi

for command in apt-get curl dpkg flock systemd-run; do
  command -v "$command" >/dev/null || {
    printf "Error: '%s' is required.\n" "$command" >&2
    exit 1
  }
done

for executable in /usr/local/bin/k3s /usr/local/libexec/install-k3s.sh; do
  if [[ ! -x "$executable" ]]; then
    printf "Error: '%s' is not executable.\n" "$executable" >&2
    exit 1
  fi
done

exec 9>/run/lock/update-server.lock
if ! flock --wait 900 9; then
  echo "Error: another server update is still running." >&2
  exit 1
fi

# Invoked by the EXIT trap after every update attempt.
# shellcheck disable=SC2329
schedule_reboot() {
  local status=$?
  local reboot_unit

  trap - EXIT
  reboot_unit="update-server-reboot-$(date +%s)"
  if systemd-run \
    --unit="$reboot_unit" \
    --on-active=10s \
    --collect \
    /usr/bin/systemctl reboot; then
    echo "Server reboot scheduled in 10 seconds."
  else
    echo "Error: unable to schedule the server reboot." >&2
    status=1
  fi
  exit "$status"
}
trap schedule_reboot EXIT

export APT_LISTCHANGES_FRONTEND=none
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

update_status=0
apt-get update || update_status=$?
if (( update_status == 0 )); then
  apt-get -y --only-upgrade install twingate-connector || update_status=$?
fi
if (( update_status == 0 )); then
  apt-get \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    -y dist-upgrade || update_status=$?
fi
if (( update_status == 0 )); then
  apt-get -y autoremove --purge || update_status=$?
fi

installed_k3s=$(/usr/local/bin/k3s --version | awk 'NR == 1 { print $3 }') || {
  status=$?
  (( update_status != 0 )) || update_status=$status
  installed_k3s=
}
stable_k3s_url=$(curl \
  --fail \
  --silent \
  --show-error \
  --location \
  --output /dev/null \
  --write-out '%{url_effective}' \
  https://update.k3s.io/v1-release/channels/stable) || {
  status=$?
  (( update_status != 0 )) || update_status=$status
  stable_k3s_url=
}
stable_k3s=${stable_k3s_url##*/}

if [[ -z "$stable_k3s" || -z "$installed_k3s" ]]; then
  echo "Unable to compare the installed and stable k3s releases." >&2
elif dpkg --compare-versions \
  "${installed_k3s#v}" lt "${stable_k3s#v}"; then
  printf 'Upgrading k3s from %s to %s...\n' "$installed_k3s" "$stable_k3s"
  INSTALL_K3S_CHANNEL=stable /usr/local/libexec/install-k3s.sh || {
    status=$?
    (( update_status != 0 )) || update_status=$status
  }
else
  printf 'k3s %s is current.\n' "$installed_k3s"
fi

echo "Pruning unused k3s container images..."
/usr/local/bin/k3s crictl rmi --prune || {
  status=$?
  (( update_status != 0 )) || update_status=$status
}

exit "$update_status"
