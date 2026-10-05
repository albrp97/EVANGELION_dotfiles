#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOTFILES_DIR="$ROOT_DIR/dotfiles/macos-v2"
COMMON_YAZI_DIR="$ROOT_DIR/dotfiles/common/.config/yazi"
COMMON_STARSHIP_CONFIG="$ROOT_DIR/dotfiles/common/.config/starship.toml"
COMMON_FASTFETCH_LOGO="$ROOT_DIR/dotfiles/common/.config/fastfetch/eva01-logo.txt"
COMMON_HUSHLOGIN="$ROOT_DIR/dotfiles/common/.hushlogin"
VSCODE_SETTINGS_SOURCE="$ROOT_DIR/dotfiles/macos/Library/Application Support/Code/User/settings.json"
VSCODE_KEYBINDINGS_SOURCE="$ROOT_DIR/dotfiles/macos/Library/Application Support/Code/User/keybindings.json"
VSCODE_EXTENSION_SOURCE="$ROOT_DIR/dotfiles/common/.vscode/extensions/macbook-linux-rice-eva01-pastel-0.1.0"
BACKUP_DIR="$HOME/.macbook-rice-v2-backup/desktop-$(date +%Y%m%d-%H%M%S)"
WALLPAPER_DIR="$HOME/.local/share/macbook-rice-v2/wallpapers"
backup_count=0

export PATH="$HOME/.local/bin:$HOME/.homebrew/bin:$HOME/.homebrew/sbin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script only supports macOS." >&2
  exit 1
fi

if [[ ! -d "$DOTFILES_DIR" ]]; then
  echo "Missing v2 dotfiles directory: $DOTFILES_DIR" >&2
  exit 1
fi

if ! bash "$ROOT_DIR/scripts/macos-v2/disable-legacy-skhd.sh"; then
  echo "Could not disable the legacy skhd shortcut service before applying v2." >&2
  exit 1
fi

backup_target() {
  local target_path="$1"
  local relative_path="$2"
  local backup_path="$BACKUP_DIR/$relative_path"

  if [[ ! -e "$target_path" && ! -L "$target_path" ]]; then
    return
  fi

  if [[ -e "$backup_path" || -L "$backup_path" ]]; then
    return
  fi

  if [[ -d "$target_path" && ! -L "$target_path" ]]; then
    echo "Cannot replace a directory with a file: $target_path" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$backup_path")"
  cp -Pp "$target_path" "$backup_path"
  backup_count=$((backup_count + 1))
}

install_file() {
  local source_path="$1"
  local relative_path="$2"
  local target_path="$HOME/$relative_path"
  local temp_path

  if [[ -e "$target_path" || -L "$target_path" ]]; then
    if [[ -f "$target_path" && ! -L "$target_path" ]] && cmp -s "$source_path" "$target_path"; then
      return
    fi
    backup_target "$target_path" "$relative_path"
  fi

  mkdir -p "$(dirname "$target_path")"
  temp_path="$(mktemp "${target_path}.tmp.XXXXXX")"
  cp -p "$source_path" "$temp_path"
  mv -f "$temp_path" "$target_path"
}

fish_binary="$(command -v fish || true)"
if [[ -z "$fish_binary" ]]; then
  echo "Fish is missing. Run scripts/macos-v2/bootstrap-tools.sh first." >&2
  exit 1
fi

ghostty_config_source="$DOTFILES_DIR/.config/ghostty/config.in"
if [[ ! -f "$ghostty_config_source" ]]; then
  echo "Missing Ghostty configuration template: $ghostty_config_source" >&2
  exit 1
fi
ghostty_config_temp="$(mktemp "${TMPDIR:-/tmp}/macbook-rice-v2-ghostty.XXXXXX")"
if ! sed "s|@RICE_V2_FISH_BINARY@|$fish_binary|g" \
  "$ghostty_config_source" >"$ghostty_config_temp"; then
  rm -f "$ghostty_config_temp"
  echo "Could not generate the Ghostty Fish command configuration." >&2
  exit 1
fi
if grep -Fq "@RICE_V2_FISH_BINARY@" "$ghostty_config_temp"; then
  rm -f "$ghostty_config_temp"
  echo "The Ghostty configuration still contains an unresolved command path." >&2
  exit 1
