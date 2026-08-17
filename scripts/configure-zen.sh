#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${1:-$ROOT_DIR/dotfiles/common/zen}"
BACKUP_DIR="${2:-$HOME/.macbook-linux-rice-backup/zen/$(date +%Y%m%d-%H%M%S)}"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Missing Zen style source directory: $SOURCE_DIR" >&2
  exit 1
fi

for required_file in userChrome.css userContent.css user.js; do
  if [[ ! -f "$SOURCE_DIR/$required_file" ]]; then
    echo "Missing Zen style file: $SOURCE_DIR/$required_file" >&2
    exit 1
  fi
done

profile_roots=(
  "$HOME/.config/zen"
  "$HOME/.config/zen-browser"
  "$HOME/.zen"
  "$HOME/Library/Application Support/Zen/Profiles"
  "$HOME/Library/Application Support/zen/Profiles"
)

backup_file() {
  local source_path="$1"
  local backup_path="$2"

  if [[ ! -e "$source_path" && ! -L "$source_path" ]]; then
    return
  fi

  mkdir -p "$(dirname "$backup_path")"
  if [[ -L "$source_path" ]]; then
    cp -P "$source_path" "$backup_path"
  else
    cp -p "$source_path" "$backup_path"
  fi
}

profile_count=0
while IFS= read -r -d '' chrome_dir; do
  profile_dir="$(dirname "$chrome_dir")"
  profile_name="$(basename "$profile_dir")"
  profile_count=$((profile_count + 1))
  backup_root="$BACKUP_DIR/${profile_count}-${profile_name}"

  backup_file "$chrome_dir/userChrome.css" "$backup_root/chrome/userChrome.css"
  backup_file "$chrome_dir/userContent.css" "$backup_root/chrome/userContent.css"
  backup_file "$profile_dir/user.js" "$backup_root/user.js"

  rm -f "$chrome_dir/userChrome.css" "$chrome_dir/userContent.css" "$profile_dir/user.js"
  cp -p "$SOURCE_DIR/userChrome.css" "$chrome_dir/userChrome.css"
  cp -p "$SOURCE_DIR/userContent.css" "$chrome_dir/userContent.css"
  cp -p "$SOURCE_DIR/user.js" "$profile_dir/user.js"

  echo "Applied EVA-01 Zen styling to: $profile_dir"
done < <(
  for profile_root in "${profile_roots[@]}"; do
    [[ -d "$profile_root" ]] || continue
    for profile_dir in "$profile_root"/*; do
      [[ -d "$profile_dir/chrome" ]] || continue
      printf '%s\0' "$profile_dir/chrome"
    done
  done
)

if [[ "$profile_count" -eq 0 ]]; then
  echo "No Zen profiles found; install or start Zen once, then rerun scripts/configure-zen.sh."
  exit 0
fi

echo "Zen styles are backed up, if needed, under:"
echo "  $BACKUP_DIR"
