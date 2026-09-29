#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$HOME/.homebrew/bin:$HOME/.homebrew/sbin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

if ! command -v yabai >/dev/null 2>&1; then
  echo "Yabai is missing. Run scripts/macos-v2/bootstrap-tools.sh." >&2
  exit 1
fi
if ! pgrep -x yabai >/dev/null 2>&1; then
  echo "Yabai is not running. Run scripts/macos-v2/install-desktop.sh." >&2
  exit 1
fi

if ! windows_json="$(yabai -m query --windows 2>&1)"; then
  echo "Yabai cannot query windows. Grant it Accessibility permission." >&2
  printf '%s\n' "$windows_json" >&2
  exit 1
fi

YABAI_WINDOWS_JSON="$windows_json" python3 - <<'PY'
import json
import os
import sys

try:
    windows = json.loads(os.environ["YABAI_WINDOWS_JSON"])
except json.JSONDecodeError as error:
    sys.exit(f"Yabai returned invalid window data: {error}")

if not windows:
    sys.exit("Yabai sees no windows; verify its Accessibility permission.")
PY

focus_mode="$(yabai -m config focus_follows_mouse)"
mouse_mode="$(yabai -m config mouse_follows_focus)"
layout="$(yabai -m config layout)"

if [[ "$focus_mode" != "autofocus" ]]; then
  echo "Expected focus_follows_mouse=autofocus, got '$focus_mode'." >&2
  exit 1
fi
if [[ "$mouse_mode" != "on" ]]; then
  echo "Expected mouse_follows_focus=on, got '$mouse_mode'." >&2
  exit 1
fi
if [[ "$layout" != "float" ]]; then
  echo "Yabai must remain in float layout so it does not compete with AeroSpace; got '$layout'." >&2
  exit 1
fi

echo "Yabai hover-focus and focus-follows-mouse are enabled; AeroSpace remains the tiling manager."
