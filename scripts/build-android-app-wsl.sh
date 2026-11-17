#!/usr/bin/env bash
set -euo pipefail

GREEN=""
GREEN_RESET=""
RED=""
if [[ -t 1 ]]; then
  GREEN=$'\033[0;32m'
  GREEN_RESET=$'\033[0m'
fi
if [[ -t 2 ]]; then
  RED=$'\033[0;31m'
  RED_RESET=$'\033[0m'
fi

print_filesystem_message() {
  local color="$1"
  local reset="$2"
  local message="$3"
  printf '%s----------------------------------------%s\n' "$color" "$reset"
  printf '%s%s%s\n' "$color" "$message" "$reset"
  printf '%s----------------------------------------%s\n' "$color" "$reset"
}

if ! command -v findmnt >/dev/null 2>&1; then
  print_filesystem_message "$RED" "$RED_RESET" "Impossible de vérifier le système de fichiers du répertoire courant (findmnt est requis)." >&2
  exit 1
fi

CURRENT_FS="$(findmnt -n -o FSTYPE --target "$PWD")"
if [[ "$CURRENT_FS" != "ext4" ]]; then
  print_filesystem_message "$RED" "$RED_RESET" "Le répertoire courant doit être sur ext4 (système détecté : ${CURRENT_FS:-inconnu})." >&2
  exit 1
fi

print_filesystem_message "$GREEN" "$GREEN_RESET" "Système de fichiers OK : ext4."

show_wsl_memory() {
  echo "Mémoire WSL - $1"
  free -h
}

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

show_wsl_memory "avant la compilation"

if docker run --rm --ulimit nofile=10240 \
  -v gradle-home-cache:/opt/gradle-home \
  -v android-sdk-cache:/opt/android \
  -v npm-cache:/npm-cache \
  -v yarn-cache:/yarn-cache \
  --env npm_config_cache=/npm-cache \
  --env YARN_CACHE_FOLDER=/yarn-cache \
  --env CMAKE_BUILD_PARALLEL_LEVEL=1 \
  -v "$APP_ROOT:/workspace" \
  -w /workspace \
  react-native-android \
  sh -c 'if [ -f package-lock.json ]; then npm ci; elif [ -f yarn.lock ]; then yarn install --frozen-lockfile; else yarn install; fi && cd android && ./gradlew --no-daemon --configuration-cache --max-workers=1 --no-parallel -Dorg.gradle.jvmargs="-Xmx1024m -XX:MaxMetaspaceSize=384m" assembleRelease'; then
  DOCKER_STATUS=0
else
  DOCKER_STATUS=$?
fi

show_wsl_memory "après la compilation"
exit "$DOCKER_STATUS"