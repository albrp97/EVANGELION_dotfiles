#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
VERSION="2.90.0"
PYTHON_VERSION="3.14.7"
CLI_ROOT="$HOME/.local/opt/azure-cli"
INSTALL_DIR="$CLI_ROOT/$VERSION"
CURRENT_LINK="$CLI_ROOT/current"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/azure-cli-install.XXXXXX")"
STAGING_DIR=""
trap 'rm -rf "$WORK_DIR"; if [[ -n "$STAGING_DIR" ]]; then rm -rf "$STAGING_DIR"; fi' EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This installer only supports macOS." >&2
  exit 1
fi

case "$(uname -m)" in
  arm64|aarch64)
    ASSET="azure-cli-$VERSION-macos-arm64.tar.gz"
    CLI_SHA256="1cdcf8dc99ece8c10d198d9451d7ac0905a4d63aea5fac5fcf903bdf2aba93b3"
    ;;
  x86_64|amd64)
    ASSET="azure-cli-$VERSION-macos-x86_64.tar.gz"
    CLI_SHA256="4617d8d16350dbee34f8024059ac768e0cfbdb7ec8f637abdfdaab1e5c9ba0ce"
    ;;
  *)
    echo "Azure CLI $VERSION is unavailable for $(uname -m)." >&2
    exit 1
    ;;
esac

find_python() {
  local candidate

  if [[ -n "${AZ_PYTHON:-}" ]]; then
    printf '%s\n' "$AZ_PYTHON"
    return
  fi

  for candidate in \
    /Library/Frameworks/Python.framework/Versions/3.14/bin/python3.14 \
    "$HOME/.homebrew/opt/python@3.14/libexec/bin/python3" \
    "$HOME/.homebrew/bin/python3.14" \
    /opt/homebrew/opt/python@3.14/libexec/bin/python3 \
    /opt/homebrew/bin/python3.14 \
    /usr/local/opt/python@3.14/libexec/bin/python3 \
    /usr/local/bin/python3.14; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  command -v python3.14 || true
}

python_is_supported() {
  [[ -x "$1" ]] && "$1" -c 'import sys; raise SystemExit(0 if sys.version_info[:2] == (3, 14) else 1)' >/dev/null 2>&1
}

PYTHON="$(find_python)"
if [[ -n "$PYTHON" ]] && ! python_is_supported "$PYTHON"; then
  echo "Python at $PYTHON is not a usable Python 3.14 runtime." >&2
  exit 1
fi

if [[ -z "$PYTHON" ]]; then
  PYTHON_PKG="$WORK_DIR/python-$PYTHON_VERSION-macos11.pkg"
  PYTHON_PKG_SHA256="70c5239ad2d62925d2947e46921d0ddd3d35be3d2f0a2d50db33da507dbcb419"

  echo "Downloading the signed Python $PYTHON_VERSION runtime required by Azure CLI."
  curl --proto '=https' --tlsv1.2 -fsSL \
    "https://www.python.org/ftp/python/$PYTHON_VERSION/python-$PYTHON_VERSION-macos11.pkg" \
    -o "$PYTHON_PKG"
  printf '%s  %s\n' "$PYTHON_PKG_SHA256" "$PYTHON_PKG" | shasum -a 256 -c -

  signature_output="$(pkgutil --check-signature "$PYTHON_PKG")"
  if [[ "$signature_output" != *"Developer ID Installer: Python Software Foundation"* ||
    "$signature_output" != *"Notarization: trusted"* ]]; then
    echo "The Python installer signature or notarization could not be verified." >&2
    exit 1
  fi

  echo "macOS will request administrator authorization to install Python in /Library/Frameworks."
  osascript -e 'on run argv
    set package_path to quoted form of (item 1 of argv)
    do shell script "/usr/sbin/installer -pkg " & package_path & " -target /" with administrator privileges
  end run' "$PYTHON_PKG"
  PYTHON="/Library/Frameworks/Python.framework/Versions/3.14/bin/python3.14"
fi

if ! python_is_supported "$PYTHON"; then
  echo "Python 3.14 is required, but the runtime at $PYTHON did not start." >&2
  exit 1
