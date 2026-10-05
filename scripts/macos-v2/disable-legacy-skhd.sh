#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$HOME/.homebrew/bin:$HOME/.homebrew/sbin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script only supports macOS." >&2
  exit 1
fi

launch_domain="gui/$(id -u)"
legacy_labels=(
  "com.koekeishiya.skhd"
  "com.asmvik.skhd"
  "homebrew.mxcl.skhd"
)
backup_dir=""
removed_agent=false

for label in "${legacy_labels[@]}"; do
  launch_agent="$HOME/Library/LaunchAgents/$label.plist"

  if launchctl print "$launch_domain/$label" >/dev/null 2>&1; then
    if ! launchctl bootout "$launch_domain/$label"; then
      echo "Could not stop the legacy skhd LaunchAgent: $label" >&2
      exit 1
    fi
  fi

  if [[ -L "$launch_agent" ]]; then
    echo "Refusing to remove a symlink at $launch_agent." >&2
    exit 1
  fi
  if [[ -d "$launch_agent" ]]; then
    echo "Refusing to replace a directory at $launch_agent." >&2
    exit 1
  fi
  if [[ -f "$launch_agent" ]]; then
    installed_label="$(
      /usr/libexec/PlistBuddy -c 'Print :Label' "$launch_agent" 2>/dev/null ||
        true
    )"
    if [[ "$installed_label" != "$label" ]]; then
      echo "Refusing to remove an unrelated LaunchAgent at $launch_agent." >&2
      exit 1
    fi

    if [[ -z "$backup_dir" ]]; then
      backup_dir="$HOME/.macbook-rice-v2-backup/legacy-skhd-$(date +%Y%m%d-%H%M%S)"
      mkdir -p "$backup_dir"
    fi
    cp -Pp "$launch_agent" "$backup_dir/$label.plist"
    rm -f "$launch_agent"
    removed_agent=true
  fi
done

skhd_pids="$(pgrep -x skhd || true)"
while IFS= read -r pid; do
  [[ "$pid" =~ ^[0-9]+$ ]] || continue
  process_path="$(ps -p "$pid" -o comm= | sed 's/^[[:space:]]*//')"
  if [[ "$process_path" != "skhd" && "$process_path" != */skhd ]]; then
    echo "Refusing to terminate an unexpected process named skhd: $process_path" >&2
    exit 1
  fi
  if ! kill "$pid"; then
    echo "Could not stop the legacy skhd process $pid." >&2
    exit 1
  fi
done <<< "$skhd_pids"

for ((attempt = 0; attempt < 20; attempt++)); do
  if ! pgrep -x skhd >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
if pgrep -x skhd >/dev/null 2>&1; then
  echo "The legacy skhd process did not stop." >&2
  exit 1
fi

brew_bin="$(command -v brew || true)"
if [[ -n "$brew_bin" ]] && "$brew_bin" list --formula skhd >/dev/null 2>&1; then
  echo "Uninstalling the legacy skhd formula so it cannot reclaim Command+number shortcuts."
  if ! "$brew_bin" uninstall --formula skhd; then
    echo "Could not uninstall the legacy skhd formula." >&2
    exit 1
  fi
fi

if [[ "$removed_agent" == true ]]; then
  echo "Removed legacy skhd LaunchAgent files; backups are in $backup_dir."
fi
