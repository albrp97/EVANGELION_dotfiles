#!/usr/bin/env bash
set -euo pipefail

wallpaper_dir="${RICE_WALLPAPER_DIR:-$HOME/.local/share/macbook-rice-v2/wallpapers}"
state_file="${XDG_STATE_HOME:-$HOME/.local/state}/macbook-rice-v2/current-wallpaper"
random_wallpaper="$HOME/.local/bin/rice-v2-random-wallpaper"
wallpaper_helper="$HOME/.local/bin/rice-v2-set-wallpaper"

if [[ ! -x "$random_wallpaper" || ! -x "$wallpaper_helper" ]]; then
  echo "Install the v2 desktop configuration before running this functionality test." >&2
  exit 1
fi

wallpapers=()
while IFS= read -r path; do
  wallpapers+=("$path")
done < <(
  find "$wallpaper_dir" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
    -print | LC_ALL=C sort
)

if (( ${#wallpapers[@]} == 0 )); then
  echo "No wallpaper images found in $wallpaper_dir" >&2
  exit 1
fi

first="$("$random_wallpaper")"
second="$("$random_wallpaper")"

if (( ${#wallpapers[@]} > 1 )) && [[ "$first" == "$second" ]]; then
  echo "Wallpaper rotation repeated the same image twice: $second" >&2
  exit 1
fi

if [[ ! -f "$second" || ! -f "$state_file" ]]; then
  echo "Wallpaper helper did not save the selected image and state." >&2
  exit 1
fi

saved=""
IFS= read -r saved < "$state_file" || true
if [[ "$saved" != "$second" ]]; then
  echo "Saved wallpaper state does not match the last selected image." >&2
  exit 1
fi

while IFS= read -r actual; do
  if [[ "$actual" != "$second" ]]; then
    echo "Display is using '$actual', expected '$second'." >&2
    exit 1
  fi
done < <("$wallpaper_helper" --current)

echo "Wallpaper rotation works: selects and applies a non-repeating image across active displays."
