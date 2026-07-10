# MacBook Linux rice user guide

## Core idea

This setup makes macOS behave like a keyboard-first Linux rice while keeping normal left Command shortcuts intact.

- **yabai** handles tiling windows and spaces.
- **skhd** handles global window-manager hotkeys.
- **Karabiner** handles HyprMod and the `Command+Space` leader launcher.
- **Right Command** acts as **HyprMod**.
- **SketchyBar** replaces the visible top bar.
- **JankyBorders** highlights the focused window through a custom LaunchAgent.
- **LinearMouse** tunes the MX Master 3S scroll direction and wheel feel without changing the trackpad.
- **Ghostty**, **Yazi**, **Starship**, and the pastel EVA-01 palette provide the terminal workflow.
- **VS Code fake transparency** uses a blurred EVA wallpaper behind semi-transparent workbench surfaces, with breadcrumbs hidden so the active filename only appears in the tab.
- **macOS system UI** uses dark mode, purple controls/highlights, and wallpaper-tinted transparency where Apple exposes safe settings.

## HyprMod

HyprMod is right Command mapped through Karabiner to:

```text
Command + Option + Control
```

Shift is not part of the base chord, so `HyprMod+Shift` remains available for moving windows.

## Main shortcuts

| Action | Shortcut |
| --- | --- |
| Open Ghostty | HyprMod+T |
| Open Ghostty | Command+Space, then T or Enter |
| Open pinned fastfetch console | Command+Space, then Y |
| Open Zen | HyprMod+Z |
| Open Zen | Command+Space, then Z |
| Open VS Code | HyprMod+V |
| Open VS Code | Command+Space, then V |
| Open Yazi in Ghostty | HyprMod+E |
| Open Yazi in Ghostty | Command+Space, then E |
| Close focused window | HyprMod+Q or Command+Q |
| Focus left/down/up/right | Command+Arrow |
| Move/swap window left/down/up/right | Command+Shift+Arrow |
| Grow focused window width | Command+= |
| Shrink focused window width | Command+- |
| Toggle floating/tiled | HyprMod+F |
| Focus left/down/up/right | HyprMod+H/J/K/L |
| Swap window left/down/up/right | HyprMod+Shift+H/J/K/L |
| Workspace 1-9 | Command+1..9 |
| Move window to workspace 1-9 | Command+Shift+1..9 |
| Toggle fullscreen | HyprMod+Shift+F |
| Balance layout | HyprMod+B |
| Search apps/files with Raycast | Command+Space, then Space |
| Region screenshot to clipboard | Command+Space, then S |

## macOS bars

The setup auto-hides the native Dock and menu bar. SketchyBar is pinned topmost at the top edge with a transparent bar background and solid EVA bubbles for widgets. yabai reserves exact external bar space plus a very small top padding so tiled windows sit close to the bar without colliding with it. The bar follows the reference rice layout: power, compact date/time, and workspace circles on the left, with volume, brightness, weather, then battery as the rightmost bubble. Workspace circles are purple except the active one, which is green. Wi-Fi, CPU, and RAM are intentionally hidden to avoid clutter. Battery text is green at 70% or higher, orange while charging below 95% or below 30%, and purple otherwise. Plug/unplug changes update through SketchyBar's power-source event instead of waiting for polling.

Click the power bubble to open the EVA power dashboard in Ghostty. It animates out from the power-button area into a terminal-style grid and collapses back toward the button when closed. It is not an Apple dialog and not a SketchyBar list. It shows live battery/display/session status, can lock the screen, turn the display off, sleep, toggle a 30-minute caffeinate session, restart the rice services, or arm logout/restart/shutdown confirmations. Click a command tile or press its letter; press Escape/Q, click the power bubble again, or click/focus outside the dashboard to close it.

Desktop icons are hidden. Screenshot shortcuts are disabled so `Command+Shift+1..9` can be used for moving windows without creating screenshots. `Command+Space` is the rice launcher on built-in and the current Flow2/Lofree Bluetooth keyboard; native Spotlight's own shortcut is disabled so it cannot steal the chord. Press Space again to open Raycast as the Spotlight replacement. Launcher keys also work if Command is still held, so `Command+Space`, then `Command+T`, opens Ghostty.

LinearMouse owns mouse scroll behavior and starts at login through the rice LaunchAgent. It reverses vertical wheel scrolling for mouse-category devices while leaving the MacBook trackpad alone, and the tracked per-device profiles add a smoothed scroll curve where needed so the wheel feels less jumpy than stock macOS. If macOS prompts for permissions, grant LinearMouse Accessibility access.

With yabai, workspaces are native macOS Desktops. `Command+2..9` works only after those Desktops exist. Either create them manually in Mission Control or enable the yabai scripting addition so the helper scripts can create missing spaces.

The SketchyBar workspace dots are intentionally conservative: the bar only draws dots up to the highest primary-display workspace that is currently in use. A space counts as "in use" when it is visible, focused, or contains at least one window. That keeps the bar compact when only workspace 1 is active, while still expanding naturally as you start using workspaces 2, 3, and beyond.

