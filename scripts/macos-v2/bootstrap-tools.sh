#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script only supports macOS." >&2
  exit 1
fi

export PATH="$HOME/.local/bin:$HOME/.homebrew/bin:$HOME/.homebrew/sbin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications --fontdir=$HOME/Library/Fonts"

if command -v brew >/dev/null 2>&1; then
  brew_bin="$(command -v brew)"
elif [[ -x "$HOME/.homebrew/bin/brew" ]]; then
  brew_bin="$HOME/.homebrew/bin/brew"
elif [[ -x /opt/homebrew/bin/brew ]]; then
  brew_bin="/opt/homebrew/bin/brew"
elif [[ -x /usr/local/bin/brew ]]; then
  brew_bin="/usr/local/bin/brew"
else
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "Xcode Command Line Tools are required. Run 'xcode-select --install', finish the installer, then retry." >&2
    exit 1
  fi
  if [[ -e "$HOME/.homebrew/Homebrew" && ! -d "$HOME/.homebrew/Homebrew/.git" ]]; then
    echo "Refusing to replace the existing path $HOME/.homebrew/Homebrew" >&2
    exit 1
  fi
  mkdir -p "$HOME/.homebrew/bin"
  if [[ ! -d "$HOME/.homebrew/Homebrew/.git" ]]; then
    git clone https://github.com/Homebrew/brew "$HOME/.homebrew/Homebrew"
  fi
  if [[ ! -e "$HOME/.homebrew/bin/brew" ]]; then
    ln -s ../Homebrew/bin/brew "$HOME/.homebrew/bin/brew"
  fi
  brew_bin="$HOME/.homebrew/bin/brew"
fi

brew_prefix="$("$brew_bin" --prefix)"
if [[ "$brew_prefix" == "$HOME/.homebrew" ]]; then
  export HOMEBREW_PREFIX="$HOME/.homebrew"
  export HOMEBREW_NO_INSTALL_FROM_API=1
fi

mkdir -p "$HOME/Applications" "$HOME/Library/Fonts" "$HOME/.local/bin"

if ! "$SCRIPT_DIR/disable-legacy-skhd.sh"; then
  echo "Could not disable the legacy skhd shortcut service before installing v2." >&2
  exit 1
fi

echo "Installing the v2 terminal, shell, fetch, file-manager, and macOS integration tools."
"$brew_bin" install fish starship yazi sevenzip duti tmux ffmpeg imagemagick
"$SCRIPT_DIR/install-azure-cli.sh"
if [[ "${HOMEBREW_NO_INSTALL_FROM_API:-}" == "1" ]]; then
  "$brew_bin" tap homebrew/cask
fi
"$brew_bin" install --cask \
  ghostty \
  font-sf-mono-nerd-font-ligaturized \
  karabiner-elements \
  raycast \
  zen \
  visual-studio-code

if [[ ! -d "/Applications/Microsoft Teams.app" &&
  ! -d "$HOME/Applications/Microsoft Teams.app" ]]; then
  "$brew_bin" install --cask microsoft-teams
fi

install_fastfetch() (
  set -euo pipefail

  local version="2.68.1"
  local asset
  local checksum
  local architecture
  local work_dir
  local archive
  local source_binary
  local temp_binary
  local target="$HOME/.local/bin/fastfetch"
  local backup_dir
  local version_output

  case "$(uname -m)" in
    arm64|aarch64)
      architecture="aarch64"
      asset="fastfetch-macos-aarch64.tar.gz"
      checksum="22426608dca945e0531af37054e21a2727aa7bb30179efaf44de7f59163be5fe"
      ;;
    x86_64|amd64)
      architecture="amd64"
      asset="fastfetch-macos-amd64.tar.gz"
      checksum="1e9a6ba7474a41b3cc2bb1b923afcf40c749c25bd17dc1e62b64464e7445a534"
      ;;
    *)
      echo "Fastfetch release binaries are unavailable for $(uname -m)." >&2
      exit 1
      ;;
  esac

  work_dir="$(mktemp -d "${TMPDIR:-/tmp}/rice-v2-fastfetch.XXXXXX")"
  temp_binary=""
  cleanup_fastfetch() {
    if [[ -n "$temp_binary" ]]; then
      rm -f "$temp_binary"
    fi
    rm -rf "$work_dir"
  }
  trap cleanup_fastfetch EXIT

  archive="$work_dir/$asset"
  curl -fsSL \
    "https://github.com/fastfetch-cli/fastfetch/releases/download/$version/$asset" \
    -o "$archive"
  printf '%s  %s\n' "$checksum" "$archive" | shasum -a 256 -c -
  tar -xzf "$archive" -C "$work_dir"

  source_binary="$work_dir/fastfetch-macos-$architecture/usr/bin/fastfetch"
  if [[ ! -x "$source_binary" ]]; then
    echo "The Fastfetch release archive did not contain its executable." >&2
    exit 1
  fi
  version_output="$("$source_binary" --version)"
  if [[ "$version_output" != *"$version"* ]]; then
    echo "Unexpected Fastfetch version in the downloaded release: $version_output" >&2
    exit 1
  fi

  if [[ -x "$target" ]] && "$target" --version 2>/dev/null | grep -Fq "$version"; then
    echo "Fastfetch $version is already installed."
    exit 0
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    if [[ -d "$target" && ! -L "$target" ]]; then
      echo "Cannot replace a directory with the Fastfetch executable: $target" >&2
      exit 1
    fi
    backup_dir="$HOME/.macbook-rice-v2-backup/fastfetch-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    cp -Pp "$target" "$backup_dir/fastfetch"
  fi

  temp_binary="$(mktemp "$HOME/.local/bin/fastfetch.XXXXXX")"
  install -m 755 "$source_binary" "$temp_binary"
  mv -f "$temp_binary" "$target"
  temp_binary=""
  echo "Installed verified Fastfetch $version in $target."
)

