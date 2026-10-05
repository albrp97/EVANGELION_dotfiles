#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$HOME/.homebrew/bin:$HOME/.homebrew/sbin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

config="$HOME/.config/macbook-rice-v2/sketchybar/sketchybarrc"
power_menu="$HOME/.local/bin/rice-v2-power-menu"

if [[ ! -x "$config" ]]; then
  echo "The installed v2 SketchyBar config is missing or not executable." >&2
  exit 1
fi
if [[ ! -x "$power_menu" ]]; then
  echo "The v2 native power chooser is missing or not executable." >&2
  exit 1
fi
if grep -qiE 'brightness|network_usage|download|upload|volume' "$config"; then
  echo "The legacy brightness item must remain excluded from the v2 bar." >&2
  exit 1
fi
if ! grep -Fq 'topmost=window' "$config"; then
  echo "SketchyBar must use the window layer so macOS system menu controls remain accessible." >&2
  exit 1
fi
if ! grep -Fq 'click_script="$HOME/.local/bin/rice-v2-power-menu"' "$config"; then
  echo "The power icon is not connected to the native macOS chooser." >&2
  exit 1
fi
if ! grep -Fq 'default button "Cancel" cancel button "Cancel"' "$power_menu"; then
  echo "Destructive power actions must default to Cancel." >&2
  exit 1
fi
if ! pgrep -x sketchybar >/dev/null 2>&1; then
  echo "SketchyBar is not running; install the v2 LaunchAgent first." >&2
  exit 1
fi

bar_json="$(sketchybar --query bar)"
BAR_JSON="$bar_json" python3 - <<'PY'
import json
import os
import sys

bar = json.loads(os.environ["BAR_JSON"])
items = set(bar.get("items") or [])
expected = {
    "power",
    "clock",
    "spaces",
    "battery",
    "weather",
    "cpu",
    "ram",
    "ssd",
    "cpu_ram_gap",
    "ram_ssd_gap",
    "system_weather_gap",
    "system_usage",
    "wallpaper_rotation",
    *(f"workspace.{number}" for number in range(1, 10)),
}
missing = sorted(expected - items)
if missing:
    sys.exit(f"Missing legacy-style top-bar items: {', '.join(missing)}")
if "brightness" in items:
    sys.exit("The brightness item is still present in the active bar.")
if (
    bar.get("position") != "top"
    or int(bar.get("height", 0)) != 34
    or bar.get("topmost") != "on"
):
    sys.exit("The active top bar is not running with its configured visible window layer.")
PY

power_item_json="$(sketchybar --query power)"
BAR_ITEM_JSON="$power_item_json" python3 - <<'PY'
import json
import os
import sys

item = json.loads(os.environ["BAR_ITEM_JSON"])
icon = item.get("icon") or {}
if item.get("name") != "power" or icon.get("value") != "⏻" or icon.get("drawing") != "on":
    sys.exit("The legacy-style power icon is not visible.")
PY

for item in clock battery weather cpu ram ssd; do
  item_json="$(sketchybar --query "$item")"
  BAR_ITEM_JSON="$item_json" python3 - "$item" <<'PY'
import json
import os
import sys

item = json.loads(os.environ["BAR_ITEM_JSON"])
name = sys.argv[1]
if item.get("name") != name or not (item.get("label") or {}).get("value"):
    sys.exit(f"The {name} item has no live label.")
PY
done

cpu_json="$(sketchybar --query cpu)"
ram_json="$(sketchybar --query ram)"
ssd_json="$(sketchybar --query ssd)"
cpu_ram_gap_json="$(sketchybar --query cpu_ram_gap)"
ram_ssd_gap_json="$(sketchybar --query ram_ssd_gap)"
system_weather_gap_json="$(sketchybar --query system_weather_gap)"
system_usage_json="$(sketchybar --query system_usage)"
weather_json="$(sketchybar --query weather)"
power_json="$(sketchybar --query power)"
clock_json="$(sketchybar --query clock)"
spaces_json="$(sketchybar --query spaces)"
battery_json="$(sketchybar --query battery)"
BAR_SYSTEM_USAGE_JSON="$system_usage_json" \
BAR_CPU_JSON="$cpu_json" \
BAR_RAM_JSON="$ram_json" \
BAR_SSD_JSON="$ssd_json" \
BAR_CPU_RAM_GAP_JSON="$cpu_ram_gap_json" \
BAR_RAM_SSD_GAP_JSON="$ram_ssd_gap_json" \
BAR_SYSTEM_WEATHER_GAP_JSON="$system_weather_gap_json" \
BAR_WEATHER_JSON="$weather_json" \
BAR_POWER_JSON="$power_json" \
BAR_CLOCK_JSON="$clock_json" \
BAR_SPACES_JSON="$spaces_json" \
BAR_BATTERY_JSON="$battery_json" \
python3 - <<'PY'
import json
import os
import re
import sys

