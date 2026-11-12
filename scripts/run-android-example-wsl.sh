#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
APK="$REPO_ROOT/examples/android-hello-world/android/app/build/outputs/apk/release/app-release.apk"
ADB_HOST="${ADB_HOST:-$(ip route show default | awk 'NR == 1 { print $3 }')}"
ADB_PORT="${ADB_PORT:-5037}"

if ! command -v adb >/dev/null 2>&1; then
  echo "adb is not installed or is not on PATH in WSL." >&2
  exit 1
fi

if [[ ! -f "$APK" ]]; then
  echo "APK not found. Build it first with ./scripts/build-android-example-wsl.sh" >&2
  exit 1
fi

if [[ -z "$ADB_HOST" ]]; then
  echo "Could not detect the Windows host. Set ADB_HOST and try again." >&2
  exit 1
fi

ADB=(adb -H "$ADB_HOST" -P "$ADB_PORT")
DEVICES="$("${ADB[@]}" devices)" || {
  echo "Could not connect to the Windows ADB server at $ADB_HOST:$ADB_PORT." >&2
  exit 1
}
mapfile -t EMULATORS < <(printf '%s\n' "$DEVICES" | awk 'NR > 1 && $2 == "device" && $1 ~ /^emulator-/ { print $1 }')

if [[ -n "${ANDROID_SERIAL:-}" ]]; then
  DEVICE="$ANDROID_SERIAL"
  DEVICE_FOUND=false
  for EMULATOR in "${EMULATORS[@]}"; do
    if [[ "$EMULATOR" == "$DEVICE" ]]; then
      DEVICE_FOUND=true
      break
    fi
  done
  if [[ "$DEVICE_FOUND" != true ]]; then
    echo "AVD '$DEVICE' is not connected to the Windows ADB server." >&2
    exit 1
  fi
elif [[ "${#EMULATORS[@]}" -eq 1 ]]; then
  DEVICE="${EMULATORS[0]}"
elif [[ "${#EMULATORS[@]}" -eq 0 ]]; then
  echo "No online AVD found. Start an AVD and check the Windows ADB server." >&2
  exit 1
else
  echo "Multiple AVDs found: ${EMULATORS[*]}. Set ANDROID_SERIAL to choose one." >&2
  exit 1
fi

"${ADB[@]}" -s "$DEVICE" install -r "$APK"
"${ADB[@]}" -s "$DEVICE" shell am start -n com.androidphonedemo/.MainActivity
