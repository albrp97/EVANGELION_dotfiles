#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/macbook-rice-v2"
STATE_FILE="$STATE_DIR/desktop-cleanliness.tsv"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script only supports macOS." >&2
  exit 1
fi

usage() {
  echo "Usage: $0 {apply|status|restore}" >&2
}

settings() {
  printf '%s\t%s\t%s\t%s\n' \
    com.apple.finder CreateDesktop bool false \
    com.apple.WindowManager StandardHideWidgets bool true \
    com.apple.WindowManager StageManagerHideWidgets bool true
}

capture_original_settings() {
  local temp_file domain key type desired value

  mkdir -p "$STATE_DIR"
  temp_file="$(mktemp "$STATE_FILE.XXXXXX")"

  while IFS=$'\t' read -r domain key type desired; do
    if value="$(defaults read "$domain" "$key" 2>/dev/null)"; then
      case "$value" in
        1|true|TRUE) value=true ;;
        0|false|FALSE) value=false ;;
        *)
          rm -f "$temp_file"
          echo "Cannot safely back up $domain $key; unexpected value: $value" >&2
          return 1
          ;;
      esac
      printf '%s\t%s\t%s\tpresent\t%s\n' "$domain" "$key" "$type" "$value" >> "$temp_file"
    else
      printf '%s\t%s\t%s\tmissing\t-\n' "$domain" "$key" "$type" >> "$temp_file"
    fi
  done < <(settings)

  mv "$temp_file" "$STATE_FILE"
}

restart_finder() {
  local uid target
  uid="$(id -u)"
  target="gui/$uid/com.apple.Finder"
  if ! launchctl print "$target" >/dev/null 2>&1; then
    echo "Cannot find the expected desktop service: $target" >&2
    return 1
  fi
  launchctl kickstart -k "$target"
}

apply_settings() {
  if [[ ! -f "$STATE_FILE" ]]; then
    capture_original_settings
  fi

  while IFS=$'\t' read -r domain key type value; do
    defaults write "$domain" "$key" "-$type" "$value"
  done < <(settings)

  restart_finder
  echo "Desktop cleanliness settings applied. Original values are saved in:"
  echo "  $STATE_FILE"
}

show_status() {
  local domain key type value

  while IFS=$'\t' read -r domain key type value; do
    if value="$(defaults read "$domain" "$key" 2>/dev/null)"; then
      printf '%s %s = %s\n' "$domain" "$key" "$value"
    else
      printf '%s %s = unset (macOS default)\n' "$domain" "$key"
    fi
  done < <(settings)
}

restore_settings() {
  local domain key type state value
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "No saved v2 desktop settings were found at $STATE_FILE" >&2
    exit 1
  fi

  while IFS=$'\t' read -r domain key type state value; do
    case "$type:$state" in
      bool:present)
        case "$value" in
          true|false) defaults write "$domain" "$key" -bool "$value" ;;
          *)
            echo "Invalid saved boolean for $domain $key: $value" >&2
            return 1
            ;;
        esac
        ;;
      bool:missing)
        if defaults read "$domain" "$key" >/dev/null 2>&1; then
          defaults delete "$domain" "$key"
        fi
        ;;
      *)
        echo "Invalid saved state for $domain $key" >&2
        return 1
        ;;
    esac
  done < "$STATE_FILE"

  restart_finder
  rm "$STATE_FILE"
  echo "Original desktop settings restored."
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

case "$1" in
  apply) apply_settings ;;
  status) show_status ;;
  restore) restore_settings ;;
  *)
    usage
    exit 2
    ;;
esac