fi
install_file "$ghostty_config_temp" ".config/ghostty/config"
rm -f "$ghostty_config_temp"

if [[ ! -d "$COMMON_YAZI_DIR" || ! -f "$COMMON_STARSHIP_CONFIG" || ! -f "$COMMON_FASTFETCH_LOGO" ]]; then
  echo "Missing shared Starship, Fastfetch, or Yazi configuration sources." >&2
  exit 1
fi
if [[ ! -f "$COMMON_YAZI_DIR/plugins/video-info.yazi/main.lua" ]]; then
  echo "Missing the shared Yazi video-info plugin source." >&2
  exit 1
fi
if [[ ! -f "$COMMON_HUSHLOGIN" ]]; then
  echo "Missing shared login-banner suppression marker: $COMMON_HUSHLOGIN" >&2
  exit 1
fi
if [[ ! -f "$VSCODE_SETTINGS_SOURCE" ||
  ! -f "$VSCODE_KEYBINDINGS_SOURCE" ||
  ! -f "$VSCODE_EXTENSION_SOURCE/package.json" ||
  ! -f "$VSCODE_EXTENSION_SOURCE/themes/eva01-pastel-color-theme.json" ||
  ! -f "$VSCODE_EXTENSION_SOURCE/icons/eva01-pastel-icon-theme.json" ]]; then
  echo "Missing the legacy VS Code settings, keybindings, or shared EVA theme sources." >&2
  exit 1
fi
if ! command -v code >/dev/null 2>&1; then
  echo "Visual Studio Code's 'code' CLI is missing. Run scripts/macos-v2/bootstrap-tools.sh first." >&2
  exit 1
fi
if [[ ! -d "$HOME/Applications/Visual Studio Code.app" &&
  ! -d "/Applications/Visual Studio Code.app" ]]; then
  echo "Visual Studio Code.app is missing. Run scripts/macos-v2/bootstrap-tools.sh first." >&2
  exit 1
fi
if [[ ! -d "$HOME/Applications/Zen.app" && ! -d "/Applications/Zen.app" ]]; then
  echo "Zen.app is missing. Run scripts/macos-v2/bootstrap-tools.sh first." >&2
  exit 1
fi

while IFS= read -r -d '' source_path; do
  relative_path="${source_path#"$COMMON_YAZI_DIR"/}"
  install_file "$source_path" ".config/yazi/$relative_path"
done < <(find "$COMMON_YAZI_DIR" -type f -print0)
install_file "$COMMON_STARSHIP_CONFIG" ".config/starship.toml"
install_file "$COMMON_FASTFETCH_LOGO" ".config/fastfetch/eva01-logo.txt"
install_file "$COMMON_HUSHLOGIN" ".hushlogin"
install_file "$VSCODE_SETTINGS_SOURCE" "Library/Application Support/Code/User/settings.json"
install_file "$VSCODE_KEYBINDINGS_SOURCE" "Library/Application Support/Code/User/keybindings.json"
while IFS= read -r -d '' source_path; do
  relative_path="${source_path#"$VSCODE_EXTENSION_SOURCE"/}"
  install_file "$source_path" ".vscode/extensions/macbook-linux-rice-eva01-pastel-0.1.0/$relative_path"
done < <(find "$VSCODE_EXTENSION_SOURCE" -type f -print0)

vscode_app="$HOME/Applications/Visual Studio Code.app"
if [[ ! -d "$vscode_app" ]]; then
  vscode_app="/Applications/Visual Studio Code.app"
fi
vscode_app_out="$vscode_app/Contents/Resources/app/out"
vscode_workbench_html="$vscode_app_out/vs/code/electron-browser/workbench/workbench.html"
vscode_background_css="$vscode_app_out/vs/workbench/macbook-linux-rice-vscode-background.css"
vscode_background_image="$vscode_app_out/vs/workbench/macbook-linux-rice-vscode-bg.png"
vscode_background_source="$ROOT_DIR/dotfiles/macos/.vscode/macbook-linux-rice-vscode-bg.png"
vscode_background_wallpaper="$ROOT_DIR/wallpapers/09.jpg"
vscode_background_current=false
if [[ -f "$vscode_workbench_html" &&
  -f "$vscode_background_css" &&
  -f "$vscode_background_image" &&
  -f "$vscode_background_source" &&
  -f "$vscode_background_wallpaper" ]] &&
  grep -Fq 'macbook-linux-rice-vscode-background.css' "$vscode_workbench_html" &&
  grep -Fq 'rice-editor: rgba(15, 16, 32, 0.66)' "$vscode_background_css" &&
  ! [[ "$vscode_background_wallpaper" -nt "$vscode_background_source" ]] &&
  cmp -s "$vscode_background_source" "$vscode_background_image"; then
  vscode_background_current=true
