#!/usr/bin/env bash
set -euo pipefail

iface="$(route get default 2>/dev/null | awk '/interface:/ {print $2; exit}')"

if [[ -z "$iface" ]]; then
  sketchybar --set "$NAME" label=" 0.0  0.0"
  exit 0
fi

read -r rx1 tx1 < <(netstat -ibn | awk -v iface="$iface" '$1 == iface && $7 ~ /^[0-9]+$/ && $10 ~ /^[0-9]+$/ {rx += $7; tx += $10} END {print rx + 0, tx + 0}')
sleep 1
read -r rx2 tx2 < <(netstat -ibn | awk -v iface="$iface" '$1 == iface && $7 ~ /^[0-9]+$/ && $10 ~ /^[0-9]+$/ {rx += $7; tx += $10} END {print rx + 0, tx + 0}')

awk -v rx="$((rx2 - rx1))" -v tx="$((tx2 - tx1))" 'BEGIN {
  printf " %.1f  %.1f", rx / 1048576, tx / 1048576
}' | xargs -I{} sketchybar --set "$NAME" label="{}"
