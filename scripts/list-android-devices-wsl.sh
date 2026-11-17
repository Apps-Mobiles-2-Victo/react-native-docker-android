#!/usr/bin/env bash
set -euo pipefail

ADB_HOST="${ADB_HOST:-$(ip route show default | awk 'NR == 1 { print $3 }')}"
ADB_PORT="${ADB_PORT:-5037}"

if ! command -v adb >/dev/null 2>&1; then
  echo "adb is not installed or is not on PATH in WSL." >&2
  exit 1
fi

if [[ -z "$ADB_HOST" ]]; then
  echo "Could not detect the Windows host. Set ADB_HOST and try again." >&2
  exit 1
fi

adb -H "$ADB_HOST" -P "$ADB_PORT" devices