fi
if [[ "$vscode_background_current" != true ]]; then
  if ! VSCODE_APP="$vscode_app" \
    "$ROOT_DIR/scripts/apply-vscode-background.sh" "$vscode_background_wallpaper"; then
    echo "Could not apply the EVA wallpaper background to VS Code." >&2
    exit 1
  fi
fi

while IFS= read -r -d '' source_path; do
  relative_path="${source_path#"$DOTFILES_DIR"/}"
  if [[ "$relative_path" == ".config/ghostty/config.in" ]]; then
    continue
  fi
  install_file "$source_path" "$relative_path"
done < <(find "$DOTFILES_DIR" -type f -print0)

mkdir -p "$WALLPAPER_DIR"
while IFS= read -r -d '' source_path; do
  relative_path=".local/share/macbook-rice-v2/wallpapers/$(basename "$source_path")"
  install_file "$source_path" "$relative_path"
done < <(
  find "$ROOT_DIR/wallpapers" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
    -print0
)

if ! command -v ya >/dev/null 2>&1; then
  echo "Yazi's 'ya' package manager is missing. Run scripts/macos-v2/bootstrap-tools.sh first." >&2
  exit 1
fi
ya pkg install

mkdir -p "$HOME/.local/bin"
temp_binary="$(mktemp "$HOME/.local/bin/rice-v2-set-wallpaper.XXXXXX")"
if ! /usr/bin/xcrun swiftc -parse-as-library -O \
  -o "$temp_binary" \
  "$ROOT_DIR/scripts/macos-v2/set-wallpaper.swift"; then
  rm -f "$temp_binary"
  echo "Could not build the native wallpaper helper." >&2
  exit 1
fi

binary_target="$HOME/.local/bin/rice-v2-set-wallpaper"
if [[ -e "$binary_target" || -L "$binary_target" ]]; then
  backup_target "$binary_target" ".local/bin/rice-v2-set-wallpaper"
fi
chmod u+x "$temp_binary"
mv -f "$temp_binary" "$binary_target"

window_frames_target="$HOME/.local/bin/rice-v2-window-frames"
temp_window_frames_binary="$(mktemp "$HOME/.local/bin/rice-v2-window-frames.XXXXXX")"
if ! /usr/bin/xcrun swiftc -O \
  -o "$temp_window_frames_binary" \
  "$ROOT_DIR/scripts/macos-v2/aerospace-window-frames.swift"; then
  rm -f "$temp_window_frames_binary"
  echo "Could not build the AeroSpace window-frame helper." >&2
  exit 1
fi
if [[ -e "$window_frames_target" || -L "$window_frames_target" ]]; then
  backup_target "$window_frames_target" ".local/bin/rice-v2-window-frames"
fi
chmod u+x "$temp_window_frames_binary"
mv -f "$temp_window_frames_binary" "$window_frames_target"

