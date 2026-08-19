#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CODE_INSTALL_ROOT="${RICE_CODE_INSTALL_ROOT:-/usr/lib/code}"
CODE_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/rice-code-transparent"
TEMPLATE="$ROOT_DIR/dotfiles/linux/.local/share/rice-code-transparent/code.mjs"
STOCK_MAIN="$CODE_INSTALL_ROOT/out/main.js"
WORKBENCH_MAIN="$CODE_INSTALL_ROOT/out/vs/workbench/workbench.desktop.main.js"
STOCK_NODE_MODULES_ASAR="$CODE_INSTALL_ROOT/node_modules.asar"

if [[ ! -f "$STOCK_MAIN" ]]; then
  echo "Code OSS main bundle not found: $STOCK_MAIN" >&2
  echo "Install Code OSS first or set RICE_CODE_INSTALL_ROOT." >&2
  exit 1
fi

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Missing portable Code OSS launcher template: $TEMPLATE" >&2
  exit 1
fi
if [[ ! -f "$WORKBENCH_MAIN" ]]; then
  echo "Code OSS workbench bundle not found: $WORKBENCH_MAIN" >&2
  exit 1
fi
if [[ ! -f "$STOCK_NODE_MODULES_ASAR" ]]; then
  echo "Code OSS dependency archive not found: $STOCK_NODE_MODULES_ASAR" >&2
  exit 1
fi

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/rice-code-transparent.XXXXXX")"
previous_root="${CODE_ROOT}.previous"

cleanup() {
  if [[ -d "$temporary_root" ]]; then
    rm -rf "$temporary_root"
  fi
}
trap cleanup EXIT

mkdir -p "$temporary_root/out" "$(dirname "$CODE_ROOT")"
cp "$STOCK_MAIN" "$temporary_root/out/main.js"

if ! grep -Fq 'let Ye=ie.invokeFunction(Rl,this.windowState,void 0,Vt);' "$temporary_root/out/main.js"; then
  echo "Unsupported Code OSS main bundle: BrowserWindow patch point was not found." >&2
  exit 1
fi
if ! grep -Fq 'n.setBackgroundColor(t.colorInfo.background);' "$temporary_root/out/main.js"; then
  echo "Unsupported Code OSS main bundle: background-color patch point was not found." >&2
  exit 1
fi

perl -0pi -e \
  's/let Ye=ie\.invokeFunction\(Rl,this\.windowState,void 0,Vt\);/let Ye=ie.invokeFunction(Rl,this.windowState,process.env.VSCODE_TRANSPARENT==="1"?{transparent:!0}:void 0,Vt);/' \
  "$temporary_root/out/main.js"
perl -0pi -e \
  's/n\.setBackgroundColor\(t\.colorInfo\.background\);/n.setBackgroundColor(process.env.VSCODE_TRANSPARENT==="1"?"#00000000":t.colorInfo.background);/' \
  "$temporary_root/out/main.js"

for source_path in "$CODE_INSTALL_ROOT"/*; do
  [[ -e "$source_path" || -L "$source_path" ]] || continue
  name="$(basename "$source_path")"
  [[ "$name" == "out" || "$name" == "code.mjs" || "$name" == "node_modules" ]] && continue
  if [[ "$name" == "node_modules.asar" ]]; then
    # Electron's ASAR resolver needs the archive at the user-owned app path.
    cp --reflink=auto "$source_path" "$temporary_root/$name"
  else
    ln -s "$source_path" "$temporary_root/$name"
  fi
done

for source_path in "$CODE_INSTALL_ROOT/out"/*; do
  [[ -e "$source_path" || -L "$source_path" ]] || continue
  name="$(basename "$source_path")"
  [[ "$name" == "main.js" || "$name" == "vs" ]] && continue
  ln -s "$source_path" "$temporary_root/out/$name"
done

mkdir -p "$temporary_root/out/vs/workbench"
for source_path in "$CODE_INSTALL_ROOT/out/vs"/*; do
  [[ -e "$source_path" || -L "$source_path" ]] || continue
  name="$(basename "$source_path")"
  [[ "$name" == "workbench" ]] && continue
  ln -s "$source_path" "$temporary_root/out/vs/$name"
done
for source_path in "$CODE_INSTALL_ROOT/out/vs/workbench"/*; do
  [[ -e "$source_path" || -L "$source_path" ]] || continue
  name="$(basename "$source_path")"
  if [[ "$name" == "workbench.desktop.main.js" ]]; then
    cp "$source_path" "$temporary_root/out/vs/workbench/$name"
  else
    ln -s "$source_path" "$temporary_root/out/vs/workbench/$name"
  fi
done

patched_workbench="$temporary_root/out/vs/workbench/workbench.desktop.main.js"
if ! grep -Fq 'default:return $e.fromHex("#252526")}}' "$patched_workbench"; then
  echo "Unsupported Code OSS workbench bundle: root background patch point was not found." >&2
  exit 1
fi
perl -0pi -e \
  's/default:return \$e\.fromHex\("#252526"\)\}\}/default:return \$e.fromHex("#141218CC")}}/' \
  "$patched_workbench"

cp -p "$TEMPLATE" "$temporary_root/code.mjs"

if [[ -e "$previous_root" || -L "$previous_root" ]]; then
  rm -rf "$previous_root"
fi
if [[ -e "$CODE_ROOT" || -L "$CODE_ROOT" ]]; then
  mv "$CODE_ROOT" "$previous_root"
fi
mv "$temporary_root" "$CODE_ROOT"
if [[ -e "$previous_root" || -L "$previous_root" ]]; then
  rm -rf "$previous_root"
fi
trap - EXIT

echo "Code OSS transparency bundle prepared:"
echo "  $CODE_ROOT"
echo "Re-run this script after Code OSS updates."
