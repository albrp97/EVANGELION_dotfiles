#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/macbook-rice-v2/sketchybar}"
SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-sketchybar}"
DISKUTIL_BIN="${DISKUTIL_BIN:-diskutil}"
PLUTIL_BIN="${PLUTIL_BIN:-plutil}"
source "$CONFIG_DIR/colors.sh"

cores="$(sysctl -n hw.ncpu)"

cpu_percent() {
  ps -A -o %cpu= |
    awk -v cores="$cores" '
      { total += $1 }
      END {
        usage = total / cores
        if (usage < 0) usage = 0
        if (usage > 100) usage = 100
        printf "%02d%%", usage
      }
    '
}

ram_percent() {
  local pages_free
  local pages_inactive
  local pages_speculative
  local total_memory
  local page_size
  local available_memory

  pages_free="$(vm_stat | awk '/Pages free/ {gsub("\\.", "", $3); print $3}')"
  pages_inactive="$(vm_stat | awk '/Pages inactive/ {gsub("\\.", "", $3); print $3}')"
  pages_speculative="$(vm_stat | awk '/Pages speculative/ {gsub("\\.", "", $3); print $3}')"
  total_memory="$(sysctl -n hw.memsize)"
  page_size="$(vm_stat | awk '/page size of/ {print $8}')"
  available_memory=$(( (pages_free + pages_inactive + pages_speculative) * page_size ))

  awk -v total="$total_memory" -v available="$available_memory" '
    BEGIN {
      used = ((total - available) / total) * 100
      if (used < 0) used = 0
      if (used > 100) used = 100
      printf "%02d%%", used
    }
  '
}

ssd_percent() {
  local container_info
  local container_size
  local container_free
  local used_bytes
  local value

  if ! container_info="$("$DISKUTIL_BIN" info -plist / 2>/dev/null)"; then
    echo "Could not read the APFS container information." >&2
    exit 1
  fi
  if ! container_size="$(
    printf "%s" "$container_info" |
      "$PLUTIL_BIN" -extract APFSContainerSize raw -o - - 2>/dev/null
  )" ||
    ! container_free="$(
      printf "%s" "$container_info" |
        "$PLUTIL_BIN" -extract APFSContainerFree raw -o - - 2>/dev/null
    )" ||
    [[ ! "$container_size" =~ ^[0-9]+$ ]] ||
    [[ ! "$container_free" =~ ^[0-9]+$ ]] ||
    ((container_size == 0 || container_free > container_size)); then
    echo "Could not read the APFS container capacity and free space." >&2
    exit 1
  fi

  used_bytes=$((container_size - container_free))
  value=$(( (used_bytes * 100 + container_size / 2) / container_size ))
  printf "%02d%%" "$value"
}

case "$NAME" in
  cpu)
    value="$(cpu_percent)"
    icon=""
    ;;
  ram)
    value="$(ram_percent)"
    icon=""
    ;;
  ssd)
    value="$(ssd_percent)"
    icon=""
    ;;
  *)
    echo "Unsupported system usage item: $NAME" >&2
    exit 1
    ;;
esac

numeric_value="${value%%%}"
color="$TEXT"
if ((numeric_value >= 80)); then
  color="$ORANGE"
fi

"$SKETCHYBAR_BIN" --set "$NAME" \
  icon="$icon" \
  icon.color="$color" \
  label.color="$color" \
  label="$value"
