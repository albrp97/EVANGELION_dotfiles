#!/usr/bin/env bash
set -euo pipefail

pages_free="$(vm_stat | awk '/Pages free/ {gsub("\\.", "", $3); print $3}')"
pages_inactive="$(vm_stat | awk '/Pages inactive/ {gsub("\\.", "", $3); print $3}')"
pages_speculative="$(vm_stat | awk '/Pages speculative/ {gsub("\\.", "", $3); print $3}')"
pages_total="$(sysctl -n hw.memsize)"
page_size="$(vm_stat | awk '/page size of/ {print $8}')"

available=$(( (pages_free + pages_inactive + pages_speculative) * page_size ))
used_percent="$(awk -v total="$pages_total" -v available="$available" 'BEGIN {printf "%d%%", ((total - available) / total) * 100}')"

sketchybar --set "$NAME" label="$used_percent"