## External monitor and lid close

When a dock or external display is connected, `rice-display-route` prefers the external display, moves normal windows there, and keeps focus on it. The MacBook panel is no longer force-disabled in software, because that path proved unreliable on this macOS/display stack and could leave the laptop screen unavailable after undocking. For true single-screen behavior, use normal macOS clamshell mode by closing the lid while power, dock, keyboard, and mouse stay connected.

## Terminal workflow

- `ls`, `ll`, and `la` use `eza`.
- `cat` uses `bat`.
- `grep` uses `ripgrep`.
- `top` uses `btop`, and `btop` inherits the tracked `eva01-pastel` theme with transparent Ghostty background, lavender structure, green live metrics, orange warning ramps, and rose high-usage peaks.
- `lg` opens Lazygit.
- `y` opens Yazi and changes the shell directory to the directory where Yazi exits. `Command+Space`, then `E`, opens Yazi directly in Ghostty. `Command+Space`, then `Y`, opens a dedicated Ghostty/tmux console with fastfetch pinned in a top pane and an interactive shell below it. Yazi is forced to the same `#0F1020` base surface as VS Code, uses full separator borders, shows Starship in the header, and marks Git status in EVA colors.
- zsh uses ghost-text autosuggestions, live completion menus, syntax highlighting, and Carapace command completions. Completion UI colors are forced through the EVA palette: purple/lavender for values, green for valid commands/highlights, orange for warnings, rose for errors, and muted frost for descriptions. `Right Arrow` moves the cursor normally, `Command+Right` accepts the full ghost suggestion, `Option+Right` accepts/moves by the next word, `Tab` inserts/enters the best completion, and `Down` opens or moves through the completion menu.
- New interactive terminal sessions show a fastfetch splash once, using the ArtZen-style `#` HANKA ROBOTICS logo recolored through the EVA palette, with a two-column essentials panel underneath. It hides the username/host title, removes GPU/usage clutter, shows total RAM and simple battery percent, and adds concise weather. Run `FASTFETCH_DISABLE=1 exec zsh` to suppress it for that session.
- Ghostty, VS Code, and SketchyBar use `Liga SFMono Nerd Font`, a Nerd-patched SF Mono variant close to Apple's default terminal font. Ligatures are disabled where supported so it stays squared and terminal-like; Ghostty uses macOS font thickening and VS Code uses weight `500` at size `14.7` for a slightly heavier, larger read.
- New terminal windows suppress the macOS `Last login` banner through `~/.hushlogin`.
- `copilot` starts with `--allow-all` automatically in interactive zsh sessions; `COPILOT_ALLOW_ALL=true` is also exported for tool approvals.
- Starship uses a green user segment, a lavender current-directory segment, an orange Git branch/status segment, an orange final cap, and a green `❯` prompt. Runtime segments are not forced into the main bar, so empty powerline blocks do not appear.

### Yazi keys

| Key | Action |
| --- | --- |
| `'h` / `'c` / `'d` / `'D` / `'.` | Jump to Home, `~/Documents/code`, Downloads, Documents, or `~/.config` |
| `l`, Right, Enter | Smart enter: enter folders, open files |
| `\c` / `\t` / `\f` | Open current folder in VS Code, open Ghostty here, reveal hovered file in Finder |
| `\x` / `\z` / `\Z` | Extract hovered archive into a same-named folder, zip selected files/folders, or zip hovered item |
| `\v` / `\V` | Toggle the preview pane, or maximize/restore preview |
| `\/` / `\p` / `\m` | Smart filter, smart paste into hovered folder, chmod selected files |
| `\lg` / `\ls` / `\lm` / `\ln` | Switch line mode to Git, size, modified time, or none |

## Theme and wallpapers

The active theme is **Pastel EVA-01**: Rosé Pine/Nord softness with EVA-01 identity. The palette reference lives at `docs/eva01-palette.png` and `docs/eva01-palette.svg`.

Color importance:

| Family | Use |
| --- | --- |
| Purple 38% | Identity, focused UI, active workspaces, keywords/headings |
| Green 20% | Active window border, success/live indicators, functions, links |
| Dark surfaces 22% | Wallpaper-compatible backgrounds, panels, terminals |
| Lavender 8% | Wallpaper highlight, strings, types/classes |
| Orange 5% | Numbers, warnings, rare attention |
| Rose/magenta 4% | Errors and rare secondary neon |
| Text/frost 3% | Foreground and muted labels |

`wallpapers/` contains the selected wallpaper set. `rice-random-wallpaper` chooses one randomly on demand, and `scripts/start-services.sh` applies one immediately at startup. The display-route helper reapplies the cached wallpaper when monitors change so plugged-in screens repaint correctly. Automatic rotation runs every 30 minutes through a hidden SketchyBar timer item, not a LaunchAgent, so macOS does not add a separate “background activity” notification for it.

## Screenshots

`Command+Space`, then `S`, starts macOS region selection and copies the selected image directly to the clipboard. Drag the region, release, then paste with `Command+V`.