cpu = json.loads(os.environ["BAR_CPU_JSON"])
ram = json.loads(os.environ["BAR_RAM_JSON"])
ssd = json.loads(os.environ["BAR_SSD_JSON"])
cpu_ram_gap = json.loads(os.environ["BAR_CPU_RAM_GAP_JSON"])
ram_ssd_gap = json.loads(os.environ["BAR_RAM_SSD_GAP_JSON"])
system_weather_gap = json.loads(os.environ["BAR_SYSTEM_WEATHER_GAP_JSON"])
system_usage = json.loads(os.environ["BAR_SYSTEM_USAGE_JSON"])
weather = json.loads(os.environ["BAR_WEATHER_JSON"])
power = json.loads(os.environ["BAR_POWER_JSON"])
clock = json.loads(os.environ["BAR_CLOCK_JSON"])
spaces = json.loads(os.environ["BAR_SPACES_JSON"])
battery = json.loads(os.environ["BAR_BATTERY_JSON"])
for item, icon in (
    (cpu, ""),
    (ram, ""),
    (ssd, ""),
):
    label = (item.get("label") or {}).get("value") or ""
    valid_label = re.fullmatch(r"\d{2,3}%", label)
    if not valid_label:
        sys.exit(f"The {item['name']} item has an invalid label: {label!r}")
    if (item.get("icon") or {}).get("value") != icon:
        sys.exit(f"The {item['name']} item has the wrong metric icon.")
    if (item.get("geometry") or {}).get("width") != 56:
        sys.exit(f"The {item['name']} item must use its fixed metric width.")

system_geometry = system_usage.get("geometry") or {}
system_background = system_geometry.get("background") or {}
if system_background.get("drawing") != "on":
    sys.exit("The system usage item is missing its rounded pill background.")
if (
    system_background.get("corner_radius") != 12
    or system_background.get("height") != 24
    or system_background.get("padding_left") != 15
    or system_background.get("padding_right") != 15
):
    sys.exit("The system usage pill geometry does not match the other top-bar pills.")

for spacer, expected_width in (
    (cpu_ram_gap, 2),
    (ram_ssd_gap, 6),
    (system_weather_gap, 6),
):
    spacer_geometry = spacer.get("geometry") or {}
    if spacer_geometry.get("width") != expected_width or spacer_geometry.get("drawing") != "on":
        sys.exit(f"The {spacer['name']} spacer must remain a visible-width transparent spacer.")

pill_items = {
  item["name"]: item
  for item in (
    power,
    clock,
    spaces,
    system_usage,
    weather,
    battery,
  )
}
for display in (
  pill_items["power"].get("bounding_rects", {}).keys()
  & pill_items["clock"].get("bounding_rects", {}).keys()
  & pill_items["spaces"].get("bounding_rects", {}).keys()
  & pill_items["system_usage"].get("bounding_rects", {}).keys()
  & pill_items["weather"].get("bounding_rects", {}).keys()
  & pill_items["battery"].get("bounding_rects", {}).keys()
):
  ordered = [
    pill_items[name]["bounding_rects"][display]
    for name in ("power", "clock", "spaces")
  ]
  right_side = [
  pill_items[name]["bounding_rects"][display]
  for name in ("system_usage", "weather", "battery")
  ]
  gaps = [
    ordered[index + 1]["origin"][0]
    - (ordered[index]["origin"][0] + ordered[index]["size"][0])
    for index in range(len(ordered) - 1)
  ]
  gaps.extend(
    right_side[index + 1]["origin"][0]
    - (right_side[index]["origin"][0] + right_side[index]["size"][0])
    for index in range(len(right_side) - 1)
  )
  if any(abs(gap - 6) > 0.5 for gap in gaps):
    sys.exit(f"Top-bar pill gaps must all be six pixels, got {gaps}.")

cpu_bounds = cpu.get("bounding_rects") or {}
ram_bounds = ram.get("bounding_rects") or {}
ssd_bounds = ssd.get("bounding_rects") or {}
system_bounds = system_usage.get("bounding_rects") or {}
weather_bounds = weather.get("bounding_rects") or {}
shared_displays = (
  cpu_bounds.keys()
  & ram_bounds.keys()
  & ssd_bounds.keys()
  & system_bounds.keys()
  & weather_bounds.keys()
)
if not shared_displays:
  sys.exit("Could not compare CPU/RAM and weather positions on a shared display.")
