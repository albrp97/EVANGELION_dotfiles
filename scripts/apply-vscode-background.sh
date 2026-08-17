#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WALLPAPER="${1:-$ROOT_DIR/wallpapers/09.jpg}"
APP_BUNDLE="${VSCODE_APP:-/Applications/Visual Studio Code.app}"
APP_OUT="$APP_BUNDLE/Contents/Resources/app/out"
MAIN_JS="$APP_OUT/main.js"
WORKBENCH_HTML="$APP_OUT/vs/code/electron-browser/workbench/workbench.html"
# The workbench HTML lives at out/vs/code/electron-browser/workbench and links
# ../../../workbench/... which resolves to out/vs/workbench.
APP_ASSET_DIR="$APP_OUT/vs/workbench"
APP_IMAGE="$APP_ASSET_DIR/macbook-linux-rice-vscode-bg.png"
APP_CSS="$APP_ASSET_DIR/macbook-linux-rice-vscode-background.css"
TRACKED_IMAGE="$ROOT_DIR/dotfiles/macos/.vscode/macbook-linux-rice-vscode-bg.png"

if [[ ! -f "$WALLPAPER" ]]; then
  echo "Wallpaper not found: $WALLPAPER" >&2
  exit 1
fi

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "VS Code app bundle not found: $APP_BUNDLE" >&2
  echo "Install VS Code or set VSCODE_APP=/path/to/Visual Studio Code.app" >&2
  exit 1
fi

if [[ ! -f "$WORKBENCH_HTML" ]]; then
  echo "VS Code workbench HTML not found: $WORKBENCH_HTML" >&2
  exit 1
fi

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick is required. Run scripts/bootstrap.sh first." >&2
  exit 1
fi

mkdir -p "$(dirname "$TRACKED_IMAGE")" "$APP_ASSET_DIR"

magick "$WALLPAPER" \
  -auto-orient \
  -resize '2560x1440^' \
  -gravity center \
  -extent 2560x1440 \
  -blur 0x26 \
  -modulate 112,122,112 \
  -fill '#0F1020' \
  -colorize 18 \
  "$TRACKED_IMAGE"

cp "$TRACKED_IMAGE" "$APP_IMAGE"

for file in "$WORKBENCH_HTML" "$MAIN_JS"; do
  [[ -f "$file" ]] || continue
  backup="$file.macbook-linux-rice-background-backup"
  if [[ ! -f "$backup" ]]; then
    cp "$file" "$backup"
  fi
done

# Remove the previous Vibrancy runtime patch so it cannot fight this static background.
if [[ -f "$MAIN_JS" ]]; then
  perl -0pi -e 's/\n\/\* !! VSCODE-VIBRANCY-START !! \*\/[\s\S]*?\/\* !! VSCODE-VIBRANCY-END !! \*\//\n/g' "$MAIN_JS"
fi
rm -rf "$APP_OUT/vscode-vibrancy-runtime-v6"

# Remove the extra trusted type from the old Vibrancy patch.
perl -0pi -e 's/ VscodeVibrancyContinued//g' "$WORKBENCH_HTML"

if ! grep -q 'macbook-linux-rice-vscode-background.css' "$WORKBENCH_HTML"; then
  perl -0pi -e 's#(<link rel="stylesheet" href="../../../workbench/workbench\.desktop\.main\.css">\n)#$1\t\t<link rel="stylesheet" href="../../../workbench/macbook-linux-rice-vscode-background.css">\n#' "$WORKBENCH_HTML"
fi

cat > "$APP_CSS" <<'CSS'
/* MacBook Linux Rice: fake transparency for VS Code.
   The wallpaper is intentionally limited to the editor/code surface. Keeping
   sidebars/title/status opaque avoids discontinuous seams between VS Code regions. */
:root {
  --rice-opaque: rgba(15, 16, 32, 0.94);
  --rice-panel: rgba(15, 16, 32, 0.90);
  --rice-editor: rgba(15, 16, 32, 0.66);
  --rice-editor-soft: rgba(15, 16, 32, 0.56);
  --rice-strong: rgba(15, 16, 32, 0.88);
  --rice-status: #5a3e85;
  --rice-border: rgba(124, 95, 184, 0.42);
}

html,
body {
  background: #0f1020 !important;
  min-height: 100% !important;
}

body {
  background: #0f1020 !important;
}

