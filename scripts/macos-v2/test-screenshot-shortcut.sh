#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

export PATH="$HOME/.local/bin:$HOME/.homebrew/bin:$HOME/.homebrew/sbin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

if [[ "$#" -gt 1 || ( "$#" -eq 1 && "$1" != "--config-only" ) ]]; then
  echo "usage: $0 [--config-only]" >&2
  exit 2
fi

helper="$HOME/.local/bin/rice-v2-region-screenshot"
config="$HOME/.config/karabiner/karabiner.json"
karabiner_cli="$(command -v karabiner_cli 2>/dev/null || true)"
if [[ -z "$karabiner_cli" && -x "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli" ]]; then
  karabiner_cli="/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"
fi
if [[ ! -x "$helper" ]]; then
  echo "The region screenshot helper is missing. Run scripts/macos-v2/install-desktop.sh." >&2
  exit 1
fi
if [[ -z "$karabiner_cli" ]]; then
  echo "Karabiner-Elements is not installed. Run scripts/macos-v2/bootstrap-tools.sh." >&2
  exit 1
fi
if [[ ! -f "$config" ]]; then
  echo "Karabiner's active configuration is missing. Run scripts/macos-v2/install-desktop.sh." >&2
  exit 1
fi

configured_profile="$(python3 - "$config" <<'PY'
import json
import plistlib
import sys
from pathlib import Path

config = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
selected = [
    profile for profile in config.get("profiles", [])
    if profile.get("selected") is True
]
if len(selected) != 1:
    sys.exit("Karabiner must have exactly one selected profile.")
print(selected[0].get("name", ""))
rules = (selected[0].get("complex_modifications") or {}).get("rules", [])
rule = next(
    (
        item
        for item in rules
        if item.get("description")
        == "MacBook Rice v2: Command+Space launcher actions"
    ),
    None,
)
if rule is None:
    sys.exit("The selected Karabiner profile has no Command+Space launcher rule.")
manipulators = rule.get("manipulators", [])

def launcher_actions(key_code):
    return [
        item
        for item in manipulators
        if item.get("from", {}).get("key_code") == key_code
        and any(
            condition.get("type") == "variable_if"
            and condition.get("name") == "rice_v2_launcher"
            and condition.get("value") == 1
            for condition in item.get("conditions", [])
        )
    ]


expected_actions = {
    "spacebar": "open -a Raycast",
    "t": "rice-v2-open-terminal",
    "return_or_enter": "rice-v2-open-terminal",
    "e": "rice-v2-open-yazi",
    "y": "rice-v2-open-fastfetch-console",
    "z": "open -a Zen",
    "v": "open -a 'Visual Studio Code'",
    "r": "open -a 'Activity Monitor'",
    "s": "rice-v2-region-screenshot",
    "p": "rice-v2-region-screenshot",
}
for key_code, expected_command in expected_actions.items():
    actions = launcher_actions(key_code)
    if not actions or not any(
        expected_command in action.get("shell_command", "")
        for item in actions
        for action in item.get("to", [])
    ):
        sys.exit(f"Launcher key '{key_code}' is not bound to {expected_command}.")
    if not any(
        action.get("set_variable", {}).get("name") == "rice_v2_launcher"
        and action.get("set_variable", {}).get("value") == 0
        for item in actions
        for action in item.get("to", [])
    ):
        sys.exit(f"Launcher key '{key_code}' does not reset launcher mode.")

space_rule = next(
    (
        item
        for item in manipulators
        if item.get("from", {}).get("key_code") == "spacebar"
        and item.get("from", {}).get("modifiers", {}).get("mandatory") == ["command"]
    ),
    None,
)
capture_rule = next(iter(launcher_actions("p")), None)
cancel_rule = next(iter(launcher_actions("escape")), None)
if space_rule is None or space_rule.get("parameters", {}).get(
    "basic.to_delayed_action_delay_milliseconds"
) != 1500:
    sys.exit("Command+Space is not configured as the 1.5-second launcher leader.")