chmod u+x \
  "$HOME/.local/bin/az" \
  "$HOME/.local/bin/rice-v2-random-wallpaper" \
  "$HOME/.local/bin/rice-v2-grid-layout" \
  "$HOME/.local/bin/rice-v2-workspace-empty" \
  "$HOME/.local/bin/rice-v2-workspace-offset" \
  "$HOME/.local/bin/rice-v2-toggle-scratch" \
  "$HOME/.local/bin/rice-v2-start-borders" \
  "$HOME/.local/bin/rice-v2-start-desktop" \
  "$HOME/.local/bin/rice-v2-open-terminal" \
  "$HOME/.local/bin/rice-v2-new-ghostty-window" \
  "$HOME/.local/bin/rice-v2-send-ghostty-command" \
  "$HOME/.local/bin/rice-v2-open-yazi" \
  "$HOME/.local/bin/rice-v2-open-fastfetch-console" \
  "$HOME/.local/bin/rice-v2-fastfetch-console" \
  "$HOME/.local/bin/rice-v2-power-menu" \
  "$HOME/.local/bin/rice-v2-yazi-extract" \
  "$HOME/.local/bin/rice-v2-yazi-compress" \
  "$HOME/.local/bin/rice-v2-open-command-file" \
  "$HOME/.local/bin/rice-v2-region-screenshot" \
  "$HOME/.local/bin/rice-v2-fastfetch-info" \
  "$HOME/.local/bin/rice-v2-workspace" \
  "$HOME/.local/bin/rice-v2-workspace-changed" \
  "$HOME/.config/macbook-rice-v2/sketchybar/sketchybarrc" \
  "$HOME/.config/macbook-rice-v2/sketchybar/colors.sh" \
  "$HOME/.config/macbook-rice-v2/sketchybar/plugins/"*.sh

install_command_file_handler() (
  set -euo pipefail

  local bundle_id="com.macbook-rice-v2.command-file-opener"
  local app_path="$HOME/Applications/MacBook Rice V2 Command File Opener.app"
  local source_path="$ROOT_DIR/scripts/macos-v2/command-file-opener.applescript"
  local build_dir
  local build_app
  local info_plist
  local existing_bundle_id
  local handler_info
  local lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

  if ! command -v duti >/dev/null 2>&1; then
    echo "duti is missing. Run scripts/macos-v2/bootstrap-tools.sh first." >&2
    exit 1
  fi
  if [[ ! -f "$source_path" ]]; then
    echo "Missing Ghostty command-file handler source: $source_path" >&2
    exit 1
  fi

  mkdir -p "$HOME/Applications"
  build_dir="$(mktemp -d "$HOME/Applications/.macbook-rice-v2-command-opener.XXXXXX")"
  trap 'rm -rf "$build_dir"' EXIT
  build_app="$build_dir/MacBook Rice V2 Command File Opener.app"

  if ! /usr/bin/osacompile -x -o "$build_app" "$source_path"; then
    echo "Could not build the Ghostty command-file handler app." >&2
    exit 1
  fi

  info_plist="$build_app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" "$info_plist" 2>/dev/null ||
    /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $bundle_id" "$info_plist"
  if /usr/libexec/PlistBuddy -c 'Print :CFBundleDocumentTypes' "$info_plist" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c 'Delete :CFBundleDocumentTypes' "$info_plist"
  fi
  /usr/libexec/PlistBuddy -c 'Add :CFBundleDocumentTypes array' "$info_plist"
  /usr/libexec/PlistBuddy -c 'Add :CFBundleDocumentTypes:0 dict' "$info_plist"
  /usr/libexec/PlistBuddy -c 'Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions array' "$info_plist"
  /usr/libexec/PlistBuddy -c 'Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions:0 string command' "$info_plist"
  /usr/libexec/PlistBuddy -c 'Add :CFBundleDocumentTypes:0:CFBundleTypeName string Shell Command' "$info_plist"
  /usr/libexec/PlistBuddy -c 'Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Shell' "$info_plist"
  /usr/libexec/PlistBuddy -c 'Add :CFBundleDocumentTypes:0:LSHandlerRank string Owner' "$info_plist"

  if [[ -L "$app_path" ]]; then
    echo "Refusing to replace a symlink at $app_path" >&2
    exit 1
  elif [[ -e "$app_path" ]]; then
    existing_bundle_id="$(
      /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist" 2>/dev/null ||
        true
    )"
    if [[ "$existing_bundle_id" != "$bundle_id" ]]; then
      echo "Refusing to replace an unrelated application at $app_path" >&2
      exit 1
    fi
  fi

  /usr/bin/ditto "$build_app" "$app_path"
  if [[ -x "$lsregister" ]]; then
    "$lsregister" -f "$app_path"
  fi
  duti -s "$bundle_id" .command all

  handler_info="$(duti -x .command)"
  if [[ "$handler_info" != *"$bundle_id"* ]]; then
    echo "The .command file default was not assigned to the v2 Ghostty handler." >&2
    exit 1
  fi

  echo "Registered .command files to run in Ghostty."
)

