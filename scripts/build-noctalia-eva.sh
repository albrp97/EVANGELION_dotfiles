#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "The EVA Noctalia build is only supported on Linux." >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NOCTALIA_TAG="${NOCTALIA_TAG:-v5.0.0-beta.8}"
NOCTALIA_JOBS="${NOCTALIA_JOBS:-2}"
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/eva-noctalia"
SOURCE_DIR="$CACHE_ROOT/source-${NOCTALIA_TAG//\//-}"
BUILD_DIR="$SOURCE_DIR/build-release"
PATCH_FILE="$ROOT_DIR/patches/noctalia/transparent-bar-no-blur.patch"

for command_name in git curl meson ninja pkg-config; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    echo "Install the build dependencies with:" >&2
    echo "  sudo pacman -S --needed meson ninja cmake nlohmann-json stb" >&2
    exit 1
  fi
done

if ! pkg-config --exists nlohmann_json && ! command -v cmake >/dev/null 2>&1; then
  echo "No nlohmann_json pkg-config or CMake package was found." >&2
  echo "Install it with: sudo pacman -S --needed cmake nlohmann-json" >&2
  exit 1
fi

stb_include="${STB_INCLUDE_DIR:-/usr/include}"
if ! printf '#include <stb/stb_image_resize2.h>\n#include <stb/stb_image_write.h>\n' \
    | "${CC:-cc}" -E -x c -I"$stb_include" - >/dev/null 2>&1; then
  echo "The stb image headers are missing." >&2
  echo "Install them with: sudo pacman -S --needed stb" >&2
  exit 1
fi

mkdir -p "$CACHE_ROOT"
if [[ ! -d "$SOURCE_DIR/.git" ]]; then
  git clone --quiet --depth=1 --branch "$NOCTALIA_TAG" \
    https://github.com/noctalia-dev/noctalia.git "$SOURCE_DIR"
fi

bar_source="$SOURCE_DIR/src/shell/bar/bar.cpp"
if grep -Fq 'instance.barConfig.backgroundOpacity <= 0.0F' "$bar_source"; then
  echo "Noctalia transparent-bar patch is already applied."
elif grep -Fq 'if (!barContentVisuallyShown(instance)) {' "$bar_source"; then
  git -C "$SOURCE_DIR" apply --check "$PATCH_FILE"
  git -C "$SOURCE_DIR" apply "$PATCH_FILE"
  echo "Applied the EVA transparent-bar patch."
else
  echo "Noctalia source no longer matches the expected bar blur code." >&2
  echo "Review the upstream change before rebuilding." >&2
  exit 1
fi

meson_setup_args=(
  --buildtype=release
  --prefix="$HOME/.local"
  -Dtests=disabled
  -Dcpp_std=c++23
  -Db_lto=true
)
if [[ -d "$BUILD_DIR" ]]; then
  meson setup "$BUILD_DIR" --reconfigure "${meson_setup_args[@]}"
else
  meson setup "$BUILD_DIR" "${meson_setup_args[@]}"
fi
meson compile -C "$BUILD_DIR" -j"$NOCTALIA_JOBS"
meson install -C "$BUILD_DIR" --no-rebuild

echo
echo "Installed patched Noctalia to:"
echo "  $HOME/.local/bin/noctalia"
echo "Restart Noctalia or log in again to apply it."