.monaco-workbench {
  position: relative;
  z-index: 1;
  background: #0f1020 !important;
  --vscode-editor-background: var(--rice-editor) !important;
  --vscode-sideBar-background: var(--rice-panel) !important;
  --vscode-activityBar-background: var(--rice-opaque) !important;
  --vscode-panel-background: var(--rice-panel) !important;
  --vscode-terminal-background: var(--rice-editor) !important;
  --vscode-titleBar-activeBackground: var(--rice-opaque) !important;
  --vscode-statusBar-background: var(--rice-status) !important;
  --vscode-statusBar-noFolderBackground: var(--rice-status) !important;
  --vscode-statusBar-debuggingBackground: #7c5fb8 !important;
  --vscode-tab-activeBackground: var(--rice-editor) !important;
  --vscode-tab-inactiveBackground: var(--rice-panel) !important;
  --vscode-editorWidget-background: var(--rice-strong) !important;
  --vscode-quickInput-background: var(--rice-strong) !important;
  --vscode-notifications-background: var(--rice-strong) !important;
}

.monaco-workbench,
.monaco-workbench .part,
.monaco-workbench .composite,
.monaco-workbench .content,
.monaco-workbench .pane-body,
.monaco-workbench .pane-header,
.monaco-workbench .split-view-view,
.monaco-workbench .editor-group-container,
.monaco-workbench .editor-container,
.monaco-workbench .editor-instance,
.monaco-workbench .monaco-editor,
.monaco-workbench .monaco-editor-background,
.monaco-workbench .monaco-editor .margin,
.monaco-workbench .terminal-outer-container,
.monaco-workbench .terminal-wrapper,
.monaco-workbench .xterm,
.monaco-workbench .xterm-viewport {
  background-color: transparent !important;
}

.monaco-workbench .part.sidebar,
.monaco-workbench .part.auxiliarybar,
.monaco-workbench .part.activitybar,
.monaco-workbench .part.panel,
.monaco-workbench .part.titlebar,
.monaco-workbench .tabs-container,
.monaco-workbench .breadcrumbs-control,
.monaco-workbench .composite.title,
.monaco-workbench .monaco-list,
.monaco-workbench .monaco-list-rows {
  background-color: var(--rice-panel) !important;
  background-image: none !important;
  backdrop-filter: none !important;
}

.monaco-workbench .part.activitybar,
.monaco-workbench .part.titlebar {
  background-color: var(--rice-opaque) !important;
}

.monaco-workbench .part.statusbar,
.monaco-workbench .part.statusbar > .items-container {
  background-color: var(--rice-status) !important;
  background-image: none !important;
  color: #f2eaff !important;
}

.monaco-workbench .part.editor,
.monaco-workbench .part.editor > .content,
.monaco-workbench .part.editor > .content .grid-view-container,
.monaco-workbench .part.editor > .content .editor-group-container,
.monaco-workbench .editor-group-container .editor-container,
.monaco-workbench .editor-instance,
.monaco-workbench .monaco-editor {
  background:
    linear-gradient(var(--rice-editor), var(--rice-editor)),
    radial-gradient(circle at 22% 35%, rgba(124, 95, 184, 0.22), transparent 36%),
    url("./macbook-linux-rice-vscode-bg.png") center / cover no-repeat !important;
}

.monaco-workbench .monaco-editor-background,
.monaco-workbench .monaco-editor .margin {
  background-color: var(--rice-editor-soft) !important;
  background-image: none !important;
}

.monaco-workbench .terminal-wrapper,
.monaco-workbench .xterm-rows {
  background-color: var(--rice-editor) !important;
  background-image: none !important;
}

.monaco-workbench .monaco-editor .view-overlays .current-line {
  background-color: rgba(25, 23, 36, 0.42) !important;
}

.monaco-workbench .monaco-scrollable-element > .scrollbar > .slider {
  background: rgba(124, 95, 184, 0.45) !important;
}

.monaco-workbench .part,
.monaco-workbench .monaco-sash {
  border-color: var(--rice-border) !important;
}
CSS

# Modifying the app bundle invalidates Microsoft's original resource seal.
# Re-sign ad hoc and clear quarantine so Gatekeeper does not report it as damaged.
codesign --force --deep --sign - "$APP_BUNDLE"
xattr -dr com.apple.quarantine "$APP_BUNDLE" 2>/dev/null || true

echo "VS Code fake transparency background applied from:"
echo "  $WALLPAPER"
echo "Generated asset:"
echo "  $TRACKED_IMAGE"
echo "Restart VS Code to see it."
