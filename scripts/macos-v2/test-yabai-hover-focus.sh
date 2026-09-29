#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

export PATH="$HOME/.local/bin:$HOME/.homebrew/bin:$HOME/.homebrew/sbin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

source_config="$ROOT_DIR/dotfiles/macos-v2/.yabairc"
active_config="$HOME/.yabairc"
launch_agent="$HOME/Library/LaunchAgents/com.asmvik.yabai.plist"

if ! command -v yabai >/dev/null 2>&1; then
  echo "Yabai is missing. Run scripts/macos-v2/bootstrap-tools.sh." >&2
  exit 1
fi
if ! cmp -s "$source_config" "$active_config"; then
  echo "The installed Yabai config differs from the persistent MacBook Rice v2 config. Run scripts/macos-v2/install-desktop.sh." >&2
  exit 1
fi
if [[ ! -f "$launch_agent" ]] ||
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :RunAtLoad' "$launch_agent" 2>/dev/null || true)" != true ]]; then
  echo "Yabai is not configured to start at login. Run scripts/macos-v2/install-desktop.sh." >&2
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

if [[ "$focus_mode" != "autoraise" ]]; then
  echo "Expected focus_follows_mouse=autoraise, got '$focus_mode'." >&2
  exit 1
fi
if [[ "$mouse_mode" != "off" ]]; then
  echo "Expected mouse_follows_focus=off, got '$mouse_mode'." >&2
  exit 1
fi
if [[ "$layout" != "float" ]]; then
  echo "Yabai must remain in float layout so it does not compete with AeroSpace; got '$layout'." >&2
  exit 1
fi

echo "Yabai focus-follows-mouse autoraises hovered windows; its login service and persistent config are verified, while AeroSpace remains the tiling manager."
