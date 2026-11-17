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
  if ! read -r -p "Nom du projet React Native à construire : " PROJECT_NAME; then
    echo "Could not read the project name." >&2
    exit 1
  fi
fi

if [[ -z "$PROJECT_NAME" || "$PROJECT_NAME" == "." || "$PROJECT_NAME" == ".." || "$PROJECT_NAME" == */* ]]; then
  echo "The project name must be a non-empty name without path separators." >&2
  exit 1
fi

APP_ROOT="${APP_ROOT:-$REPO_ROOT/examples/$PROJECT_NAME}"
if [[ ! -d "$APP_ROOT" ]]; then
  echo "Project directory not found: $APP_ROOT" >&2
  exit 1
fi

echo "Building Release APK for $PROJECT_NAME..."

docker run --rm --ulimit nofile=10240 \
  -v gradle-home-cache:/opt/gradle-home \
  -v android-sdk-cache:/opt/android \
  -v "$APP_ROOT:/workspace" \
  -w /workspace \
  react-native-android \
  sh -c 'yarn install && cd android && ./gradlew --no-daemon --configuration-cache assembleRelease'