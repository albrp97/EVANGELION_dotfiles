# MacBook Rice v2 Keyboard Map

`Command` is the macOS equivalent of Linux `SUPER`. AeroSpace manages
top-level application windows; browser tabs within one window are not separate
tiles. Open a new application window (usually `Command+N`) to create another
grid cell.

## Window management

| Action | Shortcut |
| --- | --- |
| Close focused window | `Command+Q` or `Command+Esc` |
| Focus left/right/up/down | `Command+Arrow` |
| Move focused window left/right/up/down | `Command+Shift+Arrow` |
| Cycle windows | `Option+Tab` |
| Toggle floating/tiling | `Command+Option+Space` |
| Toggle fullscreen | `Command+D` |
| Toggle the focused tile orientation | `Command+J` |
| Grow/shrink focused tile | `Command+=` / `Command+-` |
| Balance the current workspace | `HyprMod+B` |
| Focus left/down/up/right | `HyprMod+H/J/K/L` |
| Swap focused window left/down/up/right | `HyprMod+Shift+H/J/K/L` |
| Toggle floating/tiling | `HyprMod+F` |
| Toggle fullscreen | `HyprMod+Shift+F` |
| Grow/shrink focused tile | `HyprMod+=` / `HyprMod+-` |

The grid reflows on detected windows and after the tiled-window set changes.
For one through four tiled windows it matches the Linux rice's one-window,
1:1, 1:2, and 2:2 layouts. Beyond four it adds balanced columns with at most
two windows each; AeroSpace otherwise nests larger stacks unevenly. Dialogs
and floating utility windows remain outside the grid.

Yabai runs in float-only mode with `focus_follows_mouse autofocus` and
`mouse_follows_focus on`; AeroSpace continues to own tiling and virtual
workspaces. Hovering focuses the window under the pointer, and changing focus
moves the pointer to the focused window. Yabai does not load its scripting
addition, and no SIP change or `sudo` is used. Grant Yabai Accessibility
permission in System Settings so focus tracking can work.

## Workspaces

| Action | Shortcut |
| --- | --- |
| Focus workspace 1–9 | `Command+1..9` |
| Move focused window to workspace 1–9 and follow it | `Command+Shift+1..9` |
| Focus previous/next workspace | `Command+Control+Left/Right` |
| Focus the previously focused workspace | `Command+Control+Up` |
| Focus the next empty numbered workspace | `Command+Control+Down` |
| Move focused window to previous/next workspace | `Command+Control+Shift+Left/Right` |
| Move focused window by workspace offset 1–9 | `Command+Control+Shift+1..9` |
| Focus scratch workspace | `HyprMod+0` |
| Move focused window to scratch | `HyprMod+Shift+0` or `HyprMod+Shift+S` |
| Toggle scratch and the previous workspace | `HyprMod+S` |
| Focus a workspace offset from the current one | `Command+Control+1..9` |
| Move a window to a workspace on the current single monitor | `HyprMod+Shift+1..9` |

Workspace offsets wrap across 1–9; offset 1 means the next workspace and
offset 9 returns to the current workspace. The scratch workspace is not shown
in the numbered workspace-dot strip in SketchyBar.

## Launcher

| Action | Shortcut |
| --- | --- |
| Open Raycast search directly | `Option+Space` |
| Search apps and files with Raycast | `Command+Space`, then `Space` |
| Open a new Ghostty terminal | `Command+Space`, then `T` or `Return` |
| Open Yazi in a new Ghostty terminal | `Command+Space`, then `E` |
| Open the pinned Fastfetch console | `Command+Space`, then `Y` |
| Open Zen browser | `Command+Space`, then `Z` |
| Open Visual Studio Code | `Command+Space`, then `V` |
| Open Activity Monitor (btop fallback) | `Command+Space`, then `R` |
| Select a screen region and copy it to the clipboard | `Command+Space`, then `S` or `P` |
| Cancel launcher mode | `Escape` |

Raycast's own global hotkey is `Option+Space`; Karabiner-Elements separately
captures `Command+Space` as a 1.5-second leader. Launcher keys also work if
Command remains held. `Y` opens a new Ghostty window with
Fastfetch pinned above an interactive Fish shell. `Z` opens Zen and `V` opens
Visual Studio Code. `R` opens Activity Monitor as the btop fallback. `S`
preserves the old rice's screenshot key; `P` remains an alias. Press `Escape`
to cancel. Spotlight's conflicting default `Command+Space` shortcut is disabled.
The Ghostty launcher opens windows through macOS UI automation; if prompted,
grant Accessibility access to the process running the launcher.

## Top bar and power chooser

