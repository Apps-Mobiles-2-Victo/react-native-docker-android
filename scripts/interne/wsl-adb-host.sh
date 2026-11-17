#!/usr/bin/env bash

wsl_config_uses_mirrored_networking() {
  awk '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }

    {
      line = trim($0)
      lowered = tolower(line)

      if (lowered ~ /^\[wsl2\]$/) {
        in_wsl2 = 1
        next
      }
      if (lowered ~ /^\[[^]]+\]$/) {
        in_wsl2 = 0
        next
      }
      if (!in_wsl2 || line == "" || line ~ /^#/) {
        next
      }

      separator = index(line, "=")
      if (!separator) {
        next
      }
      key = tolower(trim(substr(line, 1, separator - 1)))
      value = tolower(trim(substr(line, separator + 1)))
      sub(/[[:space:]]+#.*/, "", value)
      if (key == "networkingmode") {
        mode = value
      }
    }

    END {
      exit mode != "mirrored"
    }
  ' "$1"
}

wsl_uses_mirrored_networking() {
  local windows_userprofile config_path

  if ! command -v cmd.exe >/dev/null 2>&1 || ! command -v wslpath >/dev/null 2>&1; then
    return 1
  fi

  windows_userprofile="$(cmd.exe /c echo %USERPROFILE% 2>/dev/null | tr -d '\r')" || return 1
  [[ -n "$windows_userprofile" ]] || return 1

  windows_userprofile="$(wslpath -u "$windows_userprofile" 2>/dev/null)" || return 1
  config_path="${windows_userprofile%/}/.wslconfig"
  [[ -r "$config_path" ]] || return 1

  wsl_config_uses_mirrored_networking "$config_path"
}

get_default_adb_host() {
  if wsl_uses_mirrored_networking; then
    printf '%s\n' localhost
    return
  fi

  ip route show default | awk 'NR == 1 { print $3 }'
}
