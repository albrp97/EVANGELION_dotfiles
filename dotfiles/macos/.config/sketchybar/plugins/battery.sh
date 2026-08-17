#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"

percent="$(pmset -g batt | awk '/%/ { match($0, /[0-9]+%/); if (RSTART) { print substr($0, RSTART, RLENGTH - 1); exit } }')"
state="$(pmset -g batt | awk -F"'" '/Battery Power|AC Power/ { print $2; exit }')"

percent="${percent:-0}"
icon=""
color="$TEXT"

if [[ "$percent" -ge 95 ]]; then
  icon=""
elif [[ "$state" == "AC Power" ]]; then
  icon=""
elif [[ "$percent" -ge 70 ]]; then
  icon=""
elif [[ "$percent" -ge 60 ]]; then
  icon=""
elif [[ "$percent" -ge 30 ]]; then
  icon=""
else
  icon=""
fi

if [[ "$percent" -ge 95 ]]; then
  color="$GREEN"
elif [[ "$state" == "AC Power" ]]; then
  color="$ORANGE"
elif [[ "$percent" -ge 70 ]]; then
  color="$GREEN"
elif [[ "$percent" -lt 30 ]]; then
  color="$ORANGE"
fi

sketchybar --set "$NAME" \
  icon="$icon" \
  icon.color="$color" \
  label.color="$color" \
  label="${percent}%"
