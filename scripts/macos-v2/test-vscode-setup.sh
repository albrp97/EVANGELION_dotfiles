#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
export PATH="$HOME/.local/bin:$HOME/.homebrew/bin:$HOME/.homebrew/sbin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

app_path="$HOME/Applications/Visual Studio Code.app"
if [[ ! -d "$app_path" ]]; then
  app_path="/Applications/Visual Studio Code.app"
fi
if [[ ! -d "$app_path" ]]; then
  echo "Visual Studio Code is missing. Run scripts/macos-v2/bootstrap-tools.sh." >&2
  exit 1
fi
app_out="$app_path/Contents/Resources/app/out"
workbench_html="$app_out/vs/code/electron-browser/workbench/workbench.html"
background_css="$app_out/vs/workbench/macbook-linux-rice-vscode-background.css"
background_image="$app_out/vs/workbench/macbook-linux-rice-vscode-bg.png"
if ! command -v code >/dev/null 2>&1; then
  echo "The VS Code 'code' CLI is missing. Run scripts/macos-v2/bootstrap-tools.sh." >&2
  exit 1
fi
if [[ ! -f "$workbench_html" ]] ||
  ! grep -Fq 'macbook-linux-rice-vscode-background.css' "$workbench_html" ||
  [[ ! -f "$background_css" ]] ||
  ! grep -Fq 'url("./macbook-linux-rice-vscode-bg.png")' "$background_css" ||
  [[ ! -s "$background_image" ]]; then
  echo "The EVA wallpaper background is not installed in the VS Code app bundle. Run scripts/macos-v2/install-desktop.sh." >&2
  exit 1
fi

settings_source="$ROOT_DIR/dotfiles/macos/Library/Application Support/Code/User/settings.json"
settings_target="$HOME/Library/Application Support/Code/User/settings.json"
keybindings_source="$ROOT_DIR/dotfiles/macos/Library/Application Support/Code/User/keybindings.json"
keybindings_target="$HOME/Library/Application Support/Code/User/keybindings.json"
extension_dir="$HOME/.vscode/extensions/macbook-linux-rice-eva01-pastel-0.1.0"
karabiner_config="$HOME/.config/karabiner/karabiner.json"

if [[ ! -f "$settings_target" ]] ||
  ! cmp -s "$settings_source" "$settings_target"; then
  echo "The installed VS Code settings differ from the tracked Mac rice settings. Run scripts/macos-v2/install-desktop.sh." >&2
  exit 1
fi
if [[ ! -f "$keybindings_target" ]] ||
  ! cmp -s "$keybindings_source" "$keybindings_target"; then
  echo "The installed VS Code keybindings differ from the tracked Mac rice keybindings. Run scripts/macos-v2/install-desktop.sh." >&2
  exit 1
fi
if [[ ! -f "$extension_dir/package.json" ||
  ! -f "$extension_dir/themes/eva01-pastel-color-theme.json" ||
  ! -f "$extension_dir/icons/eva01-pastel-icon-theme.json" ]]; then
  echo "The EVA-01 VS Code theme extension is incomplete. Run scripts/macos-v2/install-desktop.sh." >&2
  exit 1
fi

code --version >/dev/null
if ! code --list-extensions | grep -Fxq "macbook-linux-rice.macbook-linux-rice-eva01-pastel"; then
  echo "VS Code did not discover the locally installed EVA-01 extension." >&2
  exit 1
fi

python3 - "$settings_target" "$extension_dir" "$karabiner_config" "$keybindings_target" <<'PY'
import json
import sys
from pathlib import Path

settings_path, extension_path, karabiner_path, keybindings_path = map(Path, sys.argv[1:])
settings = json.loads(settings_path.read_text(encoding="utf-8"))
keybindings = json.loads(keybindings_path.read_text(encoding="utf-8"))
extension_path = extension_path.resolve()
extension = json.loads((extension_path / "package.json").read_text(encoding="utf-8"))
color_theme = settings.get("workbench.colorTheme")
icon_theme = settings.get("workbench.iconTheme")
if color_theme != "EVA-01 Pastel" or icon_theme != "eva01-pastel-icons":
    sys.exit("VS Code is not configured to use the EVA-01 color and icon themes.")
if not any(theme.get("label") == color_theme for theme in extension["contributes"]["themes"]):
    sys.exit("The configured EVA-01 color theme is missing from the extension.")
if not any(theme.get("id") == icon_theme for theme in extension["contributes"]["iconThemes"]):
    sys.exit("The configured EVA-01 icon theme is missing from the extension.")
if not settings.get("editor.fontFamily", "").startswith("Liga SFMono Nerd Font"):
    sys.exit("VS Code is not configured to use the rice's Nerd Font.")

expected_keybindings = {
    "cmd+,": "workbench.action.toggleSidebarVisibility",
    "cmd+/": "workbench.action.toggleAuxiliaryBar",
    "cmd+.": "workbench.action.toggleStatusbarVisibility",
}
for key, command in expected_keybindings.items():
    matching = [item for item in keybindings if item.get("key") == key]
    if len(matching) != 1 or matching[0].get("command") != command:
        sys.exit(f"VS Code shortcut '{key}' is not bound to {command}.")

config = json.loads(karabiner_path.read_text(encoding="utf-8"))
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
        if item.get("from", {}).get("key_code") == "v"
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
    action.get("shell_command") == "/usr/bin/open -a 'Visual Studio Code'"
    for action in launch.get("to", [])
):
    sys.exit("Command+Space, then V is not bound to Visual Studio Code.")
PY

if ! grep -Fqx \
  'cmd-alt-ctrl-v = '\''exec-and-forget /usr/bin/open -a "Visual Studio Code"'\''' \
  "$HOME/.aerospace.toml"; then
  echo "HyprMod+V is not bound to Visual Studio Code in the installed AeroSpace config." >&2
  exit 1
fi

/usr/bin/open -a "$app_path" --args --new-window
running=false
for _ in {1..50}; do
  if [[ "$(/usr/bin/osascript -e 'application "Visual Studio Code" is running' 2>/dev/null || true)" == "true" ]]; then
    running=true
    break
  fi
  sleep 0.1
done
if [[ "$running" != true ]]; then
  echo "The Visual Studio Code app did not start." >&2
  exit 1
fi

echo "VS Code functionality passed: app launch, wallpaper background, Nerd Font settings, EVA themes, Command+Space+V, HyprMod+V, and primary, secondary, and status-bar shortcuts."
