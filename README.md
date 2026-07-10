# MacBook Linux Rice

Project folder for turning a MacBook into a keyboard-first, Linux-rice-style development machine.

The current guide and implementation plan live at:

```text
docs/research-and-plan.md
```

The AeroSpace vs yabai decision is documented at:

```text
docs/window-manager-decision.md
```

Live setup status and usage guide:

```text
docs/status.md
docs/user-guide.md
docs/manual-config.md
docs/yabai-migration.md
```

## Project layout

```text
.
├── docs/       # Research, setup guide, decisions, replication notes
├── dotfiles/   # Future tracked config files managed by chezmoi
└── scripts/    # Future bootstrap, install, and macOS defaults scripts
```

## Current direction

Current stack:

- yabai for tiling windows, spaces, animations, and deeper macOS window control.
- skhd for global hotkeys.
- Karabiner-Elements for a HyprMod key that does not break normal Command shortcuts.
- SketchyBar for a custom top bar.
- JankyBorders for focused-window borders.
- Ghostty for the terminal.
- Yazi for terminal file management.
- Starship, zsh, Nerd Fonts, and Nord styling across the setup.
- chezmoi and a Brewfile later for reproducible dotfiles.

`Command+Space` is now the launcher mode. `Command+1..9` switches spaces and `Command+Shift+1..9` moves windows to spaces.

## First implementation

The repo now includes a first dotfile-ready implementation:

```text
Brewfile                         # Homebrew packages, casks, fonts, and services
scripts/bootstrap.sh             # Xcode CLT/Homebrew/Brewfile bootstrap
scripts/install-dotfiles.sh      # Copies dotfiles/home into $HOME with backups
scripts/apply-macos-defaults.sh  # Hides Dock/menu bar and applies keyboard/UI defaults
scripts/start-services.sh        # Starts SketchyBar, borders, yabai, skhd, and Karabiner
scripts/configure-zen.sh         # Applies Nord userChrome/user.js to Zen profiles
scripts/check-yabai-status.sh    # Checks yabai/skhd/SIP/runtime status
dotfiles/home/                   # Config files intended for the user's home directory
```

Apply order:

```sh
scripts/bootstrap.sh
scripts/install-dotfiles.sh
scripts/apply-macos-defaults.sh
scripts/start-services.sh
scripts/configure-zen.sh
scripts/check-yabai-status.sh
```

If standard Homebrew cannot be installed without administrator authentication, `scripts/bootstrap.sh` falls back to user-local Homebrew under `~/.homebrew` and installs GUI apps under `~/Applications`.

The macOS defaults script enables a more Linux-style UI by auto-hiding the Dock and native menu bar. SketchyBar then becomes the visible top bar, while yabai handles tiling/spaces and JankyBorders provides focused-window borders.

HyprMod is implemented as `Command+Option+Control` from the right Command key. Shift is intentionally left outside the base chord so bindings like `HyprMod+Shift+H/J/K/L` and `HyprMod+Shift+1..9` remain distinct.

Manual steps are still required for macOS permissions:

- Grant Accessibility access to yabai, skhd, Karabiner-Elements, SketchyBar, and borders when prompted.
- Grant Input Monitoring to Karabiner-Elements when prompted.
- Karabiner is preconfigured with the `MacBook Linux Rice` profile and `Right Command to HyprMod`.
