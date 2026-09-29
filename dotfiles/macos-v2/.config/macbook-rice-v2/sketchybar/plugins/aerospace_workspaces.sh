#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$HOME/.config/macbook-rice-v2/sketchybar"
source "$CONFIG_DIR/colors.sh"

sid="${NAME#workspace.}"
focused="${FOCUSED_WORKSPACE:-}"

if [[ -z "$focused" ]]; then
  state_file="${XDG_STATE_HOME:-$HOME/.local/state}/macbook-rice-v2/aerospace-focused-workspace"
  if [[ -f "$state_file" ]]; then
    IFS= read -r focused < "$state_file" || true
  fi
fi

highest_visible="${HIGHEST_VISIBLE_WORKSPACE:-3}"
if [[ ! "$sid" =~ ^[1-9]$ || ! "$highest_visible" =~ ^[1-9]$ ]]; then
  echo "Invalid AeroSpace workspace indicator state: workspace=$sid, highest=$highest_visible." >&2
  exit 1
fi

if ((sid > highest_visible)); then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

if [[ "$sid" == "$focused" ]]; then
  sketchybar --set "$NAME" \
    drawing=on \
    icon.color="$GREEN"
else
  sketchybar --set "$NAME" \
    drawing=on \
    icon.color="$TEXT"
fi
