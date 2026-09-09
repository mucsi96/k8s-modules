#!/bin/bash

set -uo pipefail

if (( EUID != 0 )); then
  echo "Error: update-server must run as root." >&2
  exit 1
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

for command in apt-get flock systemd-run; do
  command -v "$command" >/dev/null || {
    printf "Error: '%s' is required.\n" "$command" >&2
    exit 1
  }
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
  apt-get \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    -y dist-upgrade || update_status=$?
fi
if (( update_status == 0 )); then
  apt-get -y autoremove --purge || update_status=$?
fi

exit "$update_status"