The top bar follows the older Mac rice layout and EVA palette: power icon,
clock, AeroSpace workspace dots, plus volume, weather, and battery pills from
left to right. Dots 1–3 always show; higher-numbered dots appear through the
highest focused or occupied workspace. The old brightness item is intentionally
omitted. The power icon opens a native macOS chooser for locking, display sleep,
system sleep, 30-minute caffeinate, and restarting the v2 UI services. Logging
out, restarting, or shutting down requires a second confirmation.

## HyprMod app and utility actions

HyprMod is `Command+Option+Control`. The old Linux apps that are not installed
on this Mac use their closest installed macOS equivalents for now.

| Action | Shortcut |
| --- | --- |
| Open a new Ghostty window | `HyprMod+T` or `HyprMod+Return` |
| Open Finder (file manager / Yazi fallback) | `HyprMod+E`, `HyprMod+Shift+E`, or `HyprMod+Shift+Y` |
| Open Zen browser | `HyprMod+Z` or `HyprMod+W` |
| Open Visual Studio Code | `HyprMod+V` or `HyprMod+Shift+T` |
| Open Activity Monitor (btop fallback) | `HyprMod+R` or `Control+Shift+Escape` |
| Open Calculator | `HyprMod+Shift+C` |

The v2 installer configures the Command+Space launcher in Karabiner's selected
profile and stores its importable rule under
`~/.config/karabiner/assets/complex_modifications/`. Grant Karabiner-Elements
the required macOS input permissions when prompted. The optional
right-Command-to-HyprMod rule remains available; until it is enabled, hold
`Command+Option+Control` directly for HyprMod bindings.

## Terminal and file-manager workflow

Ghostty starts Fish with the EVA Starship prompt and Fastfetch hardware panel.
The shared `~/.hushlogin` marker suppresses macOS's `Last login` banner in new
terminal login sessions.
Set `FASTFETCH_DISABLE=1` when launching Fish to suppress the startup panel.
The `y` command opens Yazi and changes Fish's directory to Yazi's final
location when it exits.
Double-clicking an executable `.command` file runs it in Ghostty from its
containing directory; Terminal.app remains installed as a fallback.

Inside Yazi, `\t` opens Ghostty in the current directory, `\f` reveals the
hovered item in Finder, `\x` extracts the hovered archive, and `\z` creates a
zip from the selected files. `\c` opens the current directory in Finder.
Use `,l` and `,L` to sort videos by duration ascending or descending. The
`'` bookmarks include Home, code, Downloads, Documents, Pictures, Music,
Movies, Videos, and `/tmp`; use `'M` for Music and `'m` for Movies. Text files
use the `vi` editor unless `EDITOR` is changed.

Yazi includes all shared plugins, including `video-info`, with FFmpeg frame
previews, local `ffprobe` metadata, video sort and spotter support, Git status,
smart navigation/filter/paste/create, pane controls, chmod, rounded borders,
and the Starship header. The Linux systemd movie-enrichment/indexing service
remains Linux-only; macOS video technical metadata works without it.

The Fish `copilot` function forces ANSI colors, unsets `COLORTERM` so the
terminal's EVA palette supplies them, and clears inherited `COPILOT_ALLOW_ALL`.
It does not pass `--allow-all`; Copilot CLI approval prompts remain enabled.
Copilot CLI supports built-in palette presets rather than a custom EVA palette.
The v2 user settings disable the home navigation tabs so the chat stays
uncluttered. `Ctrl+T` toggles expanded reasoning rows; leave them collapsed for
the compact, muted timeline used by the Linux setup.

## Native macOS shortcuts

- `Command+Space`, then `P`, starts region selection and copies the selection
  to the clipboard. `Command+Space`, then `S`, keeps the legacy screenshot
  alias.
- `Command+Space`, then `Space`, opens Raycast app and file search.
- `Command+Tab` remains the native application switcher.
- `Control+Command+Q` locks the screen, and `Control+Command+Space` opens
  Emoji & Symbols.
- Native `Command+Shift+3/4/5` screenshot shortcuts and their `Control` copy
  variants are disabled. Karabiner also consumes `Command+Shift+3` so macOS
  cannot trigger the built-in full-screen capture; use `Command+Space`, then
  `P` for the rice capture.
- `Command+W` and normal copy/paste/edit shortcuts retain their native
  macOS meanings.
- Hardware media, volume, and brightness keys remain under macOS control.
- Noctalia's clipboard-history, wallpaper, control-center, and session panels
  have no v2 app installed yet; Raycast supplies app/file search, and native
  clipboard/screenshot shortcuts and macOS menus remain available.

AeroSpace does not provide the Hyprland-style modifier+mouse drag/resize or
modifier+scroll workspace bindings. Monitor-relative workspace variants are
also not useful on this single-display setup.

## Permissions

AeroSpace uses the Accessibility permission already granted on this Mac.
JankyBorders draws its borders without using the Accessibility API. The
right-Command HyprMod rule is optional; Karabiner-Elements is not installed,
and this setup has not requested any additional macOS permissions or changed
SIP.
