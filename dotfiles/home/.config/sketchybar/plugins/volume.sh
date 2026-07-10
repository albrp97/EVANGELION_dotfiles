#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"

volume="$(osascript -e 'output volume of (get volume settings)' 2>/dev/null || printf '?')"
sketchybar --set "$NAME" icon.color="$TEXT" label.color="$TEXT" label="${volume}%"
