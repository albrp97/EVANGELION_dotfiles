# MacBook Rice v2 — Feature Roadmap

**Status:** In progress. The v2 desktop setup, desktop-cleanliness controls,
initial AeroSpace workspace bindings, first-pass SketchyBar, wallpaper
rotation, and Linux-inspired terminal configuration are implemented.
Automated desktop and terminal functionality checks cover the installed
workflows; physical acceptance remains open for window controls, the bar,
wallpaper appearance, and terminal use. The legacy `dotfiles/macos/` setup is
preserved.

This roadmap describes a fresh MacBook rice based on the current Linux feature
set in [linux-features.md](linux-features.md). The Linux document is the
behavior reference, not a list of Linux packages or commands to copy literally.
Each feature must be adapted to macOS and this computer.

## Guardrails

- Keep the existing `dotfiles/macos/` layer and its scripts intact as the
  legacy setup and reference. Do not remove or replace it as part of this plan.
- Build v2 in a separate source path with a separate install entry point. Decide
  the exact layout before implementation; do not silently redirect the existing
  installer to v2.
- Audit shared configurations before reusing them. A file being in
  `dotfiles/common/` does not automatically make it suitable for the new setup.
- Prefer reversible, user-level macOS settings. Preserve normal authenticated
  login and Keychain behavior. Do not copy Linux automatic login, global sudo
  ticket, systemd, or root-level behavior.
- Do not require SIP changes, app-bundle patching, or broad system permissions
  without a separate design decision and clear recovery steps.
- Keep video conversion, codec, and media-workflow implementation in the
  `resolve-media-tui` repository. This repository may configure launchers or
  application integration only.

## Phase 0 — Inventory and decisions

*Source: Linux reference §§1–3, 9–10.*

### P0-F01 — Record this Mac's baseline

- [ ] Record Mac model, processor architecture, macOS version, storage, and
  current system-integrity settings.
- [ ] Record built-in/external displays, resolutions, refresh rates, docks,
  keyboards, mice, trackpad, audio devices, and the apps already installed.
- [ ] Identify existing login agents, window managers, hotkey tools, and
  package managers before designing replacements.

### P0-F02 — Define the target behavior

- [ ] Decide which Linux behaviors are core requirements, optional, or not
  wanted on this Mac.
- [ ] Choose the intended daily apps and defaults for terminal, shell, browser,
  editor, file manager, media player, and launcher.
- [ ] Decide the modifier-key strategy and identify macOS shortcut conflicts.
- [ ] Record hardware-dependent features separately so the base setup works
  without optional devices or an external display.

## Phase 1 — Reversible setup and configuration ownership

*Source: Linux reference §§1–2, 11.*

### P1-F01 — Create an isolated v2 setup

- [x] Choose a separate v2 dotfiles path and installer entry point without
  changing the legacy macOS installer.
- [ ] Separate shared EVA appearance/configuration from Mac-specific
  configuration, with explicit override rules.
- [ ] Make installation idempotent and support a dry run and component
  selection before it changes the home directory.
- [ ] Back up every replaced file, including symlinks, and document how to
  restore the backups and disable installed services.

### P1-F02 — Bootstrap packages safely

- [x] Inventory required and optional Homebrew formulae, casks, fonts, and
  external applications for the desktop and terminal setup.
- [ ] Skip already-installed software cleanly and report failures without
  leaving a partially configured success state.
- [ ] Require clear confirmation before installing packages or requesting
  administrator authentication; do not use unattended privileged operations.
- [ ] Document package-update and post-upgrade recovery steps.

### P1-F03 — Own and reload configuration

- [ ] Define the source of truth for every config, service, and generated file.
- [ ] Document how to reload or restart each component and how to diagnose
  startup failures.
- [ ] Keep generated caches, app profiles, machine-specific data, and secrets
  out of Git.
- [ ] Add a per-feature recovery procedure for updates that replace or invalidate
  generated configuration.

## Phase 2 — Login session, windows, and input

*Source: Linux reference §§2–4.*

### P2-F01 — Start a stable macOS user session

- [ ] Start rice services through user LaunchAgents after the normal macOS
  login, with predictable ordering and duplicate-process protection.
- [ ] Keep FileVault, Keychain, and normal macOS authentication behavior intact.
- [ ] Define clean start, stop, restart, and failure-recovery behavior.

### P2-F02 — Recreate the EVA window workflow

- [x] Evaluate macOS-compatible window managers and choose one before
  implementing bindings.
- [x] Implement and functionally test a geometry-aware grid: one window fills
  the space; two, three, and four tiled windows form 1:1, 1:2, and 2:2 layouts.
