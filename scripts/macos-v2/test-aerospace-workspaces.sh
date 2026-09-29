#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$HOME/.homebrew/bin:$HOME/.homebrew/sbin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

state_file="${XDG_STATE_HOME:-$HOME/.local/state}/macbook-rice-v2/aerospace-focused-workspace"
original_workspace="$(aerospace list-workspaces --focused)"
focused_window_id="$(
  aerospace list-windows --focused --format '%{window-id}'
)"

if ! command -v sketchybar >/dev/null 2>&1; then
  echo "SketchyBar CLI is required to verify the active workspace indicator." >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 is required to verify SketchyBar item state." >&2
  exit 1
fi

restore_state() {
  local result=$?
  local current_window_workspace
  trap - EXIT
  sleep 0.25

  if [[ -n "$focused_window_id" ]]; then
    current_window_workspace="$(
      aerospace list-windows --all --format '%{window-id} %{workspace}' |
        awk -v window_id="$focused_window_id" '$1 == window_id { print $2; exit }'
    )"
    if [[ -n "$current_window_workspace" && "$current_window_workspace" != "$original_workspace" ]]; then
      if ! aerospace move-node-to-workspace \
        --window-id "$focused_window_id" \
        --focus-follows-window \
        "$original_workspace"; then
        echo "Could not restore the focused window to workspace $original_workspace." >&2
        result=1
      fi
    fi
  fi

  if [[ "$(aerospace list-workspaces --focused)" != "$original_workspace" ]]; then
    if ! aerospace workspace "$original_workspace"; then
      echo "Could not restore workspace $original_workspace." >&2
      result=1
    fi
  fi
  if [[ -n "$focused_window_id" ]]; then
    if ! aerospace focus --window-id "$focused_window_id"; then
      echo "Could not restore focused window $focused_window_id." >&2
      result=1
    fi
  fi

  exit "$result"
}
trap restore_state EXIT

workspace_item_has_icon_color() {
  local workspace_number="$1"
  local expected_icon_color="$2"
  local item_json

  if ! item_json="$(sketchybar --query "workspace.$workspace_number")"; then
    return 1
  fi

  AEROSPACE_BAR_ITEM_JSON="$item_json" python3 - \
    "$workspace_number" "$expected_icon_color" 2>/dev/null <<'PY'
import json
import os
import sys

item = json.loads(os.environ["AEROSPACE_BAR_ITEM_JSON"])
expected_workspace = sys.argv[1]
expected_icon_color = sys.argv[2]
geometry = item.get("geometry") or {}
background = geometry.get("background") or {}
icon = item.get("icon") or {}

if item.get("name") != f"workspace.{expected_workspace}":
    sys.exit(1)
if icon.get("value") != "●" or icon.get("drawing") != "on":
    sys.exit(1)
if icon.get("color") != expected_icon_color or background.get("drawing") != "off":
    sys.exit(1)
PY
}

workspace_item_is_active() {
  workspace_item_has_icon_color "$1" "0xffa3d977"
}

workspace_item_is_inactive() {
  workspace_item_has_icon_color "$1" "0xffc4a7e7"
}

workspace_bar_state_matches() {
  if [[ "$1" == "scratch" ]]; then
    workspace_item_is_inactive 1
  else
    workspace_item_is_active "$1"
  fi
}

assert_workspace() {
  local expected="$1"
  local actual
  local attempt

  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    actual="$(aerospace list-workspaces --focused)"
    if [[ "$actual" == "$expected" ]]; then
      if [[ -f "$state_file" ]] && [[ "$(cat "$state_file")" == "$expected" ]]; then
        if workspace_bar_state_matches "$expected"; then
          sleep 0.1
          actual="$(aerospace list-workspaces --focused)"
          if [[ "$actual" == "$expected" ]] &&
            [[ -f "$state_file" ]] &&
            [[ "$(cat "$state_file")" == "$expected" ]] &&
            workspace_bar_state_matches "$expected"; then
            return
          fi
        fi
      fi
    fi
    sleep 0.2
  done

  echo "Expected focused workspace $expected and matching active bar indicator, got '$actual'." >&2
  exit 1
}

for target in 2 3 4 5 6 7 8 9 1; do
  aerospace trigger-binding --mode main "cmd-$target"
  assert_workspace "$target"
done

if [[ "$(aerospace list-workspaces --focused)" != "$original_workspace" ]]; then
  aerospace workspace "$original_workspace"
fi
assert_workspace "$original_workspace"
aerospace focus --window-id "$focused_window_id"

