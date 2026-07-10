#!/usr/bin/env bash
set -euo pipefail

sketchybar --set "$NAME" label="$(date '+%H:%M  %d %b')"