- [ ] Physically verify directional focus, resizing, movement, and auto-grid
  behavior before closing this feature.
- [x] Configure moving, resizing, floating, fullscreen, and balancing windows.
- [ ] Add app/window rules for dialogs, picture-in-picture, media players, and
  other windows that should float or keep a predictable size.
- [ ] Support native Spaces and multiple displays without losing windows when
  displays are connected, disconnected, or the lid is closed.

**v2 choice:** AeroSpace uses its own virtual workspaces, avoids disabling SIP,
and does not need `sudo`. Yabai runs only in float mode to provide
`focus_follows_mouse autofocus`; AeroSpace continues to own tiling and virtual
workspaces. No Yabai scripting addition, `sudo`, or SIP change is used. macOS
requires Accessibility access for both managers. `Command+1..9` switches
workspaces, `Command+Shift+1..9` moves the focused window and follows it,
`Command+Arrow` focuses, `Command+Shift+Arrow` moves, `Command+=/-` resizes,
and `Command+Q` closes the focused window instead of quitting the app.
AeroSpace's window query and move operations are already working on this
account, so no new permission prompt was needed during setup.

**Grid and automatic reflow:** `rice-v2-grid-layout` matches the Linux
`eva-grid` distribution for one through four tiled windows: one full-size
window, then 1:1, 1:2, and 2:2. Beyond four it adds balanced columns with at
most two rows each because AeroSpace nests larger stacks unevenly. AeroSpace
invokes the reflow after window detection, focus changes, and workspace moves.
Dialogs and floating utility windows remain outside the grid.

**Physical window acceptance:** Open separate app windows with `Command+N`
(browser tabs in one window do not create tiles). Confirm the one-window,
1:1, 1:2, and 2:2 layouts as the count grows to four; a fifth window should
add another balanced column. Focus different windows and confirm the active
border is EVA green while inactive borders are dark purple. Test directional
focus/movement, hover over another window to confirm focus follows the mouse,
and use keyboard focus to confirm the pointer follows the focused window.
Also test resizing, float/tiling, fullscreen, and balancing. Run
`scripts/macos-v2/test-yabai-hover-focus.sh` to verify the live Yabai service
is responsive with both focus-follow settings enabled and without taking over
tiling.

- [x] Implement and functionally test the Command+1..9 and
  Command+Shift+1..9 workspace bindings and the bar's active-workspace state.
- [x] Port the compatible Linux/yabai window-management combinations and
  document the macOS-native and single-monitor equivalents.
- [ ] Have the user physically verify the shortcuts before closing this
  feature.

**Physical acceptance:** Ghostty's automatic Secure Input is disabled by
choice to preserve AeroSpace shortcuts during terminal password prompts; this
reduces automatic terminal-password protection, but manual Secure Keyboard
Entry and Secure Input enabled by other apps still block shortcuts. After any
other app's macOS Secure Input ends, press `Command+2`,
`Command+3`, and `Command+1` and confirm the active workspace follows in the
bar. With a disposable window focused, test `Command+Shift+2` and
`Command+Shift+1` and confirm the window moves and focus follows. The
lock-shield overlay is AeroSpace's Secure Input warning; shortcuts are
intentionally unavailable while that macOS security feature is active.

### P2-F03 — Design keyboard, pointer, and gesture controls

- [x] Define and document the compatible keyboard map for window
  focus/movement, workspaces, app launchers, and native macOS actions in
  [macbook-rice-v2-keybindings.md](macbook-rice-v2-keybindings.md).
- [x] Preserve ordinary macOS shortcuts unless an intentional replacement is
  documented and tested.
- [ ] Add mouse drag/resize and trackpad gestures only where they do not
  conflict with system gestures.
- [x] Keep media keys, brightness, volume, and lock-screen controls usable.
- [x] Explain required Accessibility, Input Monitoring, Screen Recording, or
  other permissions and how to revoke them.

## Phase 3 — EVA desktop, launcher, and session panels

*Source: Linux reference §5.*

### P3-F01 — Apply the shared EVA visual system

- [ ] Use the Pastel EVA palette with consistent semantic roles: purple for
  structure, green for active/success states, orange for warnings, and rose
  for destructive/error states.
- [ ] Align supported system controls, terminal, editor, file tools, and
  application themes without forcing unsupported system-wide theming.
- [ ] Choose wallpaper storage, manual selection, and optional rotation with a
  safe fallback if a wallpaper cannot be applied.

### P3-F02 — Build the top bar and app launcher

