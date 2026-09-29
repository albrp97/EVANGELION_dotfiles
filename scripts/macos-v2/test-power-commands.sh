#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
SOURCE_CONFIG="$ROOT_DIR/dotfiles/macos-v2/.config/fish/config.fish"
INSTALLED_CONFIG="$HOME/.config/fish/config.fish"
SOURCE_POWER_MENU="$ROOT_DIR/dotfiles/macos-v2/.local/bin/rice-v2-power-menu"
INSTALLED_POWER_MENU="$HOME/.local/bin/rice-v2-power-menu"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rice-v2-power-commands.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT

FISH_BIN="$(command -v fish || true)"
if [[ -z "$FISH_BIN" ]]; then
  echo "Fish is missing. Run scripts/macos-v2/bootstrap-tools.sh." >&2
  exit 1
fi
if [[ ! -f "$SOURCE_CONFIG" || ! -f "$INSTALLED_CONFIG" ]] ||
  ! cmp -s "$SOURCE_CONFIG" "$INSTALLED_CONFIG"; then
  echo "Installed Fish config differs from the tracked v2 source. Run scripts/macos-v2/install-desktop.sh." >&2
  exit 1
fi
if [[ ! -x "$INSTALLED_POWER_MENU" || ! -f "$SOURCE_POWER_MENU" ]] ||
  ! cmp -s "$SOURCE_POWER_MENU" "$INSTALLED_POWER_MENU"; then
  echo "Installed power-menu helper differs from the tracked v2 source. Run scripts/macos-v2/install-desktop.sh." >&2
  exit 1
fi

mkdir -p "$TEST_DIR/fake-bin"
cat >"$TEST_DIR/fake-bin/command-shim" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s' "${0##*/}" >>"$RICE_POWER_TEST_LOG"
printf ' <%s>' "$@" >>"$RICE_POWER_TEST_LOG"
printf '\n' >>"$RICE_POWER_TEST_LOG"
SH
chmod u+x "$TEST_DIR/fake-bin/command-shim"
for command_name in rice-v2-power-menu pmset sleep; do
  ln -s command-shim "$TEST_DIR/fake-bin/$command_name"
done

RICE_POWER_TEST_BIN="$TEST_DIR/fake-bin" \
  RICE_POWER_TEST_LOG="$TEST_DIR/commands.log" \
  "$FISH_BIN" -c '
    source "$HOME/.config/fish/config.fish"
    set -p PATH "$RICE_POWER_TEST_BIN"
    shutdown
    reboot
    sleep
    sleep 7
  '

actual="$(cat "$TEST_DIR/commands.log")"
expected="$(
  printf '%s\n' \
    'rice-v2-power-menu <--shutdown>' \
    'rice-v2-power-menu <--reboot>' \
    'pmset <sleepnow>' \
    'sleep <7>'
)"
if [[ "$actual" != "$expected" ]]; then
  printf 'Unexpected power command dispatch.\nExpected:\n%s\nActual:\n%s\n' "$expected" "$actual" >&2
  exit 1
fi

echo "Power command functionality checks passed."
