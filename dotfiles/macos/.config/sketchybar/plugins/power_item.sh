#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"

name="${NAME:-}"
sender="${SENDER:-}"

case "$sender" in
  mouse.entered)
    sketchybar --animate tanh 10 --set "$name" background.color="$ITEM_BG_ACTIVE" icon.color="$GREEN"
    ;;
  mouse.exited)
    sketchybar --animate tanh 12 --set "$name" background.color="$ITEM_BG" icon.color="$TEXT"
    ;;
esac
