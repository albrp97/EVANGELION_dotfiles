#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALL_ROOT="${RICE_LOSSLESSCUT_INSTALL_ROOT:-/usr/share/losslesscut}"
THEME_CSS="$ROOT_DIR/dotfiles/linux/.config/losslesscut/eva01.css"
OVERLAY_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/rice-losslesscut"

if [[ ! -x "$INSTALL_ROOT/losslesscut" ]]; then
  echo "LosslessCut executable not found: $INSTALL_ROOT/losslesscut" >&2
  echo "Install losslesscut-bin first or set RICE_LOSSLESSCUT_INSTALL_ROOT." >&2
  exit 1
fi

if [[ ! -f "$INSTALL_ROOT/resources/app.asar" ]]; then
  echo "LosslessCut application archive not found: $INSTALL_ROOT/resources/app.asar" >&2
  exit 1
fi

if [[ ! -f "$THEME_CSS" ]]; then
  echo "Missing LosslessCut EVA stylesheet: $THEME_CSS" >&2
  exit 1
fi

if command -v asar >/dev/null 2>&1; then
  ASAR_COMMAND=(asar)
elif command -v npx >/dev/null 2>&1; then
  ASAR_COMMAND=(npx --yes @electron/asar@latest)
else
  echo "The LosslessCut theme needs the Electron ASAR tool." >&2
  echo "Install Node.js/npm or put the 'asar' command on PATH." >&2
  exit 1
fi

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/rice-losslesscut.XXXXXX")"
cleanup() {
  if [[ -d "$temporary_root" ]]; then
    rm -rf "$temporary_root"
  fi
}
trap cleanup EXIT

extracted_root="$temporary_root/app"
"${ASAR_COMMAND[@]}" extract "$INSTALL_ROOT/resources/app.asar" "$extracted_root" >/dev/null

renderer_index="$extracted_root/out/renderer/index.html"
if [[ ! -f "$renderer_index" ]]; then
  echo "Unsupported LosslessCut archive: renderer index was not found." >&2
  exit 1
fi

renderer_css_name="$(sed -nE 's#.*href="./assets/([^"]+\.css)".*#\1#p' "$renderer_index" | head -n 1)"
if [[ -z "$renderer_css_name" ]]; then
  echo "Unsupported LosslessCut archive: renderer stylesheet link was not found." >&2
  exit 1
fi

renderer_css="$extracted_root/out/renderer/assets/$renderer_css_name"
if [[ ! -f "$renderer_css" ]]; then
  echo "Unsupported LosslessCut archive: linked stylesheet was not found: $renderer_css_name" >&2
  exit 1
fi

main_bundle="$extracted_root/out/main/index.js"
if [[ ! -f "$main_bundle" ]]; then
  echo "Unsupported LosslessCut archive: main process bundle was not found." >&2
  exit 1
fi

if ! grep -Fq '    darkTheme: true,' "$main_bundle" \
  || ! grep -Fq '    backgroundColor: darkMode ? "#333" : "#fff",' "$main_bundle"; then
  echo "Unsupported LosslessCut main bundle: transparent-window patch points were not found." >&2
  exit 1
fi

perl -0pi -e \
  's/(\n    darkTheme: true,\n)/$1    transparent: true,\n/' \
  "$main_bundle"
perl -0pi -e \
  's/\n    backgroundColor: darkMode \? "#333" : "#fff",/\n    backgroundColor: "#00000000",/' \
  "$main_bundle"

printf '\n' >> "$renderer_css"
cat "$THEME_CSS" >> "$renderer_css"

patched_archive="$temporary_root/app.asar"
"${ASAR_COMMAND[@]}" pack "$extracted_root" "$patched_archive" >/dev/null

runtime_root="$temporary_root/runtime"
mkdir -p "$runtime_root/resources"
cp --reflink=auto "$INSTALL_ROOT/losslesscut" "$runtime_root/losslesscut"
chmod u+x "$runtime_root/losslesscut"

for source_path in "$INSTALL_ROOT"/*; do
  [[ -e "$source_path" || -L "$source_path" ]] || continue
  name="$(basename "$source_path")"
  [[ "$name" == "losslesscut" || "$name" == "resources" ]] && continue
  ln -s "$source_path" "$runtime_root/$name"
done

for source_path in "$INSTALL_ROOT/resources"/*; do
  [[ -e "$source_path" || -L "$source_path" ]] || continue
  name="$(basename "$source_path")"
  [[ "$name" == "app.asar" ]] && continue
  ln -s "$source_path" "$runtime_root/resources/$name"
done
cp --reflink=auto "$patched_archive" "$runtime_root/resources/app.asar"

mkdir -p "$(dirname "$OVERLAY_ROOT")"
previous_root="${OVERLAY_ROOT}.previous"
if [[ -e "$previous_root" || -L "$previous_root" ]]; then
  rm -rf "$previous_root"
fi
if [[ -e "$OVERLAY_ROOT" || -L "$OVERLAY_ROOT" ]]; then
  mv "$OVERLAY_ROOT" "$previous_root"
fi
mv "$runtime_root" "$OVERLAY_ROOT"
if [[ -e "$previous_root" || -L "$previous_root" ]]; then
  rm -rf "$previous_root"
fi
trap - EXIT

echo "LosslessCut EVA-01 runtime prepared:"
echo "  $OVERLAY_ROOT"
echo "Re-run this script after losslesscut-bin updates."
