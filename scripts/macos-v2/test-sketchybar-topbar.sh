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
if grep -qi brightness "$config"; then
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
    "volume",
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

for item in clock battery weather volume; do
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

volume_json="$(sketchybar --query volume)"
weather_json="$(sketchybar --query weather)"
BAR_VOLUME_JSON="$volume_json" BAR_WEATHER_JSON="$weather_json" python3 - <<'PY'
import json
import os
import sys

volume = json.loads(os.environ["BAR_VOLUME_JSON"])
weather = json.loads(os.environ["BAR_WEATHER_JSON"])
volume_geometry = volume.get("geometry") or {}
volume_background = volume_geometry.get("background") or {}
if volume_background.get("drawing") != "on":
  sys.exit("The volume item is missing its rounded pill background.")
if (
  volume_background.get("corner_radius") != 12
  or volume_background.get("height") != 24
):
  sys.exit("The volume pill geometry does not match the other top-bar pills.")

volume_bounds = volume.get("bounding_rects") or {}
weather_bounds = weather.get("bounding_rects") or {}
shared_displays = volume_bounds.keys() & weather_bounds.keys()
if not shared_displays:
  sys.exit("Could not compare volume and weather positions on a shared display.")
for display in shared_displays:
  volume_x = volume_bounds[display]["origin"][0]
  weather_x = weather_bounds[display]["origin"][0]
  if volume_x >= weather_x:
      sys.exit("The volume pill must be positioned to the left of weather.")
PY

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

echo "Legacy-style top bar passed: power, clock, progressive workspace dots, volume pill left of weather, battery, no brightness."
