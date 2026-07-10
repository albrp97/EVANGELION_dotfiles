#!/usr/bin/env bash
set -euo pipefail

echo "Applying Linux-style macOS UI defaults..."

# Safe system-wide Pastel EVA-01 appearance knobs.
# macOS does not expose full app-surface theming for Settings/Finder, but these
# values recolor supported controls, selections, buttons, and highlight states.
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true' >/dev/null 2>&1 || true
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"
defaults write NSGlobalDomain AppleInterfaceStyleSwitchesAutomatically -bool false
defaults write NSGlobalDomain AppleAccentColor -int 5
defaults write NSGlobalDomain AppleHighlightColor -string "0.486275 0.372549 0.721569 Purple"
defaults write NSGlobalDomain AppleReduceTransparency -bool false
defaults write NSGlobalDomain AppleEnableMenuBarTransparency -bool true
defaults write NSGlobalDomain AppleShowScrollBars -string "WhenScrolling"

# Hide the macOS Dock and remove most of its reveal delay.
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.15
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock tilesize -int 36

# Hide the native menu bar so SketchyBar can act as the visible top bar.
defaults write NSGlobalDomain _HIHideMenuBar -bool true
defaults write -g _HIHideMenuBar -bool true
defaults write NSGlobalDomain AppleMenuBarVisibleInFullscreen -bool false

# Hide Desktop icons for a clean Linux-rice desktop.
defaults write com.apple.finder CreateDesktop -bool false

# Disable macOS screenshot shortcuts that conflict with Command+Shift+workspace.
# Disable native Spotlight shortcuts so Karabiner can own Command+Space on
# built-in and Bluetooth keyboards.
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 28 "{ enabled = 0; value = { parameters = (51, 20, 1179648); type = standard; }; }"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 29 "{ enabled = 0; value = { parameters = (51, 20, 1441792); type = standard; }; }"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 30 "{ enabled = 0; value = { parameters = (52, 21, 1179648); type = standard; }; }"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 31 "{ enabled = 0; value = { parameters = (52, 21, 1441792); type = standard; }; }"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 "{ enabled = 0; value = { parameters = (32, 49, 1048576); type = standard; }; }"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 65 "{ enabled = 0; value = { parameters = (32, 49, 1572864); type = standard; }; }"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 184 "{ enabled = 0; value = { parameters = (53, 23, 1179648); type = standard; }; }"

# Keep native Control+1..9 Desktop switching disabled; workspace switching is
# handled by skhd/yabai. Native shortcuts were tested for slide animation but
# added delay without visible animation on this setup.
for shortcut_id in 118 119 120 121 122 123 124 125 126; do
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$shortcut_id" "{ enabled = 0; }"
done

# Keep workspaces predictable for tiling.
defaults write com.apple.dock mru-spaces -bool false
defaults write com.apple.spaces spans-displays -bool false

# Make keyboard navigation feel closer to Linux.
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Trackpad: tap-to-click and slightly faster pointer movement.
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 1.65
defaults -currentHost write NSGlobalDomain com.apple.trackpad.scaling -float 1.65
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

# Reduce animation friction without disabling core macOS features.
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
defaults write com.apple.dock expose-animation-duration -float 0.1
defaults write com.apple.dock launchanim -bool false

# Finder/dev quality-of-life defaults.
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true

uid="$(id -u)"
launchctl kickstart -k "gui/$uid/com.apple.Dock.agent" >/dev/null 2>&1 || true
launchctl kickstart -k "gui/$uid/com.apple.SystemUIServer.agent" >/dev/null 2>&1 || true
launchctl kickstart -k "gui/$uid/com.apple.Finder" >/dev/null 2>&1 || true

echo "Defaults applied. Some Spaces and menu-bar changes may require logging out and back in."
