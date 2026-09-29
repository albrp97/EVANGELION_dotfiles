#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$HOME/.config/macbook-rice-v2/sketchybar"
source "$CONFIG_DIR/colors.sh"

battery_info="$(pmset -g batt)"
percent="$(
  printf '%s\n' "$battery_info" |
    sed -nE 's/.*[[:space:]]([0-9]{1,3})%;.*/\1/p' |
    head -n 1
)"
power_source="$(
  printf '%s\n' "$battery_info" |
    sed -nE "s/Now drawing from '([^']+)'.*/\1/p" |
    head -n 1
)"

if [[ ! "$percent" =~ ^[0-9]{1,3}$ ]]; then
  echo "Could not read the Mac battery percentage from pmset." >&2
  exit 1
fi

color="$TEXT"
icon=""
if [[ "$percent" -ge 95 ]]; then
  icon=""
  color="$GREEN"
elif [[ "$power_source" == "AC Power" ]]; then
  icon=""
  color="$ORANGE"
elif [[ "$percent" -ge 70 ]]; then
  icon=""
  color="$GREEN"
elif [[ "$percent" -ge 60 ]]; then
  icon=""
elif [[ "$percent" -ge 30 ]]; then
  icon=""
else
  icon=""
fi

if [[ "$percent" -lt 30 ]]; then
  color="$ORANGE"
fi

sketchybar --set "$NAME" \
  icon="$icon" \
  icon.color="$color" \
  label.color="$color" \
  label="${percent}%"
