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

PARALLEL_BUILD=1
PARALLEL_OPTION=""
BUILD_VARIANT="Release"
PROJECT_NAME=""
for arg in "$@"; do
  case "$arg" in
    --debug)
      BUILD_VARIANT="Debug"
      ;;
    --parallel|--no-parallel)
      if [[ -n "$PARALLEL_OPTION" && "$PARALLEL_OPTION" != "$arg" ]]; then
        echo "Usage: $0 [--debug] [--parallel|--no-parallel] [ProjectName]" >&2
        exit 1
      fi
      PARALLEL_OPTION="$arg"
      if [[ "$arg" == "--no-parallel" ]]; then
        PARALLEL_BUILD=0
      fi
      ;;
    -*)
      echo "Usage: $0 [--debug] [--parallel|--no-parallel] [ProjectName]" >&2
      exit 1
      ;;
    *)
      if [[ -n "$PROJECT_NAME" ]]; then
        echo "Usage: $0 [--debug] [--parallel|--no-parallel] [ProjectName]" >&2
        exit 1
      fi
      PROJECT_NAME="$arg"
      ;;
  esac
done

if [[ -z "$PROJECT_NAME" ]]; then
  if [[ ! -t 0 ]]; then
    echo "Provide a project name as an argument when running non-interactively." >&2
    exit 1
  fi
  if ! read -r -p "Nom du projet React Native à construire : " PROJECT_NAME; then
    echo "Could not read the project name." >&2
    exit 1
  fi
fi

if [[ "$PARALLEL_BUILD" -eq 1 ]]; then
  GRADLE_PARALLEL_ARGS=(--parallel --max-workers=2)
  CMAKE_BUILD_PARALLEL_LEVEL=2
else
  GRADLE_PARALLEL_ARGS=(--max-workers=1 --no-parallel)
  CMAKE_BUILD_PARALLEL_LEVEL=1
fi

GRADLE_BUILD_ARGS=("${GRADLE_PARALLEL_ARGS[@]}")
if [[ "$BUILD_VARIANT" == "Debug" ]]; then
  GRADLE_BUILD_ARGS+=(-PbundleDebugJs=true)
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

CMAKE_BUILD_TASK=":app:buildCMakeRelWithDebInfo[x86_64]"
if [[ "$BUILD_VARIANT" == "Debug" ]]; then
  CMAKE_BUILD_TASK=":app:buildCMakeDebug[x86_64]"
fi

echo "Building $BUILD_VARIANT APK for $PROJECT_NAME..."

show_wsl_memory "avant la compilation"

if docker run --rm --ulimit nofile=10240 \
  -v gradle-home-cache:/opt/gradle-home \
  -v android-sdk-cache:/opt/android \
  -v npm-cache:/npm-cache \
  -v yarn-cache:/yarn-cache \
  --env npm_config_cache=/npm-cache \
  --env YARN_CACHE_FOLDER=/yarn-cache \
  --env CMAKE_BUILD_PARALLEL_LEVEL="$CMAKE_BUILD_PARALLEL_LEVEL" \
  --env BUILD_VARIANT="$BUILD_VARIANT" \
  --env CMAKE_BUILD_TASK="$CMAKE_BUILD_TASK" \
  -v "$APP_ROOT:/workspace" \
  -w /workspace \
  react-native-android \
  sh -c 'if [ -f package-lock.json ]; then npm ci; elif [ -f yarn.lock ]; then yarn install --frozen-lockfile; else yarn install; fi && cd android && ./gradlew --no-daemon --configuration-cache "$@" -Dorg.gradle.jvmargs="-Xmx1024m -XX:MaxMetaspaceSize=384m" "$CMAKE_BUILD_TASK" && ./gradlew --no-daemon --configuration-cache "$@" -Dorg.gradle.jvmargs="-Xmx1024m -XX:MaxMetaspaceSize=384m" -x "$CMAKE_BUILD_TASK" "assemble$BUILD_VARIANT"' sh "${GRADLE_BUILD_ARGS[@]}"; then
  DOCKER_STATUS=0
else
  DOCKER_STATUS=$?
fi

show_wsl_memory "après la compilation"
exit "$DOCKER_STATUS"