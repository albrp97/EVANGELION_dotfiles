#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$HOME/.config/macbook-rice-v2/sketchybar"
source "$CONFIG_DIR/colors.sh"

case "${SENDER:-}" in
  mouse.entered)
    sketchybar --animate tanh 10 --set "$NAME" background.color="$ITEM_BG_ACTIVE" icon.color="$GREEN"
    ;;
  mouse.exited)
    sketchybar --animate tanh 12 --set "$NAME" background.color="$ITEM_BG" icon.color="$TEXT"
    ;;
esac
