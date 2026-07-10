#!/usr/bin/env bash
set -euo pipefail

if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "SIP:"
csrutil status 2>/dev/null || true

echo
echo "Services:"
launchctl list | grep -E 'com.asmvik.yabai|com.koekeishiya.skhd|homebrew.mxcl.sketchybar|com.macbook-linux-rice.borders' || true

echo
echo "Processes:"
ps -axo pid,comm | grep -E 'yabai|skhd|sketchybar|borders' | grep -v grep || true

echo
echo "yabai spaces:"
yabai -m query --spaces 2>/dev/null | jq 'map({index, id, "has-focus", "is-visible"})' || echo "yabai is not running or lacks Accessibility permission."

echo
echo "Recent errors:"
tail -n 20 "/tmp/yabai_$(whoami).err.log" "/tmp/skhd_$(whoami).err.log" 2>/dev/null || true
