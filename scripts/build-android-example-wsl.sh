#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
EXAMPLE_DIR="$REPO_ROOT/examples/android-hello-world"

docker run --rm --ulimit nofile=10240 \
  -v "$EXAMPLE_DIR:/workspace" \
  -w /workspace react-native-android \
  sh -c 'yarn install && cd android && ./gradlew --no-daemon assembleRelease'
