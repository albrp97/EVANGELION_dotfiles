#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
export PATH="$HOME/.local/bin:$HOME/.homebrew/bin:$HOME/.homebrew/sbin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

EXPECTED_WRAPPER="$ROOT_DIR/dotfiles/macos-v2/.local/bin/az"
INSTALLED_WRAPPER="$HOME/.local/bin/az"
CURRENT_LINK="$HOME/.local/opt/azure-cli/current"

if [[ ! -x "$INSTALLED_WRAPPER" || ! -f "$EXPECTED_WRAPPER" ]] ||
  ! cmp -s "$EXPECTED_WRAPPER" "$INSTALLED_WRAPPER"; then
  echo "The installed Azure CLI wrapper is missing or differs from the tracked source." >&2
  exit 1
fi
if [[ ! -L "$CURRENT_LINK" || ! -x "$CURRENT_LINK/bin/az" ]]; then
  echo "The versioned Azure CLI installation is missing or incomplete at $CURRENT_LINK." >&2
  exit 1
fi
if [[ "$(command -v az)" != "$INSTALLED_WRAPPER" ]]; then
  echo "The az command does not resolve to the MacBook Rice v2 launcher." >&2
  exit 1
fi

version_json="$(az version --output json)"
python3 - "$version_json" <<'PY'
import json
import sys

try:
    version = json.loads(sys.argv[1]).get("azure-cli")
except (IndexError, json.JSONDecodeError) as error:
    raise SystemExit(f"Azure CLI returned invalid version output: {error}")

if version != "2.90.0":
    raise SystemExit(f"Expected Azure CLI 2.90.0, found {version!r}.")
PY
az account -h >/dev/null

echo "Azure CLI functionality check passed: az runs, reports version 2.90.0, and exposes account commands."