- [x] Choose a macOS-compatible top-bar implementation and define its layout.
- [x] Port the legacy Mac bar's power icon, clock, workspace dots, battery,
  and weather; intentionally omit its brightness, network, and volume items.
- [x] Add a rounded fixed-width CPU/RAM/SSD percentage capsule with compact
  CPU-chip, database-stack, and SSD icons, equal outer margins, inter-cell
  approximately four-pixel visible spacing, orange 80% warning colors, and
  two-second refresh.
- [x] Keep workspace dots 1–3 visible and reveal higher dots only through the
  highest focused or occupied numbered workspace.
- [x] Install JankyBorders with the EVA green active gradient and dark-purple
  inactive border, managed by a separate v2 LaunchAgent.
- [x] Choose a launcher for applications and common actions, and document its
  key behavior and conflicts.
- [ ] Ensure the bar and launcher recover after sleep/wake, display changes,
  and service restarts.

**v2 choice:** Karabiner-Elements provides the 1.5-second `Command+Space`
leader; Raycast provides app/file search through its native `Option+Space`
hotkey and the leader's second-Space alias. The legacy terminal, Yazi,
Fastfetch, screenshot, and application actions are documented in the v2
keymap. SketchyBar
matches the legacy Mac EVA palette, Nerd Font, rounded item backgrounds,
power/clock/workspace-dot layout, fixed-width CPU/RAM/SSD usage, battery, and
weather indicators, with brightness, network, and volume omitted. AeroSpace supplies the active/inactive workspace
dots. Clicking the power icon opens a native macOS chooser; logout, restart,
and shutdown require explicit confirmation. A user LaunchAgent manages the
SketchyBar process. Startup across an actual logout/login or reboot has not
yet been tested.

**Physical bar acceptance:** Confirm the focused workspace dot is green, other
dots are lavender, and the power, clock, roomy CPU/RAM/SSD capsule, battery, and
weather items are visible with no brightness, network, or volume items. Confirm
the CPU/RAM/SSD cells have equal outer margins and approximately four-pixel
visible inter-cell spacing, and
orange icon/text colors at 80% or higher. Open the power chooser and cancel it, then
verify the confirmation dialog defaults to Cancel for a destructive action.
After a normal logout/login, verify both the bar and JankyBorders start without
an attached shell.
Run `scripts/macos-v2/test-sketchybar-topbar.sh` to verify the live item set,
workspace-dot colors, and that brightness remains absent.

### P3-F03 — Add safe session and power actions

- [x] Provide clearly labeled lock, sleep, display, and rice-service actions
  where macOS exposes reliable interfaces.
- [x] Require deliberate confirmation for logout, restart, and shutdown.
- [ ] Do not add power-profile switching until a supported macOS behavior and
  restore policy are defined.

**v2 implementation:** The top-bar power icon opens a native macOS action
chooser for lock, display off, sleep, 30-minute caffeinate, and restarting the
v2 UI services. Logout, restart, and shutdown are separately confirmed.

### P3-F04 — Keep the desktop blank and hide system bars

- [x] Auto-hide the top menu bar and bottom Dock through macOS Settings;
  leave those settings under user control.
- [x] Hide Finder desktop items and desktop widgets without deleting files.
- [x] Manage the settings through an isolated v2 script with status and restore
  commands.
- [x] Capture and inspect a screenshot to confirm the desktop is clean and the
  bars are hidden when not in use.
- [x] Get user confirmation after visual and interaction testing before marking
  this feature complete.

**Applied on this Mac:** `scripts/macos-v2/apply-desktop-cleanliness.sh` manages
the Finder/widget preferences. Its `restore` command uses the original values
saved at `~/.local/state/macbook-rice-v2/desktop-cleanliness.tsv`.
**User validation:** Confirmed the bars auto-hide/reveal on hover and the
desktop remains free of icons and widgets.

The legacy `scripts/apply-macos-defaults.sh` hides Finder desktop items with
`CreateDesktop=false`. No desktop-widget hiding setting was found in the old
macOS configuration; `docs/research-and-plan.md` only lists Übersicht widgets
as an alternative considered for desktop UI.

### P3-F05 — Rotate the Linux EVA wallpaper set

- [x] Reuse the tracked `wallpapers/` images and keep v2's installed copy
  separate from the legacy macOS wallpaper directory.
- [x] Apply a random wallpaper at desktop-bar startup and rotate every 30
  minutes without selecting the same image consecutively.
- [x] Verify the installed image, active desktop appearance, and rotation with
  an executable functionality test and screenshot.
- [ ] Have the user confirm the wallpaper and top-bar appearance before
  closing this feature.

