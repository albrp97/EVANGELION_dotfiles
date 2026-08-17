#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"

weather="$(curl -fsS --max-time 3 'https://wttr.in/?format=%t' 2>/dev/null | tr -d '+[:space:]' || true)"
weather="${weather:-?°C}"

sketchybar --set "$NAME" icon.color="$TEXT" label.color="$TEXT" label="$weather"
