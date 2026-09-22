#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "The Linux sudo session configuration requires Linux." >&2
  exit 1
fi

for command_name in cmp id install mktemp sed sudo visudo; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$ROOT_DIR/scripts/sudoers/90-eva-sudo-session"
TARGET="/etc/sudoers.d/90-eva-sudo-session"
CURRENT_USER="$(id -un)"
TEMP_FILE="$(mktemp)"
TARGET_ALREADY_EXISTS=0

cleanup() {
  rm -f "$TEMP_FILE"
}
trap cleanup EXIT

sed "s/__USER__/$CURRENT_USER/g" "$TEMPLATE" > "$TEMP_FILE"
if ! visudo -cf "$TEMP_FILE" >/dev/null; then
  echo "Generated sudoers configuration failed validation." >&2
  exit 1
fi

if sudo test -e "$TARGET"; then
  TARGET_ALREADY_EXISTS=1
  if ! sudo cmp -s "$TEMP_FILE" "$TARGET"; then
    echo "A different sudoers configuration already exists: $TARGET" >&2
    echo "Review it manually before replacing it." >&2
    exit 1
  fi
else
  sudo install -o root -g root -m 0440 "$TEMP_FILE" "$TARGET"
fi

if ! sudo visudo -c >/dev/null; then
  if [[ "$TARGET_ALREADY_EXISTS" -eq 0 ]]; then
    sudo rm -f "$TARGET"
  fi
  echo "The complete sudoers configuration failed validation." >&2
  exit 1
fi

# Warm the global timestamp immediately, so this install also counts as the
# current session's one authentication.
sudo -v
echo "Sudo authentication is cached globally until the ticket is invalidated."
