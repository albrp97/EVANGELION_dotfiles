#!/usr/bin/env bash
set -euo pipefail

sid="${1:?space id required}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"

displays_json="$(yabai -m query --displays 2>/dev/null || true)"
spaces_json="$(yabai -m query --spaces 2>/dev/null || true)"
primary_display="$(
  jq -r '
    [ .[]
    | select(.frame.x == 0 and .frame.y == 0)
    | .index
    ] | sort | .[0] // empty
  ' <<<"$displays_json" 2>/dev/null || true
)"
focused="$(
  jq -r --argjson display "${primary_display:-0}" '
    [ .[]
    | select(.display == $display and ."is-visible" == true)
    | .index
    ] | .[0] // empty
  ' <<<"$spaces_json" 2>/dev/null || true
)"
highest_visible="$(
  jq -r --argjson display "${primary_display:-0}" '
    [ .[]
    | select(
        .display == $display
        and (
          ."is-visible" == true
          or ."has-focus" == true
          or ((.windows // []) | length) > 0
        )
      )
    | .index
    ] | max // 0
  ' <<<"$spaces_json" 2>/dev/null || true
)"
space_json="$(jq --arg sid "$sid" '.[] | select((.index | tostring) == $sid)' <<<"$spaces_json" 2>/dev/null || true)"
exists="$(jq -r '.index // empty' <<<"$space_json" 2>/dev/null || true)"

if [[ -z "$exists" || "$sid" -gt "${highest_visible:-0}" ]]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

if [[ "$sid" == "$focused" ]]; then
  sketchybar --set "$NAME" drawing=on icon="●" icon.color="$GREEN"
else
  sketchybar --set "$NAME" drawing=on icon="●" icon.color="$TEXT"
fi