install_command_file_handler

if ! command -v yabai >/dev/null 2>&1; then
  echo "Yabai is missing. Run scripts/macos-v2/bootstrap-tools.sh first." >&2
  exit 1
fi
if pgrep -x yabai >/dev/null 2>&1; then
  if ! yabai --restart-service; then
    echo "Could not restart the v2 Yabai focus service." >&2
    exit 1
  fi
else
  if ! yabai --start-service; then
    echo "Could not start the v2 Yabai focus service." >&2
    exit 1
  fi
fi

yabai_ready=false
for ((attempt = 0; attempt < 50; attempt++)); do
  if yabai -m query --windows >/dev/null 2>&1; then
    yabai_ready=true
    break
  fi
  sleep 0.1
done
if [[ "$yabai_ready" != true ]]; then
  echo "Yabai is not responsive. Grant it Accessibility permission, then rerun install-desktop.sh." >&2
  exit 1
fi

# Disable built-in screenshot and recording keys so the rice launcher owns capture.
if ! python3 "$ROOT_DIR/scripts/macos-v2/configure-disabled-hotkeys.py" \
  28 29 30 31 64 184; then
  echo "Could not disable macOS's default screenshot keyboard shortcuts." >&2
  exit 1
fi

system_ui_pid="$(pgrep -x SystemUIServer || true)"
if [[ ! "$system_ui_pid" =~ ^[0-9]+$ ]]; then
  echo "Could not identify the SystemUIServer process to reload keyboard shortcuts." >&2
  exit 1
fi
system_ui_command="$(ps -p "$system_ui_pid" -o comm=)"
if [[ "$system_ui_command" != */SystemUIServer ]]; then
  echo "Refusing to restart an unexpected process for the SystemUIServer shortcut reload." >&2
  exit 1
fi
# launchctl cannot kickstart this SIP-protected UI agent, so signal its exact PID.
if ! kill -TERM "$system_ui_pid"; then
  echo "Could not restart SystemUIServer to apply the screenshot shortcut settings." >&2
  exit 1
fi
system_ui_reloaded=false
for ((attempt = 0; attempt < 50; attempt++)); do
  current_system_ui_pid="$(pgrep -x SystemUIServer || true)"
  if [[ "$current_system_ui_pid" =~ ^[0-9]+$ &&
    "$current_system_ui_pid" != "$system_ui_pid" ]]; then
    system_ui_reloaded=true
    break
  fi
  sleep 0.1
done
if [[ "$system_ui_reloaded" != true ]]; then
  echo "SystemUIServer did not restart to load the screenshot shortcut settings." >&2
  exit 1
fi

if ! python3 "$ROOT_DIR/scripts/macos-v2/configure-karabiner-shortcut.py"; then
  echo "Could not configure Karabiner's Command+Space launcher shortcuts." >&2
  exit 1
fi

launch_domain="gui/$(id -u)"
load_launch_agent() {
  local label="$1"
  local path="$HOME/Library/LaunchAgents/$label.plist"

  if launchctl print "$launch_domain/$label" >/dev/null 2>&1; then
    launchctl bootout "$launch_domain/$label"
  fi
  launchctl bootstrap "$launch_domain" "$path"
  if ! launchctl print "$launch_domain/$label" >/dev/null 2>&1; then
    echo "LaunchAgent did not load: $path" >&2
    exit 1
  fi
  echo "Loaded v2 LaunchAgent: $label"
}

load_launch_agent "com.macbook-rice-v2.borders"
load_launch_agent "com.macbook-rice-v2.sketchybar"
if ! "$HOME/.local/bin/rice-v2-start-desktop"; then
  echo "The v2 SketchyBar did not initialize after installation." >&2
  exit 1
fi

echo "Installed the v2 AeroSpace, SketchyBar, and wallpaper configuration."
if [[ "$backup_count" -gt 0 ]]; then
  echo "Replaced files were backed up under: $BACKUP_DIR"
else
  echo "No existing v2 target files needed backup."
fi
echo "Wallpaper files are in: $WALLPAPER_DIR"
