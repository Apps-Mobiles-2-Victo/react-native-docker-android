#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
APP_ROOT="${APP_ROOT:-$REPO_ROOT/examples/android-hello-world}"

echo "Building Release APK..."

docker run --rm --ulimit nofile=10240 \
  -v gradle-home-cache:/opt/gradle-home \
  -v "$APP_ROOT:/workspace" \
  -w /workspace \
  react-native-android \
  sh -c 'yarn install && cd android && ./gradlew --no-daemon --configuration-cache assembleRelease'