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
PROJECTS_DIR="$REPO_ROOT/examples"

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
  if ! read -r -p "Nom du nouveau projet React Native : " PROJECT_NAME; then
    echo "Could not read the project name." >&2
    exit 1
  fi
fi

if [[ -z "$PROJECT_NAME" || "$PROJECT_NAME" == "." || "$PROJECT_NAME" == ".." || "$PROJECT_NAME" == */* ]]; then
  echo "The project name must be a non-empty name without path separators." >&2
  exit 1
fi

if [[ -e "$PROJECTS_DIR/$PROJECT_NAME" || -L "$PROJECTS_DIR/$PROJECT_NAME" ]]; then
  echo "Project already exists: $PROJECTS_DIR/$PROJECT_NAME" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed or is not on PATH in WSL." >&2
  exit 1
fi

show_wsl_memory "avant la création du projet"

if docker run --rm --ulimit nofile=10240 \
  --env HOME=/tmp \
  --env PROJECT_UID="$(id -u)" \
  --env PROJECT_GID="$(id -g)" \
  -v npm-cache:/npm-cache \
  --env npm_config_cache=/npm-cache \
  -v "$PROJECTS_DIR:/workspace" \
  -w /workspace \
  react-native-android \
  sh -c '
    npx @react-native-community/cli@latest init "$1"
    status=$?
    # Le template RN peut demander un autre NDK que celui installe dans l image
    if [ -f "$1/android/build.gradle" ]; then
      sed -i "s/ndkVersion = \".*\"/ndkVersion = \"$(basename "$ANDROID_NDK_HOME")\"/" "$1/android/build.gradle"
    fi

    if [ "$status" -eq 0 ]; then
      gradle_properties="$1/android/gradle.properties"
      if [ ! -f "$gradle_properties" ]; then
        echo "Generated project is missing $gradle_properties." >&2
        status=1
      elif grep -q "^reactNativeArchitectures=" "$gradle_properties"; then
        sed -i "s/^reactNativeArchitectures=.*/reactNativeArchitectures=x86_64/" "$gradle_properties" || status=$?
      else
        printf "\nreactNativeArchitectures=x86_64\n" >> "$gradle_properties" || status=$?
      fi

      if [ "$status" -eq 0 ]; then
        if grep -q "^org.gradle.caching=" "$gradle_properties"; then
          sed -i "s/^org.gradle.caching=.*/org.gradle.caching=true/" "$gradle_properties" || status=$?
        else
          printf "\norg.gradle.caching=true\n" >> "$gradle_properties" || status=$?
        fi
      fi
    fi

    if [ -e "$1" ]; then
      chown -R "$PROJECT_UID:$PROJECT_GID" "$1" || exit 1
    fi
    exit "$status"
  ' sh "$PROJECT_NAME"; then
  DOCKER_STATUS=0
else
  DOCKER_STATUS=$?
fi

show_wsl_memory "après la création du projet"
exit "$DOCKER_STATUS"
