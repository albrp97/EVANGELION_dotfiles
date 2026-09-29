#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$HOME/.homebrew/bin:$HOME/.homebrew/sbin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

zen_app="$HOME/Applications/Zen.app"
if [[ ! -d "$zen_app" ]]; then
  zen_app="/Applications/Zen.app"
fi
if [[ ! -d "$zen_app" ]]; then
  echo "Zen is missing. Run scripts/macos-v2/bootstrap-tools.sh." >&2
  exit 1
fi

karabiner_config="$HOME/.config/karabiner/karabiner.json"
if [[ ! -f "$karabiner_config" ]]; then
  echo "Karabiner's active configuration is missing. Run scripts/macos-v2/install-desktop.sh." >&2
  exit 1
fi

python3 - "$karabiner_config" <<'PY'
import json
import sys
from pathlib import Path

config = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
selected = [profile for profile in config.get("profiles", []) if profile.get("selected") is True]
if len(selected) != 1:
    sys.exit("Karabiner must have exactly one selected profile.")
rules = selected[0].get("complex_modifications", {}).get("rules", [])
rule = next(
    (
        item for item in rules
        if item.get("description") == "MacBook Rice v2: Command+Space launcher actions"
    ),
    None,
)
if rule is None:
    sys.exit("The selected Karabiner profile has no Command+Space launcher rule.")
launch = next(
    (
        item for item in rule.get("manipulators", [])
        if item.get("from", {}).get("key_code") == "z"
        and any(
            condition.get("type") == "variable_if"
            and condition.get("name") == "rice_v2_launcher"
            and condition.get("value") == 1
            for condition in item.get("conditions", [])
        )
    ),
    None,
)
if launch is None or not any(
    action.get("shell_command") == "/usr/bin/open -a Zen"
    for action in launch.get("to", [])
):
    sys.exit("Command+Space, then Z is not bound to Zen.")
if not any(
    action.get("set_variable", {}).get("name") == "rice_v2_launcher"
    and action.get("set_variable", {}).get("value") == 0
    for action in launch.get("to", [])
):
    sys.exit("The Zen launcher shortcut does not reset launcher mode.")
PY

for binding in \
  "cmd-alt-ctrl-z = 'exec-and-forget /usr/bin/open -a Zen'" \
  "cmd-alt-ctrl-w = 'exec-and-forget /usr/bin/open -a Zen'"; do
  if ! grep -Fqx "$binding" "$HOME/.aerospace.toml"; then
    echo "The installed AeroSpace config is missing browser binding: $binding" >&2
    exit 1
  fi
done

/usr/bin/open -a "$zen_app"
running=false
for _ in {1..50}; do
  if [[ "$(/usr/bin/osascript -e 'application "Zen" is running' 2>/dev/null || true)" == "true" ]]; then
    running=true
    break
  fi
  sleep 0.1
done
if [[ "$running" != true ]]; then
  echo "The Zen browser did not start." >&2
  exit 1
fi

echo "Zen functionality passed: browser launch, Command+Space+Z, and HyprMod browser bindings."
