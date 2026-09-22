#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "The Linux greetd configuration requires Linux." >&2
  exit 1
fi

for command_name in cmp id install mktemp sed sudo systemctl; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

if [[ ! -f /etc/greetd/config.toml ]] && ! command -v greetd >/dev/null 2>&1; then
  echo "greetd is not installed; skipping automatic session configuration."
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$ROOT_DIR/scripts/greetd/config.toml"
TARGET="/etc/greetd/config.toml"
BACKUP="/etc/greetd/config.toml.eva-noctalia-backup"
CURRENT_USER="$(id -un)"
TEMP_FILE="$(mktemp)"

cleanup() {
  rm -f "$TEMP_FILE"
}
trap cleanup EXIT

if [[ "$CURRENT_USER" == "root" ]]; then
  echo "Run this script as the desktop user, not root." >&2
  exit 1
fi

if [[ ! -x /usr/bin/uwsm || ! -f /usr/share/wayland-sessions/hyprland.desktop ]]; then
  echo "UWSM-managed Hyprland is not installed; cannot configure greetd safely." >&2
  exit 1
fi

sed "s/__USER__/$CURRENT_USER/g" "$TEMPLATE" > "$TEMP_FILE"

if sudo test -e "$TARGET" && ! sudo test -e "$BACKUP"; then
  sudo install -o root -g root -m 0644 "$TARGET" "$BACKUP"
fi

if sudo cmp -s "$TEMP_FILE" "$TARGET"; then
  echo "greetd is already configured for automatic UWSM Hyprland login."
else
  sudo install -o root -g root -m 0644 "$TEMP_FILE" "$TARGET"
  echo "Configured greetd to skip Noctalia Greeter and start Hyprland automatically."
fi

sudo systemctl enable greetd.service >/dev/null
echo "The new login behavior applies after the next reboot or greetd restart."