## Trusted downloads blocked by Gatekeeper

For a trusted installer that macOS blocks with “Apple could not verify this is free of malware”, run:

```sh
rice-open-trusted-download ~/Downloads/file-name
```

This bypasses quarantine for that one file only. Gatekeeper stays enabled globally.

## VS Code

VS Code uses the local **EVA-01 Pastel** theme extension from `~/.vscode/extensions/macbook-linux-rice-eva01-pastel-0.1.0`. The token colors are tuned for Markdown, JSON, and Python:

- Markdown headings/JSON keys/keywords use pastel purple for identity.
- The main terminal/Copilot foreground is warm white, matching the VS Code editor text. Purple is reserved for structure, secondary text, borders, and selected surfaces.
- Functions, Markdown links, list markers, Copilot status dots, and selected chat accents use EVA green.
- Strings use a deeper pastel purple `#B48DDB` so Python, JSON, and Markdown string values are visibly violet without becoming neon.
- Markdown bold text, numbers/constants, warnings, the Ghostty/VS Code cursors, primary buttons, progress bars, active controls, menu selections, and small hover/focus outlines use soft orange because they are important but should stay rare.
- Comments and quotes use Nord-frost muted blue with italics.
- Errors use rose/magenta sparingly.
- Copilot chat, inline chat, ghost text, quick input, panels, sidebar, and editor surfaces share the same translucent `#0F1020` base so the file tree and code area look uniform. Copilot surfaces favor purple borders/backgrounds, green avatars/inline accents, and only small orange details.
- Brackets use a high-contrast EVA sequence instead of the default rainbow: orange, green, pink, lavender, purple, deep purple. The file explorer uses the local **EVA-01 Pastel Icons** theme with green folders plus purple/lavender file icons.
- Git/SCM visuals are forced into the EVA palette too: graph lanes start orange/green/pink/purple, branch/reference pills avoid VS Code blue, added diffs use EVA green, deleted diffs use rose, and title/tab/toolbar surfaces stay on the dark purple-tinted base.

VS Code fake transparency is applied by `scripts/apply-vscode-background.sh`. It generates a blurred/dimmed background from `wallpapers/09.jpg`, injects a CSS file into the VS Code app bundle, ad-hoc re-signs the modified app, clears quarantine, and makes the theme surfaces translucent enough to reveal it. Re-run the script after VS Code updates or pass a different wallpaper path to change the image.

Ghostty uses the same `#0F1020` base with `background-opacity = 0.70`, `background-opacity-cells = true`, `background-blur = 76`, an orange block cursor, and a subtle purple/orange cursor-trail shader at `~/.config/ghostty/shaders/eva-cursor-trail.glsl`. The close confirmation is disabled so `Command+Q` exits without an extra dialog. The shell integration cursor feature is disabled so zsh/apps do not turn the prompt cursor back into a bar. On macOS, opacity, cursor-shape, and shader changes require a full Ghostty restart, not just a config reload. VS Code uses the same orange block cursor in the editor and integrated terminal.

Finder and System Settings cannot be fully recolored through supported macOS APIs, so they keep Apple’s dark surfaces while using the rice’s purple accent and selection highlight.

## Zen

Zen was clean-reinstalled and is left visually stock. The rice does not manage Zen profile CSS, themes, tabs, history, or browser preferences.

## Trackpad and focus

Tap-to-click is enabled, physical clicking remains enabled, and pointer speed is set about 10% faster than the default target. yabai is configured with mouse-follows-focus and focus-follows-mouse. The macOS pointer is intentionally left stock after Mousecape and overlay approaches proved unreliable or visually poor on this setup.

## Manual configuration

See `docs/manual-config.md` for each configurable tool, its config path, and reload command.

## Manual activation

- Install packages first with `scripts/bootstrap.sh`. If standard Homebrew cannot install without administrator authentication, the script uses user-local Homebrew under `~/.homebrew`.
- Run `scripts/install-dotfiles.sh` after package installation if configs need to be refreshed.
- Run `scripts/apply-macos-defaults.sh` after changing macOS UI defaults.
- Run `scripts/start-services.sh` after package installation to start SketchyBar, borders, yabai, skhd, and Karabiner.
- Zen is installed by `scripts/bootstrap.sh`; the rice only maps `HyprMod+Z` and `Command+Space`, then `Z`, to open `/Applications/Zen.app`.
- Karabiner is preconfigured with the `MacBook Linux Rice` profile and `Right Command to HyprMod`.
- Grant Accessibility permissions to yabai, skhd, Karabiner-Elements, SketchyBar, and borders.
- Grant Input Monitoring to Karabiner-Elements.
- See `docs/yabai-migration.md` for the yabai Accessibility and partial-SIP animation steps.

## Current status

The dotfiles, Homebrew packages, app installs, macOS defaults, Karabiner profile, SketchyBar, borders, and yabai/skhd configs have been applied. The Dock and native menu bar are hidden. yabai/skhd still need macOS Accessibility permission before their services can stay running.
