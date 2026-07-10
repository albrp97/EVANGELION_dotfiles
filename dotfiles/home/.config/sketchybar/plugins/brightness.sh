#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"

brightness="$(
  ioreg -w0 -l 2>/dev/null \
    | perl -0ne '
      if (/"brightness"=\{[^}]*"max"=([0-9]+)[^}]*"value"=([0-9]+)/s) {
        printf "%d%%", ($2 / $1) * 100;
      }'
)"
brightness="${brightness:-?%}"

sketchybar --set "$NAME" icon.color="$TEXT" label.color="$TEXT" label="$brightness"
