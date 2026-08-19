#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Linux bootstrap must run on Linux." >&2
  exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
  echo "pacman is required. This bootstrap targets Arch Linux and CachyOS." >&2
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo is required to install system packages." >&2
  exit 1
fi

PACMAN_PACKAGES=(
  base-devel
  bat
  btop
  code
  cmake
  curl
  eza
  fastfetch
  fd
  fish
  ffmpeg
  fzf
  ghostty
  grim
  hyprland
  imagemagick
  jq
  kitty
  lazygit
  meson
  neovim
  ninja
  nlohmann-json
  noctalia
  perl
  poppler
  resvg
  ripgrep
  satty
  slurp
  solaar
  stb
  smplayer
  starship
  tmux
  uwsm
  wl-clipboard
  yazi
  zoxide
  7zip
  electron42
)

echo "Updating Arch/CachyOS packages and installing rice dependencies..."
sudo pacman -Syu --needed "${PACMAN_PACKAGES[@]}"

aur_helper=""
if command -v paru >/dev/null 2>&1; then
  aur_helper="paru"
elif command -v yay >/dev/null 2>&1; then
  aur_helper="yay"
elif sudo pacman -S --needed paru; then
  aur_helper="paru"
fi

if [[ -n "$aur_helper" ]]; then
  echo "Installing Zen and LosslessCut through $aur_helper..."
  "$aur_helper" -S --needed zen-browser-bin losslesscut-bin
else
  echo "No paru or yay helper is available; install Zen and LosslessCut separately from the AUR." >&2
fi

echo
echo "Linux bootstrap complete. Next run:"
echo "  scripts/install-dotfiles.sh linux"
echo "  scripts/linux/apply-code-transparency.sh"
