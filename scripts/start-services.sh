#!/usr/bin/env bash
set -euo pipefail

if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif [[ -x "$HOME/.homebrew/bin/brew" ]]; then
  eval "$("$HOME/.homebrew/bin/brew" shellenv)"
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is not available; run scripts/bootstrap.sh first." >&2
  exit 1
fi

if ! brew services restart sketchybar >/dev/null 2>&1; then
  echo "SketchyBar restart was blocked by Homebrew tap trust; reloading the running service instead." >&2
  sketchybar --reload >/dev/null 2>&1 || true
fi
skhd --restart-service >/dev/null 2>&1 || skhd --start-service
yabai --restart-service >/dev/null 2>&1 || yabai --start-service

if [[ -x "$HOME/.local/bin/rice-random-wallpaper" ]]; then
  if ! "$HOME/.local/bin/rice-random-wallpaper"; then
    echo "Wallpaper could not be applied; check macOS Accessibility permission." >&2
  fi
else
  echo "Wallpaper helper is missing: $HOME/.local/bin/rice-random-wallpaper" >&2
fi

if [[ -x "$HOME/.local/bin/rice-display-route" ]]; then
  "$HOME/.local/bin/rice-display-route" >/dev/null 2>&1 || true
fi

uid="$(id -u)"
launchctl bootout "gui/$uid" "$HOME/Library/LaunchAgents/com.macbook-linux-rice.display-route.plist" >/dev/null 2>&1 || true

brew services stop borders >/dev/null 2>&1 || true
launchctl bootout "gui/$uid" "$HOME/Library/LaunchAgents/homebrew.mxcl.borders.plist" >/dev/null 2>&1 || true
launchctl bootout "gui/$uid" "$HOME/Library/LaunchAgents/com.macbook-linux-rice.borders.plist" >/dev/null 2>&1 || true

while read -r pid; do
  if [[ -n "$pid" ]]; then
    kill "$pid" >/dev/null 2>&1 || true
  fi
done < <(ps -axo pid=,command= | awk '/[b]orders active_color=/ { print $1 }')

if [[ -f "$HOME/Library/LaunchAgents/com.macbook-linux-rice.borders.plist" ]]; then
  launchctl bootstrap "gui/$uid" "$HOME/Library/LaunchAgents/com.macbook-linux-rice.borders.plist"
  launchctl kickstart -k "gui/$uid/com.macbook-linux-rice.borders"
elif command -v borders >/dev/null 2>&1; then
  borders 'active_color=gradient(top_left=0xffa3d977,bottom_right=0xff6faf6e)' inactive_color=0xff26233a width=6.0 &
fi

launchctl bootout "gui/$uid" "$HOME/Library/LaunchAgents/com.macbook-linux-rice.wallpaper-rotation.plist" >/dev/null 2>&1 || true
launchctl remove "com.macbook-linux-rice.wallpaper-rotation" >/dev/null 2>&1 || true
rm -f "$HOME/Library/LaunchAgents/com.macbook-linux-rice.wallpaper-rotation.plist"

open_app_if_present() {
  local app_name="$1"
  if [[ -d "/Applications/$app_name.app" || -d "$HOME/Applications/$app_name.app" ]]; then
    open -gja "$app_name"
  else
    echo "$app_name is not installed yet; skipping launch."
  fi
}

open_app_if_present Karabiner-Elements

echo "Rice services started. Grant macOS permissions if prompted."
