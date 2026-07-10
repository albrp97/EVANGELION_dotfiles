#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BREWFILE="$ROOT_DIR/Brewfile"
USER_BREW_PREFIX="$HOME/.homebrew"

TAPS=(
  FelixKratz/formulae
  asmvik/formulae
)

FORMULAE=(
  chezmoi
  starship
  fzf
  zoxide
  zsh-autosuggestions
  zsh-autocomplete
  zsh-syntax-highlighting
  carapace
  fastfetch
  eza
  bat
  fd
  ripgrep
  jq
  duti
  git-delta
  btop
  neovim
  tmux
  lazygit
  yazi
  ffmpeg
  sevenzip
  unar
  poppler
  resvg
  imagemagick
  sketchybar
  borders
  asmvik/formulae/yabai
  asmvik/formulae/skhd
)

CASKS=(
  ghostty
  font-hack-nerd-font
  font-jetbrains-mono-nerd-font
  font-sf-mono-nerd-font-ligaturized
  font-symbols-only-nerd-font
)

ADOPTABLE_CASKS=(
  visual-studio-code
  zen
)

PRIVILEGED_CASKS=(
  karabiner-elements
)

load_brew() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  elif [[ -x "$USER_BREW_PREFIX/bin/brew" ]]; then
    eval "$("$USER_BREW_PREFIX/bin/brew" shellenv)"
  fi
}

install_user_local_homebrew() {
  echo "Installing user-local Homebrew in $USER_BREW_PREFIX..."
  mkdir -p "$USER_BREW_PREFIX"

  if [[ ! -d "$USER_BREW_PREFIX/Homebrew/.git" ]]; then
    git clone https://github.com/Homebrew/brew "$USER_BREW_PREFIX/Homebrew"
  else
    git -C "$USER_BREW_PREFIX/Homebrew" pull --ff-only
  fi

  mkdir -p "$USER_BREW_PREFIX/bin"
  ln -sf ../Homebrew/bin/brew "$USER_BREW_PREFIX/bin/brew"
}

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "Re-run this script after the Xcode Command Line Tools installer finishes."
  exit 0
fi

load_brew

if ! command -v brew >/dev/null 2>&1; then
  if sudo -n true >/dev/null 2>&1; then
    echo "Installing standard Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    echo "Standard Homebrew needs administrator authentication; using user-local Homebrew instead."
    install_user_local_homebrew
  fi
fi

load_brew

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew was not installed or could not be loaded." >&2
  exit 1
fi

if [[ "$(brew --prefix)" == "$USER_BREW_PREFIX" ]]; then
  mkdir -p "$HOME/Applications" "$HOME/Library/Fonts"
  export HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications --fontdir=$HOME/Library/Fonts"
  export HOMEBREW_NO_INSTALL_FROM_API=1
fi

echo "Installing packages from $BREWFILE..."
brew update

for tap in "${TAPS[@]}"; do
  brew tap "$tap"
done

brew install "${FORMULAE[@]}"

for cask in "${CASKS[@]}"; do
  brew install --cask "$cask"
done

for cask in "${ADOPTABLE_CASKS[@]}"; do
  brew install --cask "$cask" || brew install --cask --adopt "$cask"
done

for cask in "${PRIVILEGED_CASKS[@]}"; do
  if ! brew install --cask "$cask"; then
    echo "Could not install privileged cask: $cask" >&2
    echo "Install it later with administrator authentication, then rerun scripts/install-dotfiles.sh." >&2
  fi
done

if command -v code >/dev/null 2>&1; then
  code --install-extension arcticicestudio.nord-visual-studio-code --force
fi

echo "Bootstrap complete. Next run:"
echo "  scripts/install-dotfiles.sh"
echo "  scripts/apply-macos-defaults.sh"
echo "  scripts/start-services.sh"
