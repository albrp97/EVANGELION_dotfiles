#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$HOME/.homebrew/bin:$HOME/.homebrew/sbin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

workspace="9"
frame_helper="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aerospace-window-frames.swift"
original_workspace="$(aerospace list-workspaces --focused)"
original_window_id="$(aerospace list-windows --focused --format '%{window-id}' || true)"
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/macbook-rice-v2-grid-test.XXXXXX")"
temp_files=()
created_window_ids=()

restore_state() {
  local result=$?
  local window_id
  trap - EXIT

  if [[ "${#created_window_ids[@]}" -gt 0 ]]; then
    for window_id in "${created_window_ids[@]}"; do
      if aerospace list-windows --all --format '%{window-id}' | grep -Fxq "$window_id"; then
        if ! aerospace close --window-id "$window_id"; then
          echo "Could not close grid-test window $window_id." >&2
          result=1
        fi
      fi
    done
  fi

  if [[ "$(aerospace list-workspaces --focused)" != "$original_workspace" ]]; then
    if ! aerospace workspace "$original_workspace"; then
      echo "Could not restore workspace $original_workspace." >&2
      result=1
    fi
  fi
  if [[ -n "$original_window_id" ]]; then
    if ! aerospace focus --window-id "$original_window_id"; then
      echo "Could not restore focused window $original_window_id." >&2
      result=1
    fi
  fi

  if [[ "${#temp_files[@]}" -gt 0 ]]; then
    for temp_file in "${temp_files[@]}"; do
      rm -f "$temp_file"
    done
  fi
  rmdir "$temp_dir" 2>/dev/null || true
  exit "$result"
}
trap restore_state EXIT

if ! command -v aerospace >/dev/null 2>&1; then
  echo "AeroSpace CLI not found." >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 is required for grid frame assertions." >&2
  exit 1
fi
if [[ ! -f "$frame_helper" ]]; then
  echo "Missing visible-window frame helper: $frame_helper" >&2
  exit 1
fi
if aerospace list-windows --all --format '%{app-name}' | grep -Fxq TextEdit; then
  echo "Close existing TextEdit windows before running the AeroSpace grid test." >&2
  exit 1
fi
if [[ "$(aerospace list-windows --workspace "$workspace" --count)" -ne 0 ]]; then
  echo "Workspace $workspace must be empty before running the AeroSpace grid test." >&2
  exit 1
fi

for index in 1 2 3 4 5; do
  temp_file="$temp_dir/window-$index.txt"
  printf 'MacBook Rice v2 grid test window %s\n' "$index" > "$temp_file"
  temp_files+=("$temp_file")
done

window_rows() {
  aerospace list-windows --workspace "$workspace" \
    --format '%{window-id}|%{window-layout}|%{window-parent-container-layout}|%{workspace-root-container-layout}'
}

refresh_created_window_ids() {
  local row
  local window_id
  local layout
  local parent
  local root
  local rows

  rows="$(window_rows)"
  created_window_ids=()
  while IFS='|' read -r window_id layout parent root; do
    [[ -n "$window_id" ]] || continue
    created_window_ids+=("$window_id")
  done <<< "$rows"
}

