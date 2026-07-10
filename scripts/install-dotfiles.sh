#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/dotfiles/home"
BACKUP_DIR="$HOME/.macbook-linux-rice-backup/$(date +%Y%m%d-%H%M%S)"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Missing dotfiles source directory: $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"

while IFS= read -r -d '' source_path; do
  relative_path="${source_path#$SOURCE_DIR/}"
  target_path="$HOME/$relative_path"

  if [[ -e "$target_path" || -L "$target_path" ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$relative_path")"
    cp -R "$target_path" "$BACKUP_DIR/$relative_path"
    chmod u+w "$target_path" 2>/dev/null || true
  fi

  mkdir -p "$(dirname "$target_path")"
  cp "$source_path" "$target_path"
done < <(find "$SOURCE_DIR" -type f -print0)

chmod +x "$HOME/.config/sketchybar/sketchybarrc" "$HOME/.config/sketchybar/plugins/"*.sh 2>/dev/null || true
chmod +x "$HOME/.local/bin/"rice-* 2>/dev/null || true

echo "Dotfiles installed. Backups, if any, are in:"
echo "  $BACKUP_DIR"
echo
echo "Karabiner: the 'MacBook Linux Rice' profile maps right Command to HyprMod."
echo "yabai/skhd: grant Accessibility permission when prompted, then run scripts/start-services.sh."
