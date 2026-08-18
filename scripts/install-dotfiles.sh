#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
requested_platform="${1:-}"
if [[ "$requested_platform" == "macos" || "$requested_platform" == "linux" ]]; then
  shift
elif [[ -n "$requested_platform" ]]; then
  echo "Usage: $0 [macos|linux]" >&2
  exit 2
fi

if [[ $# -gt 0 ]]; then
  echo "Usage: $0 [macos|linux]" >&2
  exit 2
fi

platform="$requested_platform"
if [[ -z "$platform" ]]; then
  case "$(uname -s)" in
    Darwin) platform="macos" ;;
    Linux) platform="linux" ;;
    *)
      echo "Unsupported operating system: $(uname -s)" >&2
      exit 1
      ;;
  esac
fi

COMMON_DIR="$ROOT_DIR/dotfiles/common"
PLATFORM_DIR="$ROOT_DIR/dotfiles/$platform"
BACKUP_DIR="$HOME/.macbook-linux-rice-backup/$platform/$(date +%Y%m%d-%H%M%S)"
BACKUP_MARKER_DIR="$BACKUP_DIR/.backed-up"

for source_dir in "$COMMON_DIR" "$PLATFORM_DIR"; do
  if [[ ! -d "$source_dir" ]]; then
    echo "Missing dotfiles source directory: $source_dir" >&2
    exit 1
  fi
done

mkdir -p "$BACKUP_MARKER_DIR"

backup_target() {
  local relative_path="$1"
  local target_path="$2"
  local marker_path="$BACKUP_MARKER_DIR/$relative_path"
  local backup_path="$BACKUP_DIR/$relative_path"

  if [[ -e "$marker_path" || -L "$marker_path" ]]; then
    return
  fi

  mkdir -p "$(dirname "$marker_path")"
  : > "$marker_path"

  if [[ ! -e "$target_path" && ! -L "$target_path" ]]; then
    return
  fi

  mkdir -p "$(dirname "$backup_path")"
  if [[ -d "$target_path" && ! -L "$target_path" ]]; then
    cp -R -p "$target_path" "$backup_path"
  elif [[ -L "$target_path" ]]; then
    cp -P "$target_path" "$backup_path"
  else
    cp -p "$target_path" "$backup_path"
  fi
}

install_file() {
  local source_path="$1"
  local relative_path="$2"
  local target_root="${3:-$HOME}"
  local target_path="$target_root/$relative_path"
  local backup_relative="$relative_path"
  if [[ "$target_root" != "$HOME" ]]; then
    backup_relative="${target_path#"$HOME"/}"
  fi

  backup_target "$backup_relative" "$target_path"

  if [[ -d "$target_path" && ! -L "$target_path" ]]; then
    echo "Cannot replace directory with a file: $target_path" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$target_path")"
  local temp_path
  temp_path="$(mktemp "${target_path}.tmp.XXXXXX")"
  rm -f "$temp_path"
  if [[ -L "$source_path" ]]; then
    cp -P "$source_path" "$temp_path"
  else
    cp -p "$source_path" "$temp_path"
  fi
  mv -f "$temp_path" "$target_path"
}

install_layer() {
  local source_dir="$1"
  local skip_zen="$2"

  while IFS= read -r -d '' source_path; do
    local relative_path="${source_path#"$source_dir"/}"
    if [[ "$skip_zen" == "yes" && ( "$relative_path" == "zen" || "$relative_path" == zen/* ) ]]; then
      continue
    fi
    install_file "$source_path" "$relative_path"
  done < <(find "$source_dir" \( -type f -o -type l \) -print0)
}

install_tree_to_root() {
  local source_dir="$1"
  local target_root="$2"

  while IFS= read -r -d '' source_path; do
    local relative_path="${source_path#"$source_dir"/}"
    install_file "$source_path" "$relative_path" "$target_root"
  done < <(find "$source_dir" \( -type f -o -type l \) -print0)
}

install_eva_virtual_click() {
  local protocol="$ROOT_DIR/scripts/protocols/wlr-virtual-pointer-unstable-v1.xml"
  local source="$ROOT_DIR/scripts/eva-vclick.c"
  local wrapper="$ROOT_DIR/scripts/eva-vclick-current.sh"
  local build_dir
  build_dir="$(mktemp -d)"

  if ! command -v wayland-scanner >/dev/null 2>&1 \
    || ! command -v "${CC:-cc}" >/dev/null 2>&1 \
    || ! pkg-config --exists wayland-client; then
    rm -rf "$build_dir"
    echo "Missing Wayland build dependencies for the Noctalia hover anchor." >&2
    echo "Install wayland-scanner, a C compiler, and wayland-client development files." >&2
    exit 1
  fi

  if ! wayland-scanner client-header "$protocol" \
      "$build_dir/wlr-virtual-pointer-unstable-v1-client-protocol.h" \
    || ! wayland-scanner private-code "$protocol" \
      "$build_dir/wlr-virtual-pointer-unstable-v1-client-protocol.c" \
    || ! "${CC:-cc}" -O2 -Wall -Wextra -I"$build_dir" "$source" \
      "$build_dir/wlr-virtual-pointer-unstable-v1-client-protocol.c" \
      -o "$build_dir/eva-vclick" $(pkg-config --cflags --libs wayland-client); then
    rm -rf "$build_dir"
    echo "Failed to build the Noctalia hover anchor helper." >&2
    exit 1
  fi

  install_file "$build_dir/eva-vclick" ".local/bin/eva-vclick"
  install_file "$wrapper" ".local/bin/eva-vclick-current"
  rm -rf "$build_dir"
}

install_layer "$COMMON_DIR" yes
install_layer "$PLATFORM_DIR" no

if [[ "$platform" == "linux" ]]; then
  install_eva_virtual_click
fi

if [[ "$platform" == "macos" && -d "$ROOT_DIR/wallpapers" ]]; then
  install_tree_to_root "$ROOT_DIR/wallpapers" "$HOME/.local/share/macbook-linux-rice/wallpapers"
fi

if [[ "$platform" == "linux" && -d "$COMMON_DIR/.vscode/extensions" ]]; then
  install_tree_to_root "$COMMON_DIR/.vscode/extensions" "$HOME/.vscode-oss/extensions"
fi

if [[ -d "$COMMON_DIR/zen" ]]; then
  "$ROOT_DIR/scripts/configure-zen.sh" "$COMMON_DIR/zen" "$BACKUP_DIR/zen"
fi

chmod u+x "$HOME/bin/copilot" "$HOME/bin/code" "$HOME/bin/update" 2>/dev/null || true
find "$HOME/.local/bin" -type f -name 'rice-*' -exec chmod u+x {} + 2>/dev/null || true
find "$HOME/.local/bin" -type f \( -name 'screenshot-*' -o -name 'paste-*' \) -exec chmod u+x {} + 2>/dev/null || true
chmod u+x "$HOME/.config/sketchybar/sketchybarrc" "$HOME/.config/sketchybar/plugins/"*.sh 2>/dev/null || true
rm -rf "$BACKUP_MARKER_DIR"

echo "Installed common EVA-01 configuration and the $platform platform layer."
echo "Backups, if any, are in:"
echo "  $BACKUP_DIR"
if [[ "$platform" == "macos" ]]; then
  echo
  echo "Karabiner: the 'MacBook Linux Rice' profile maps right Command to HyprMod."
  echo "yabai/skhd: grant Accessibility permission when prompted, then run scripts/start-services.sh."
fi