install_fastfetch

"$brew_bin" tap nikitabobko/tap
"$brew_bin" trust --cask nikitabobko/tap/aerospace

echo "Installing AeroSpace from its official, non-notarized release."
echo "The official Homebrew cask removes quarantine from this app only; Gatekeeper stays enabled."
"$brew_bin" install --cask nikitabobko/tap/aerospace

echo "Installing Yabai for hover-focus only; AeroSpace remains the window manager."
"$brew_bin" tap koekeishiya/formulae
"$brew_bin" install koekeishiya/formulae/yabai

if ! command -v borders >/dev/null 2>&1; then
  echo "Installing JankyBorders from FelixKratz's Homebrew formula."
  "$brew_bin" install felixkratz/formulae/borders
fi

if ! command -v sketchybar >/dev/null 2>&1; then
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "Xcode Command Line Tools are required to build SketchyBar." >&2
    exit 1
  fi

  build_dir="$(mktemp -d "${TMPDIR:-/tmp}/macbook-rice-v2-sketchybar.XXXXXX")"
  trap 'rm -rf "$build_dir"' EXIT
  archive="$build_dir/sketchybar.tar.gz"
  source_dir="$build_dir/SketchyBar-2.24.0"

  curl -fsSL \
    "https://github.com/FelixKratz/SketchyBar/archive/refs/tags/v2.24.0.tar.gz" \
    -o "$archive"
  printf '%s  %s\n' \
    "de0bf966e73735acfdbe54d8848b7a506e59dc1ffb39a0d4799d74e4a6a3f6dc" \
    "$archive" | shasum -a 256 -c -
  tar -xzf "$archive" -C "$build_dir"
  make -C "$source_dir"
  codesign --force -s - "$source_dir/bin/sketchybar"

  target="$HOME/.local/bin/sketchybar"
  if [[ -e "$target" || -L "$target" ]]; then
    backup_dir="$HOME/.macbook-rice-v2-backup/sketchybar-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    cp -Pp "$target" "$backup_dir/sketchybar"
  fi
  install -m 755 "$source_dir/bin/sketchybar" "$target"
fi

sketchybar -v
if ! command -v borders >/dev/null 2>&1; then
  echo "JankyBorders is missing after installation." >&2
  exit 1
fi
echo "JankyBorders: $(command -v borders)"
if ! command -v aerospace >/dev/null 2>&1; then
  echo "AeroSpace CLI is missing after installation." >&2
  exit 1
fi
echo "AeroSpace CLI: $(command -v aerospace)"
if ! command -v yabai >/dev/null 2>&1; then
  echo "Yabai is missing after installation." >&2
  exit 1
fi
echo "Yabai CLI: $(command -v yabai)"
if ! command -v code >/dev/null 2>&1; then
  echo "Visual Studio Code's 'code' CLI is missing after installation." >&2
  exit 1
fi
if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI's 'az' command is missing after installation." >&2
  exit 1
fi
if [[ ! -d "$HOME/Applications/Visual Studio Code.app" &&
  ! -d "/Applications/Visual Studio Code.app" ]]; then
  echo "Visual Studio Code.app is missing after installation." >&2
  exit 1
fi
if [[ ! -d "$HOME/Applications/Zen.app" && ! -d "/Applications/Zen.app" ]]; then
  echo "Zen.app is missing after installation." >&2
  exit 1
fi
if [[ ! -d "/Applications/Microsoft Teams.app" ]]; then
  echo "Microsoft Teams.app is missing after installation." >&2
  exit 1
fi
echo "Microsoft Teams: /Applications/Microsoft Teams.app"
echo "Azure CLI: $(command -v az)"
az version --output none
code --version
