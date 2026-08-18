#!/usr/bin/env bash
set -euo pipefail

cursor="$(hyprctl cursorpos -j)"
read -r x y <<<"$(jq -r '"\(.x) \(.y)"' <<<"$cursor")"
read -r min_x min_y extent_x extent_y <<<"$(
  hyprctl monitors -j | jq -r '
    ([.[] | .x] | min) as $min_x
    | ([.[] | .y] | min) as $min_y
    | ([.[] | (.x + .width)] | max) as $max_x
    | ([.[] | (.y + .height)] | max) as $max_y
    | "\($min_x) \($min_y) \($max_x - $min_x) \($max_y - $min_y)"
  '
)"

x=$((x - min_x))
y=$((y - min_y))
exec "$(dirname "$0")/eva-vclick" "$x" "$y" "$extent_x" "$extent_y"