for display in shared_displays:
  cpu_x = cpu_bounds[display]["origin"][0]
  ram_x = ram_bounds[display]["origin"][0]
  ssd_x = ssd_bounds[display]["origin"][0]
  weather_x = weather_bounds[display]["origin"][0]
  cpu_width = cpu_bounds[display]["size"][0]
  ram_width = ram_bounds[display]["size"][0]
  if ram_x - (cpu_x + cpu_width) < 4:
      sys.exit("The CPU/RAM metrics need the reduced separator.")
  if ssd_x - (ram_x + ram_width) < 4:
      sys.exit("The RAM/SSD metrics need the reduced separator.")
  if not cpu_x < ram_x < ssd_x < weather_x:
      sys.exit("The fixed-width CPU/RAM/SSD metrics must be positioned to the left of weather.")
PY

system_usage_plugin="$HOME/.config/macbook-rice-v2/sketchybar/plugins/system_usage.sh"
warning_test_dir="$(mktemp -d)"
trap 'rm -rf "$warning_test_dir"' EXIT
cat > "$warning_test_dir/df" <<'EOF'
#!/bin/sh
printf '%s\n' \
  'Filesystem 1024-blocks Used Available Capacity Mounted on' \
  '/dev/mock 100 85 15 85% /'
EOF
cat > "$warning_test_dir/sketchybar" <<'EOF'
#!/bin/sh
printf '%s\n' "$*"
EOF
chmod u+x "$warning_test_dir/df" "$warning_test_dir/sketchybar"
warning_output="$(
  DF_BIN="$warning_test_dir/df" \
  SKETCHYBAR_BIN="$warning_test_dir/sketchybar" \
  NAME=ssd \
  CONFIG_DIR="$HOME/.config/macbook-rice-v2/sketchybar" \
  bash "$system_usage_plugin"
)"
if ! grep -Fq 'icon.color=0xfff6c177' <<<"$warning_output" ||
  ! grep -Fq 'label.color=0xfff6c177' <<<"$warning_output" ||
  ! grep -Fq 'label=85%' <<<"$warning_output"; then
  echo "The SDD metric does not turn orange at 80% usage." >&2
  exit 1
fi
trap - EXIT
rm -rf "$warning_test_dir"

focused_workspace="$(aerospace list-workspaces --focused)"
highest_visible_workspace=3
if [[ "$focused_workspace" =~ ^[1-9]$ ]] &&
  ((focused_workspace > highest_visible_workspace)); then
  highest_visible_workspace="$focused_workspace"
fi
if ! used_workspaces="$(aerospace list-windows --all --format '%{workspace}')"; then
  echo "Could not determine which AeroSpace workspaces are in use." >&2
  exit 1
fi
while IFS= read -r workspace; do
  [[ "$workspace" =~ ^[1-9]$ ]] || continue
  if ((workspace > highest_visible_workspace)); then
    highest_visible_workspace="$workspace"
  fi
done <<< "$used_workspaces"

for number in 1 2 3 4 5 6 7 8 9; do
  item_json="$(sketchybar --query "workspace.$number")"
  AEROSPACE_BAR_ITEM_JSON="$item_json" python3 - \
    "$number" "$focused_workspace" "$highest_visible_workspace" <<'PY'
import json
import os
import sys

item = json.loads(os.environ["AEROSPACE_BAR_ITEM_JSON"])
number, focused, highest_visible = sys.argv[1:]
icon = item.get("icon") or {}
geometry = item.get("geometry") or {}
expected_drawing = "on" if int(number) <= int(highest_visible) else "off"
expected_color = "0xffa3d977" if number == focused else "0xffc4a7e7"
if geometry.get("drawing") != expected_drawing:
    sys.exit(
        f"Workspace {number} should have drawing={expected_drawing}, "
        f"got {geometry.get('drawing')}."
    )
if expected_drawing == "off":
    raise SystemExit(0)
if icon.get("value") != "●" or icon.get("drawing") != "on":
    sys.exit(f"Workspace {number} is not rendered as a visible dot.")
if icon.get("color") != expected_color:
    sys.exit(f"Workspace {number} has the wrong active/inactive dot color.")
PY
done

menu_actions="$("$power_menu" --list-actions)"
for action in "Lock Screen" "Display Off" "Sleep" "Toggle 30m Caffeinate" "Restart v2 UI"; do
  if ! grep -Fqx "$action" <<<"$menu_actions"; then
    echo "The native power chooser is missing '$action'." >&2
    exit 1
  fi
done
for action in "Log Out..." "Restart Mac..." "Shut Down Mac..."; do
  if ! grep -Fqx "$action" <<<"$menu_actions"; then
    echo "The native power chooser is missing the confirmed action '$action'." >&2
    exit 1
  fi
done
if grep -qi brightness <<<"$menu_actions"; then
  echo "Brightness must not appear in the native power chooser." >&2
  exit 1
fi

echo "Legacy-style top bar passed: power, clock, CPU/RAM/SSD pill, weather, battery, no network or volume."