**Implementation:** `scripts/macos-v2/bootstrap-tools.sh` installs AeroSpace
and builds SketchyBar without `sudo`. Then run
`scripts/macos-v2/install-desktop.sh` to install the isolated v2 configuration
and compile the native wallpaper helper. AeroSpace's official cask removes
quarantine from the non-notarized AeroSpace app only; Gatekeeper remains
enabled. Wallpaper files and user configs are kept separate from the legacy
`dotfiles/macos/` installation.
Run `scripts/macos-v2/test-wallpaper-rotation.sh` to functionally verify that
rotation applies a different image and matches the wallpaper reported for
every active display. Run `scripts/macos-v2/test-aerospace-workspaces.sh` to
exercise Command+1..9, Command+Shift+number, and the bar's active-workspace
state; it restores the originally focused workspace/window afterward.

## Phase 4 — Terminal, shell, and developer workflow

*Source: Linux reference §6.*

### P4-F01 — Standardize the interactive shell

- [x] Use Fish in Ghostty without changing the macOS login shell.
- [x] Configure the shared EVA Starship prompt and Fish startup behavior.
- [ ] Add useful command replacements and shortcuts for file listing, search,
  navigation, Git, and system monitoring.
- [x] Show the Mac-adapted EVA Fastfetch panel on interactive Fish startup and
  allow it to be disabled with `FASTFETCH_DISABLE=1`.

### P4-F02 — Configure terminals and system tools

- [x] Use Ghostty as the primary terminal, run `.command` files in Ghostty by
  default, and keep Terminal.app available as a macOS fallback.
- [x] Apply the Linux EVA palette, the SF Mono Nerd Font, and the macOS EVA
  cursor shader.
- [ ] Configure btop to show useful Mac hardware/session information.
- [x] Configure Fastfetch to show Mac hardware/session details and the EVA-01
  logo.
- [x] Configure Yazi's terminal launcher to open Ghostty in the requested
  directory.
- [x] Suppress macOS's `Last login` banner in new terminal login sessions.

**Terminal installation:** Run `scripts/macos-v2/bootstrap-tools.sh` to install
Ghostty, Fish, Starship, Fastfetch, FFmpeg, Yazi, tmux, Raycast, sevenzip, and
the SF Mono Nerd Font. Then run `scripts/macos-v2/install-desktop.sh` to install
the v2 configuration, shared Starship/Fastfetch/Yazi assets, the shared
`.hushlogin` marker, and Yazi packages. The system login shell is not changed.

**Terminal functionality check:** Run
`scripts/macos-v2/test-terminal-setup.sh`. It validates Ghostty, Fish, Raycast,
tmux, FFmpeg, Yazi's pinned plugins and video registrations, and the quiet-login
marker; it also opens a real Ghostty window and Yazi window through the
launcher helpers. It exercises the Fastfetch greeting and Starship prompt,
verifies Copilot's color wrapper clears inherited `COPILOT_ALLOW_ALL`, launches
Yazi in a pseudo-terminal, tests the Fish `y` directory handoff and local video
metadata, and round-trips an archive with paths containing spaces.

**Physical terminal acceptance:** Use `HyprMod+T` or `HyprMod+Return` to open
Ghostty. Confirm there is no macOS `Last login` banner, then check the EVA
colors, readable Nerd Font icons, Fastfetch panel, Fish/Starship prompt, and
cursor effect. Run `y`, navigate to another folder, and quit to verify Fish
changes directory. In Yazi, test Finder reveal,
Ghostty-in-directory, archive extraction, and zip creation. Run `copilot
--version`, then start a normal Copilot session and confirm its usual approval
prompts still appear.

### P4-F03 — Preserve safe Copilot CLI approvals

- [x] Reuse the Linux ANSI-color mode (`FORCE_COLOR=1`,
  `TERM=xterm-256color`, and unset `COLORTERM`) so Copilot inherits Ghostty's
  EVA palette.
- [x] Keep the CLI's normal approval prompts by default; do not port the Linux
  `--allow-all` wrapper or enable automatic tool approval implicitly.
- [x] Document any optional approval behavior separately from the default
  launcher.

Copilot CLI has built-in palette presets rather than a custom EVA palette. The
Linux launcher did not set a preset; it unsets `COLORTERM` so Copilot's ANSI
colors use the terminal palette. V2 follows that behavior while retaining
normal approval prompts. The v2 Copilot settings hide the home navigation tabs,
and `Ctrl+T` returns expanded reasoning to the compact, muted timeline rows.

## Phase 5 — File, browser, editor, and media workflows

