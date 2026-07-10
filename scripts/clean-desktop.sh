#!/usr/bin/env bash
set -euo pipefail

DESKTOP="$HOME/Desktop"
BACKUP_DIR="$HOME/.macbook-linux-rice-backup/desktop-$(date +%Y%m%d-%H%M%S)"

if [[ ! -d "$DESKTOP" ]]; then
  echo "Desktop directory does not exist; nothing to clean."
  exit 0
fi

find "$DESKTOP" -maxdepth 1 -type f \( \
  -name 'Screenshot *' -o \
  -name 'Screen Shot *' -o \
  -name 'CleanShot *' \
\) -print -delete

mkdir -p "$BACKUP_DIR"
moved=0

while IFS= read -r -d '' item; do
  name="$(basename "$item")"
  case "$name" in
    .DS_Store|.localized)
      rm -f "$item"
      ;;
    *)
      mv "$item" "$BACKUP_DIR/"
      moved=1
      ;;
  esac
done < <(find "$DESKTOP" -maxdepth 1 -mindepth 1 -print0)

if [[ "$moved" -eq 0 ]]; then
  rmdir "$BACKUP_DIR" 2>/dev/null || true
  echo "Desktop cleaned. No user files needed backup."
else
  echo "Desktop cleaned. Non-screenshot files moved to:"
  echo "  $BACKUP_DIR"
fi
