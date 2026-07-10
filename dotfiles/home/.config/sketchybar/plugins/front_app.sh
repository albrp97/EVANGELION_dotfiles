#!/usr/bin/env bash
set -euo pipefail

app="${INFO:-$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || echo "")}"

sketchybar --set "$NAME" label="$app"
