# Developer guide

## Visual direction

The rice should stay macOS-native underneath, but visually read like a Linux/EVA-01 terminal setup: dark translucent terminal surfaces, purple structure, green active/safe signals, and orange/rose only for warning or destructive states.

Power-menu inspiration references are saved in:

```text
docs/inspiration/power-menu-system-monitor-card.png
docs/inspiration/power-menu-calendar-weather-card.png
docs/inspiration/power-menu-terminal-dashboard.png
docs/inspiration/power-menu-terminal-fastfetch-dashboard.png
```

Use them as layout inspiration only: terminal panels, clear header, grouped telemetry, Android-like command density, strong spacing, and subtle motion. Keep our palette, avoid Apple-style dialogs, and avoid list/bubble menus for power actions.

## Power dashboard

The power bubble launches a Ghostty terminal dashboard, because SketchyBar popup rows read as a list and raw AppKit panels did not present reliably from the bar/session context.

```text
dotfiles/home/.config/sketchybar/sketchybarrc
dotfiles/home/.local/bin/rice-power-dashboard
dotfiles/home/.local/bin/rice-power-dashboard-tui
dotfiles/home/.config/sketchybar/plugins/power_item.sh
```

Design rules:

- Open/close/toggle through `rice-power-dashboard`; the SketchyBar item only provides the launcher and hover highlight.
- Add a one-shot yabai rule before launch so the dashboard Ghostty window starts small and translucent near the top-left power bubble, then expands via yabai into the full floating grid anchored under that button.
- On close, apply the same origin grid with lower opacity before killing the TUI so it visually collapses back toward the power bubble.
- Add a labelled yabai `window_focused` signal while open so focusing/clicking any non-dashboard window closes the dashboard and then removes the signal.
- Use one Ghostty terminal surface with square panel outlines and a command grid, not row bubbles.
- Size the TUI canvas wide enough to fill the floating Ghostty surface; avoid leaving a large blank terminal area beside the dashboard.
- Keep visible UI text-first: compact labels, `::::` separators, `[KEY]` command hints, and EVA-01 terminal language.
- Enable terminal mouse tracking so tile hover/click feedback works inside Ghostty.
- Close on Escape/Q, clicking the power bubble again, or focusing/clicking outside the dashboard.
- Safe actions may execute immediately: lock, display off, sleep, caffeinate, restart rice services.
- Destructive actions must require confirmation: logout, restart Mac, shutdown.

The older `rice-power-menu` / `rice-power-action` SketchyBar popup scripts are retained as historical fallback helpers, but the live UI should remain the Ghostty dashboard unless the design direction changes again.

## Reusable Ghostty dashboard pattern

Use the power dashboard as the template for future rice dashboards. Keep each dashboard split into a small shell wrapper plus a terminal TUI:

```text
~/.local/bin/rice-<name>-dashboard      # open / close / toggle, yabai rules, process cleanup
~/.local/bin/rice-<name>-dashboard-tui  # drawing, telemetry, mouse/keyboard handling, actions
```

Wrapper checklist:

- Store a PID in `~/.cache/macbook-linux-rice/<name>-dashboard.pid`.
- Give the Ghostty window a unique terminal title and find it through `yabai -m query --windows`.
- Before launch, add a one-shot yabai rule for `app="^Ghostty$"` with `manage=off`, `sub-layer=above`, a small origin `grid`, and low opacity.
- Launch with `open -na Ghostty --args -e "$HOME/.local/bin/rice-<name>-dashboard-tui"`.
- Implement `open`, `close`, and `toggle`; close should remove the focus signal, animate back to the origin grid, then terminate both the TUI PID and the matching Ghostty window PID.

TUI checklist:

- Set the terminal title immediately, for example `\033]0;EVA-01 <NAME> DASH\a`, so the wrapper and yabai can target the right window.
- Draw a tiny boot panel first, then call yabai from inside the TUI to expand to the final grid. This creates the "opens from the bar button" motion.
- Use raw terminal mode, hide the cursor, enable SGR mouse tracking (`?1000`, `?1003`, `?1006`), and always restore terminal state in cleanup.
- Install a uniquely labelled yabai `window_focused` signal after the final draw so clicking/focusing outside closes the dashboard.
- Keep the visual language text-based: dark background, ASCII boxes, `::::` separators, `[KEY]` hints, compact labels, and a 2-row or grid command layout instead of lists or round bubbles.
- Palette rules: purple for structure/borders, green for safe/active states, orange for important prompts, and pink/rose only for dangerous or error states.
- Destructive actions must have an armed confirmation state; safe actions may execute directly.
- Support both mouse and keyboard: hover/click tiles, letter shortcuts, `Esc`/`Q` close, and `Enter` to confirm an armed destructive action.

Recommended layout skeleton:

```text
+--------------------------------------------------------------+
| EVA-01 <NAME> DASH                              mode::terminal |
| AI CORE // <DOMAIN> CONTROL // NO APPLE DIALOGS               |
|--------------------------------------------------------------|
| [ telemetry / state panel ]  [ session / context panel ]      |
|                                                              |
| [ command grid: square text tiles with key hints ]            |
+--------------------------------------------------------------+
```

For consistency, start new dashboards by copying the power dashboard wrapper/TUI, then change only the title, PID file, yabai signal label, telemetry functions, tile list, and action commands.

## Pointer cursor notes

The macOS pointer is intentionally left stock for now. Mousecape was tested with a Rosé Pine/BreezeX recolor, but on this Apple Silicon/macOS setup it reported success while the core Arrow/IBeam remained stock. A Swift overlay cursor was also tested and rejected because it looked poor. Do not auto-start pointer overlays or Mousecape cursor hooks unless a better approach is chosen.