*Source: Linux reference §§7–8.*

### P5-F01 — Make Yazi and Finder work together

- [x] Port the shared Yazi theme, compatible plugins, Git status, smart
  navigation, archive actions, and useful bookmarks.
- [x] Add Finder, Ghostty, and editor open/reveal actions.
- [x] Port the shared video-info plugin, local metadata and frame previews,
  video spotter/fetcher, and duration sorting with FFmpeg on macOS.
- [x] Keep Linux's systemd movie-indexer service and online movie enrichment
  Linux-only; never start Linux service commands on macOS.
- [ ] Keep Finder available and avoid copying Dolphin, Baloo, or Linux mount
  shortcuts literally.

### P5-F02 — Theme the selected apps

- [x] Use Zen as the browser and Visual Studio Code as the editor; port the
  EVA theme, icons, font settings, and launch shortcuts.
- [ ] Apply Zen profile styling safely, backing up existing profile files.
- [ ] Configure supported media and utility apps (for example, qBittorrent or
  LosslessCut) without modifying package-owned app files by default.
- [ ] Define file associations deliberately and keep a simple way to restore
  macOS defaults.

### P5-F03 — Keep external media tools separate

- [ ] Decide whether this Mac needs launchers or app associations for DaVinci
  Resolve and `resolve-media-tui`.
- [ ] Keep conversion, concatenation, codec research, and their implementation
  in `resolve-media-tui`; do not duplicate those tools in this repository.

## Phase 6 — Hardware, screenshots, audio, and updates

*Source: Linux reference §§4, 9–10.*

### P6-F01 — Integrate Mac hardware

- [ ] Tune trackpad and mouse behavior per device without double-applying
  scroll or acceleration changes.
- [ ] Route audio to connected Bluetooth, USB, HDMI, or display outputs only
  when the selected macOS tools can do so reliably.
- [ ] Make media, volume, brightness, and battery state visible and responsive.
- [ ] Use supported macOS power controls; if a workflow temporarily changes
  system performance settings, restore the previous state on success, failure,
  and cancellation.

### P6-F02 — Implement screenshots and clipboard helpers

- [ ] Provide region and full-screen screenshot workflows using native macOS
  mechanisms where possible.
- [ ] Define whether each action saves a file, copies an image, or both.
- [ ] Leave the clipboard unchanged when capture is cancelled and clean up
  temporary files.
- [ ] Document and test the required screen-capture permissions.

### P6-F03 — Provide a safe update workflow

- [ ] Decide whether a Homebrew update helper is needed or documented package
  commands are sufficient.
- [ ] If adding an updater, show pending changes and require confirmation
  before modifying packages.
- [ ] Do not port Arch/AUR/Flatpak staging rules or the Linux global sudo
  timestamp behavior to macOS.

## Phase 7 — Verification and migration

*Source: Linux reference §§11–13.*

### P7-F01 — Verify the complete user workflow

- [ ] Test a clean install and an upgrade install without losing existing
  configs or user data.
- [ ] Test login, service restart, sleep/wake, reboot, Spaces, and display
  hotplug.
- [ ] Test every shortcut, window rule, launcher action, screenshot path,
  clipboard path, and supported app integration.
- [ ] Test backup restoration and removal/disablement of every installed
  LaunchAgent or service.
- [ ] Record a clear manual user-test checklist for each feature and get
  explicit user acceptance before marking that feature complete.
- [ ] Add an executable automated functionality test for every acceptance
  outcome, separate from unit or regression tests.

### P7-F02 — Keep the old setup until v2 is accepted

- [ ] Confirm v2 works on this computer through normal use and after reboot.
- [ ] Keep the legacy `dotfiles/macos/` path available as a rollback/reference
  until the user explicitly accepts the replacement.
- [ ] Only after acceptance, decide whether to make v2 the default installer
  target; document the migration and rollback before changing it.

## Mac-specific decisions still open

- [x] Choose AeroSpace for initial workspace and window management; the full
  geometry-aware layout, app rules, and multi-display workflow remain open in
  P2-F02.
- [ ] Choose an application/action launcher and its key behavior.
- [ ] Which shell and terminal should be the defaults?
- [ ] Which browser, editor, file manager, and media applications should be
  supported?
- [ ] Which bar widgets and system actions are useful on this computer?
- [ ] Which permissions or optional system integrations are acceptable?
- [x] Choose `dotfiles/macos-v2/` and `scripts/macos-v2/` as the v2 source
  roots, with `scripts/macos-v2/install-desktop.sh` as the desktop installer.
- [ ] Define a documented, one-command restore/removal interface for v2.