fi

mkdir -p "$CLI_ROOT" "$HOME/.local/bin"

if [[ -e "$INSTALL_DIR" || -L "$INSTALL_DIR" ]]; then
  if [[ ! -x "$INSTALL_DIR/bin/az" ||
    ! -d "$INSTALL_DIR/libexec/lib/python3.14/site-packages" ]]; then
    echo "Refusing to replace an incomplete Azure CLI installation at $INSTALL_DIR." >&2
    exit 1
  fi
else
  ARCHIVE="$WORK_DIR/$ASSET"
  curl --proto '=https' --tlsv1.2 -fsSL \
    "https://github.com/Azure/azure-cli/releases/download/azure-cli-$VERSION/$ASSET" \
    -o "$ARCHIVE"
  printf '%s  %s\n' "$CLI_SHA256" "$ARCHIVE" | shasum -a 256 -c -

  STAGING_DIR="$(mktemp -d "$CLI_ROOT/.$VERSION.XXXXXX")"
  tar -xzf "$ARCHIVE" -C "$STAGING_DIR"
  if [[ ! -x "$STAGING_DIR/bin/az" ||
    ! -d "$STAGING_DIR/libexec/lib/python3.14/site-packages" ]]; then
    echo "The verified Azure CLI archive is missing its launcher or Python packages." >&2
    exit 1
  fi

  mv "$STAGING_DIR" "$INSTALL_DIR"
  STAGING_DIR=""
fi

if [[ -e "$CURRENT_LINK" && ! -L "$CURRENT_LINK" ]]; then
  echo "Refusing to replace a non-symlink Azure CLI path: $CURRENT_LINK" >&2
  exit 1
fi
ln -sfn "$INSTALL_DIR" "$CURRENT_LINK"

version_json="$(AZ_PYTHON="$PYTHON" "$INSTALL_DIR/bin/az" version --output json)"
AZURE_CLI_VERSION_JSON="$version_json" EXPECTED_AZURE_CLI_VERSION="$VERSION" \
  "$PYTHON" -c '
import json
import os
import sys

try:
    version = json.loads(os.environ["AZURE_CLI_VERSION_JSON"]).get("azure-cli")
except (KeyError, json.JSONDecodeError) as error:
    raise SystemExit(f"Could not read Azure CLI version output: {error}")

expected = os.environ["EXPECTED_AZURE_CLI_VERSION"]
if version != expected:
    raise SystemExit(f"Expected Azure CLI {expected}, found {version!r}.")
'

WRAPPER_SOURCE="$ROOT_DIR/dotfiles/macos-v2/.local/bin/az"
WRAPPER_TARGET="$HOME/.local/bin/az"
if [[ ! -f "$WRAPPER_SOURCE" ]]; then
  echo "Missing Azure CLI launcher wrapper: $WRAPPER_SOURCE" >&2
  exit 1
fi

if [[ -e "$WRAPPER_TARGET" || -L "$WRAPPER_TARGET" ]]; then
  if [[ -d "$WRAPPER_TARGET" && ! -L "$WRAPPER_TARGET" ]]; then
    echo "Refusing to replace a directory with the Azure CLI wrapper: $WRAPPER_TARGET" >&2
    exit 1
  fi
  if ! cmp -s "$WRAPPER_SOURCE" "$WRAPPER_TARGET"; then
    BACKUP_DIR="$HOME/.macbook-rice-v2-backup/azure-cli-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    cp -Pp "$WRAPPER_TARGET" "$BACKUP_DIR/az"
    TEMP_WRAPPER="$(mktemp "$HOME/.local/bin/az.XXXXXX")"
    install -m 755 "$WRAPPER_SOURCE" "$TEMP_WRAPPER"
    mv -f "$TEMP_WRAPPER" "$WRAPPER_TARGET"
  fi
else
  install -m 755 "$WRAPPER_SOURCE" "$WRAPPER_TARGET"
fi

"$WRAPPER_TARGET" version --output none
echo "Installed Azure CLI $VERSION at $INSTALL_DIR using $("$PYTHON" --version 2>&1)."
