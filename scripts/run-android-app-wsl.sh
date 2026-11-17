#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

if [[ "$#" -gt 1 ]]; then
  echo "Usage: $0 [ProjectName]" >&2
  exit 1
fi

if [[ "$#" -eq 1 ]]; then
  PROJECT_NAME="$1"
else
  if [[ ! -t 0 ]]; then
    echo "Provide a project name as an argument when running non-interactively." >&2
    exit 1
  fi
  if ! read -r -p "Nom du projet React Native à exécuter : " PROJECT_NAME; then
    echo "Could not read the project name." >&2
    exit 1
  fi
fi

if [[ -z "$PROJECT_NAME" || "$PROJECT_NAME" == "." || "$PROJECT_NAME" == ".." || "$PROJECT_NAME" == */* ]]; then
  echo "The project name must be a non-empty name without path separators." >&2
  exit 1
fi

APP_ROOT="${APP_ROOT:-$REPO_ROOT/examples/$PROJECT_NAME}"
APK="$APP_ROOT/android/app/build/outputs/apk/release/app-release.apk"
ADB_HOST="${ADB_HOST:-$(ip route show default | awk 'NR == 1 { print $3 }')}"
ADB_PORT="${ADB_PORT:-5037}"

if ! command -v adb >/dev/null 2>&1; then
  echo "adb is not installed or is not on PATH in WSL." >&2
  exit 1
fi

if [[ ! -d "$APP_ROOT" ]]; then
  echo "Project directory not found: $APP_ROOT" >&2
  exit 1
fi

if [[ ! -f "$APK" ]]; then
  echo "APK not found. Build it first with ./scripts/build-android-app-wsl.sh $PROJECT_NAME" >&2
  exit 1
fi

if [[ -z "${APP_PACKAGE:-}" ]]; then
  GRADLE_FILE="$APP_ROOT/android/app/build.gradle"
  if [[ ! -f "$GRADLE_FILE" ]]; then
    echo "Could not find $GRADLE_FILE to determine the Android application ID." >&2
    exit 1
  fi
  APP_PACKAGE="$(awk '
    /^[[:space:]]*applicationId[[:space:]]+/ {
      value = $2
      gsub(/["\047]/, "", value)
      print value
      exit
    }' "$GRADLE_FILE")"
  if [[ -z "$APP_PACKAGE" ]]; then
    echo "Could not determine the Android application ID. Set APP_PACKAGE and try again." >&2
    exit 1
  fi
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
"${ADB[@]}" -s "$DEVICE" shell am start -n "$APP_PACKAGE/.MainActivity"
