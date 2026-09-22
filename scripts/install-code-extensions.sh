#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Code OSS extension installation is configured for Linux only."
  exit 0
fi

code_cli="${RICE_CODE_CLI:-}"
if [[ -z "$code_cli" ]]; then
  if command -v code-oss >/dev/null 2>&1; then
    code_cli="$(command -v code-oss)"
  else
    echo "Code OSS is not installed; skipping Code OSS extension installation."
    exit 0
  fi
fi

if [[ ! -x "$code_cli" ]]; then
  echo "Code OSS CLI is not executable: $code_cli" >&2
  exit 1
fi

extensions=(
  tomoki1207.pdf
)

for extension in "${extensions[@]}"; do
  "$code_cli" --install-extension "$extension" --force
done