assert_grid_shape() {
  local expected_count="$1"
  local rows="$2"
  local frames

  frames="$(swift "$frame_helper")" || {
    echo "Could not read window frames for the grid test." >&2
    return 1
  }

  AEROSPACE_GRID_COUNT="$expected_count" \
  AEROSPACE_GRID_ROWS="$rows" \
  AEROSPACE_GRID_FRAMES="$frames" \
  python3 - <<'PY'
import json
import os
import sys

expected_count = int(os.environ["AEROSPACE_GRID_COUNT"])
rows = [line.split("|") for line in os.environ["AEROSPACE_GRID_ROWS"].splitlines() if line]
frames = json.loads(os.environ["AEROSPACE_GRID_FRAMES"])

if len(rows) != expected_count:
    sys.exit(f"Expected {expected_count} tiled windows, got {len(rows)}")
if any(row[1] == "floating" for row in rows):
    sys.exit("A test window was classified as floating")
if any(row[3] != "h_tiles" for row in rows):
    sys.exit("The workspace root is not horizontal")

parent_counts = {
    "h_tiles": sum(row[2] == "h_tiles" for row in rows),
    "v_tiles": sum(row[2] == "v_tiles" for row in rows),
}
expected_parents = {
    1: {"h_tiles": 1, "v_tiles": 0},
    2: {"h_tiles": 2, "v_tiles": 0},
    3: {"h_tiles": 1, "v_tiles": 2},
    4: {"h_tiles": 0, "v_tiles": 4},
    5: {"h_tiles": 1, "v_tiles": 4},
}[expected_count]
if parent_counts != expected_parents:
    sys.exit(f"Unexpected grid tree: {parent_counts}, expected {expected_parents}")

ids = {int(row[0]) for row in rows}
visible = [frame for frame in frames if frame["windowId"] in ids]
if len(visible) != expected_count:
    sys.exit(f"Only {len(visible)} of {expected_count} test windows have visible frames")

def clusters(key, tolerance=20):
    groups = []
    for frame in sorted(visible, key=lambda item: item[key]):
        value = frame[key]
        if not groups or value - groups[-1][-1][key] > tolerance:
            groups.append([frame])
        else:
            groups[-1].append(frame)
    return groups

def close_enough(values, tolerance, label):
    if max(values) - min(values) > tolerance:
        sys.exit(f"{label} are not balanced: {values}")

x_columns = clusters("x")
y_rows = clusters("y")

if expected_count == 1:
    sys.exit(0)

if expected_count == 2:
    if len(x_columns) != 2 or len(y_rows) != 1:
        sys.exit("Two windows are not arranged in a 1:1 side-by-side layout")
    close_enough([column[0]["width"] for column in x_columns], 20, "Column widths")
    close_enough([frame["height"] for frame in visible], 20, "Window heights")
elif expected_count == 3:
    if len(x_columns) != 2 or sorted(len(column) for column in x_columns) != [1, 2]:
        sys.exit("Three windows are not arranged as a 1:2 two-column grid")
    close_enough([column[0]["width"] for column in x_columns], 20, "Column widths")
    stacked_column = next(column for column in x_columns if len(column) == 2)
    full_column = next(column for column in x_columns if len(column) == 1)
    close_enough([frame["height"] for frame in stacked_column], 15, "Stacked row heights")
    stacked_height = sum(frame["height"] for frame in stacked_column)
    if abs(full_column[0]["height"] - stacked_height - 10) > 25:
        sys.exit("The single window does not span the two stacked rows")
elif expected_count == 4:
    if len(x_columns) != 2 or len(y_rows) != 2:
        sys.exit("Four windows are not arranged in a 2:2 grid")
    if any(len(column) != 2 for column in x_columns) or any(len(row) != 2 for row in y_rows):
        sys.exit("The 2:2 grid does not contain one window in each cell")
    close_enough([column[0]["width"] for column in x_columns], 20, "Column widths")
    close_enough([frame["height"] for frame in visible], 15, "Row heights")
elif expected_count == 5:
    if len(x_columns) != 3 or sorted(len(column) for column in x_columns) != [1, 2, 2]:
        sys.exit("Five windows are not arranged as a 2:2:1 three-column grid")
    close_enough([column[0]["width"] for column in x_columns], 20, "Column widths")
    stacked_columns = [column for column in x_columns if len(column) == 2]
    full_column = next(column for column in x_columns if len(column) == 1)
    for column in stacked_columns:
        close_enough([frame["height"] for frame in column], 15, "Stacked row heights")
    stacked_height = sum(frame["height"] for frame in stacked_columns[0]) + 10
    if abs(full_column[0]["height"] - stacked_height) > 25:
        sys.exit("The single window does not span the two stacked rows")

PY
}

wait_for_grid() {
  local expected_count="$1"
  local attempt
  local rows
  local count
  local check_log="$temp_dir/grid-check.log"

  : > "$check_log"

  for ((attempt = 0; attempt < 60; attempt++)); do
    rows="$(window_rows)"
    refresh_created_window_ids
    count="$(awk -F '|' 'NF { count++ } END { print count + 0 }' <<< "$rows")"
    if [[ "$count" -eq "$expected_count" ]]; then
      if assert_grid_shape "$expected_count" "$rows" 2>"$check_log"; then
        if [[ ! -x "$HOME/.local/bin/rice-v2-grid-layout" ]]; then
          echo "Missing installed grid reflow helper: $HOME/.local/bin/rice-v2-grid-layout" >&2
          return 1
        fi
        if AEROSPACE_WORKSPACE="$workspace" "$HOME/.local/bin/rice-v2-grid-layout"; then
          rows="$(window_rows)"
          if assert_grid_shape "$expected_count" "$rows" 2>"$check_log"; then
            return 0
          fi
        fi
      fi
    fi
    sleep 0.1
  done

  echo "AeroSpace did not produce the expected ${expected_count}-window grid." >&2
  if [[ -s "$check_log" ]]; then
    cat "$check_log" >&2
  fi
  window_rows >&2
  return 1
}

aerospace workspace "$workspace"
for index in 1 2 3 4 5; do
  open -a TextEdit "${temp_files[index - 1]}"
  wait_for_grid "$index"
done

echo "AeroSpace automatic grid passed: 1 window, 1:1, 1:2, 2:2, and wider two-row layouts."