move_target=2
if [[ "$original_workspace" == "$move_target" ]]; then
  move_target=3
fi

aerospace trigger-binding --mode main "cmd-shift-$move_target"
assert_workspace "$move_target"

window_state="$(aerospace list-windows --focused --format '%{window-id} %{workspace}')"
read -r moved_window_id moved_workspace <<< "$window_state"
if [[ "$moved_window_id" != "$focused_window_id" || "$moved_workspace" != "$move_target" ]]; then
  echo "Command+Shift+$move_target did not move and focus the original window." >&2
  exit 1
fi

aerospace move-node-to-workspace --focus-follows-window "$original_workspace"
assert_workspace "$original_workspace"

if [[ "$original_workspace" =~ ^[1-9]$ ]]; then
  next_workspace=$((original_workspace % 9 + 1))
  aerospace trigger-binding --mode main "cmd-ctrl-right"
  assert_workspace "$next_workspace"
  aerospace trigger-binding --mode main "cmd-ctrl-left"
  assert_workspace "$original_workspace"

  aerospace trigger-binding --mode main "cmd-ctrl-right"
  assert_workspace "$next_workspace"
  aerospace trigger-binding --mode main "cmd-ctrl-up"
  assert_workspace "$original_workspace"
  aerospace trigger-binding --mode main "cmd-ctrl-up"
  assert_workspace "$next_workspace"
  aerospace workspace "$original_workspace"
  assert_workspace "$original_workspace"

  empty_workspace=""
  while IFS= read -r workspace; do
    [[ -n "$workspace" ]] || continue
    [[ "$workspace" == "$original_workspace" || "$workspace" == scratch ]] && continue
    if [[ "$(aerospace list-windows --workspace "$workspace" --count)" -eq 0 ]]; then
      empty_workspace="$workspace"
      break
    fi
  done < <(aerospace list-workspaces --all --format '%{workspace}')
  if [[ -z "$empty_workspace" ]]; then
    echo "No empty numbered workspace is available for Command+Control+Down testing." >&2
    exit 1
  fi

  aerospace trigger-binding --mode main "cmd-ctrl-down"
  assert_workspace "$empty_workspace"
  if [[ "$(aerospace list-windows --workspace "$empty_workspace" --count)" -ne 0 ]]; then
    echo "Command+Control+Down did not focus an empty numbered workspace." >&2
    exit 1
  fi
  aerospace workspace "$original_workspace"
  assert_workspace "$original_workspace"
  aerospace focus --window-id "$focused_window_id"

  aerospace trigger-binding --mode main "cmd-ctrl-shift-1"
  assert_workspace "$next_workspace"
  window_state="$(aerospace list-windows --focused --format '%{window-id} %{workspace}')"
  read -r moved_window_id moved_workspace <<< "$window_state"
  if [[ "$moved_window_id" != "$focused_window_id" || "$moved_workspace" != "$next_workspace" ]]; then
    echo "Command+Control+Shift+1 did not move the original window to the next workspace." >&2
    exit 1
  fi

  aerospace trigger-binding --mode main "cmd-ctrl-shift-8"
  assert_workspace "$original_workspace"
  window_state="$(aerospace list-windows --focused --format '%{window-id} %{workspace}')"
  read -r moved_window_id moved_workspace <<< "$window_state"
  if [[ "$moved_window_id" != "$focused_window_id" || "$moved_workspace" != "$original_workspace" ]]; then
    echo "Command+Control+Shift+8 did not return the original window to its workspace." >&2
    exit 1
  fi
fi

echo "AeroSpace numbered, relative, adjacent, empty, and back-and-forth workspace controls passed."

if [[ "$original_workspace" != "scratch" ]]; then
  aerospace trigger-binding --mode main "cmd-alt-ctrl-s"
  assert_workspace "scratch"
  aerospace trigger-binding --mode main "cmd-alt-ctrl-s"
  assert_workspace "$original_workspace"
  aerospace trigger-binding --mode main "cmd-alt-ctrl-0"
  assert_workspace "scratch"
  aerospace workspace "$original_workspace"
  assert_workspace "$original_workspace"
fi

if [[ "$original_workspace" =~ ^[1-9]$ ]]; then
  aerospace workspace 1
  assert_workspace 1
  aerospace trigger-binding --mode main "cmd-ctrl-1"
  assert_workspace 2
  aerospace workspace "$original_workspace"
  assert_workspace "$original_workspace"
fi
