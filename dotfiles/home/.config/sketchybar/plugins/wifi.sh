#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"

device="$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi|AirPort/{getline; print $2; exit}')"
ssid=""

if [[ -n "$device" ]]; then
  airport="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
  if [[ -x "$airport" ]]; then
    ssid="$("$airport" -I 2>/dev/null | awk -F': ' '/ SSID/ { print $2; exit }')"
  fi
fi

if [[ -n "$ssid" ]]; then
  sketchybar --set "$NAME" icon.color="$GREEN" label="$ssid"
else
  sketchybar --set "$NAME" icon.color="$TEXT_MUTED" label="offline"
fi
