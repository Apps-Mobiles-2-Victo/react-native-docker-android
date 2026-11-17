#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/interne/wsl-adb-host.sh"

ADB_HOST="${ADB_HOST:-$(get_default_adb_host)}"
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