if capture_rule is None or not any(
    "rice-v2-region-screenshot" in action.get("shell_command", "")
    for action in capture_rule.get("to", [])
):
    sys.exit("Launcher P is not bound to the region screenshot helper.")
if cancel_rule is None:
    sys.exit("Escape is not configured to cancel launcher mode.")

screenshot_blocker = next(
    (
        item
        for item in manipulators
        if item.get("from", {}).get("key_code") == "3"
        and item.get("from", {}).get("modifiers", {}).get("mandatory")
        == ["command", "shift"]
    ),
    None,
)
if (
    screenshot_blocker is None
    or screenshot_blocker.get("conditions")
    or screenshot_blocker.get("to") != [{"key_code": "vk_none"}]
):
    sys.exit("Command+Shift+3 is not consumed by Karabiner.")

preferences = Path.home() / "Library/Preferences/com.apple.symbolichotkeys.plist"
try:
    hotkeys = plistlib.loads(preferences.read_bytes()).get("AppleSymbolicHotKeys", {})
except FileNotFoundError:
    sys.exit("The macOS keyboard shortcut preferences are missing.")

spotlight = hotkeys.get("64")
if not isinstance(spotlight, dict) or spotlight.get("enabled") is not False:
    sys.exit("Spotlight still owns Command+Space.")

for shortcut_id in ("28", "29", "30", "31", "184"):
    shortcut = hotkeys.get(shortcut_id)
    if not isinstance(shortcut, dict) or shortcut.get("enabled") is not False:
        sys.exit(f"macOS screenshot hotkey {shortcut_id} is still enabled.")
    value = shortcut.get("value")
    parameters = value.get("parameters") if isinstance(value, dict) else None
    if (
        not isinstance(value, dict)
        or value.get("type") != "standard"
        or not isinstance(parameters, list)
        or any(type(item) is not int for item in parameters)
    ):
        sys.exit(f"macOS screenshot hotkey {shortcut_id} has invalid plist types.")
PY
)"

if ! current_profile="$("$karabiner_cli" --show-current-profile-name 2>&1)"; then
  echo "Karabiner-Elements is not responding: $current_profile" >&2
  exit 1
fi
if [[ "$current_profile" != "$configured_profile" ]]; then
  echo "Karabiner is using '$current_profile' instead of '$configured_profile'." >&2
  exit 1
fi
if ! "$karabiner_cli" --list-connected-devices >/dev/null 2>&1; then
  echo "Karabiner cannot access keyboard devices; approve its macOS permissions." >&2
  exit 1
fi
if ! "$karabiner_cli" --lint-complex-modifications \
  "$HOME/.config/karabiner/assets/complex_modifications/command-space-region-screenshot.json" \
  >/dev/null; then
  echo "Karabiner rejected the Command+Space launcher rule." >&2
  exit 1
fi

settings_json="$("$karabiner_cli" --show-settings-window-guidance)"
KARABINER_SETTINGS_JSON="$settings_json" python3 - <<'PY'
import json
import os
import sys

settings = json.loads(os.environ["KARABINER_SETTINGS_JSON"])
core = settings.get("core_service_daemon_state") or {}
permissions = core.get("current_process_permission_check_result") or {}
if (
    settings.get("current_alert") != "none"
    or not core.get("driver_activated")
    or not core.get("virtual_hid_keyboard_ready")
    or not permissions.get("accessibility_process_trusted")
    or not permissions.get("iohid_listen_event_allowed")
    or core.get("karabiner_json_parse_error_message")
):
    sys.exit("Karabiner's driver, permissions, or selected profile is not ready.")
PY

if [[ "${1:-}" == "--config-only" ]]; then
  echo "Screenshot shortcut settings passed: Command+Space P remains configured, native screenshot hotkeys are disabled, and Karabiner consumes Command+Shift+3."
  exit 0
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "Swift is required to automate the mouse selection test." >&2
  exit 1
fi
if ! swift "$ROOT_DIR/scripts/macos-v2/test-screenshot-shortcut.swift" "$helper"; then
  echo "Interactive region selection or clipboard verification failed." >&2
  exit 1
fi

echo "Karabiner launcher configuration and interactive screenshot capture passed."
