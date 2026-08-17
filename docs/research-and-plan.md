# MacBook Linux-ricing setup plan

## Goal

Turn the MacBook into a keyboard-first development machine that feels close to a Linux Hyprland/i3 rice while staying macOS-safe, reproducible, and ready to become dotfiles later.

Target feel:
- Tiling windows, persistent workspaces, gaps, focus/move/resize shortcuts.
- A custom Nord-themed top bar with workspace indicators.
- Fast app launcher bindings for terminal, Zen Browser, VS Code, Yazi, and close-window.
- A better terminal, Nerd Font, Nord palette, shell prompt, CLI tools, and terminal file manager.
- All config stored in plain files suitable for a future dotfiles repo.

## Research findings

### Window manager and workspaces

Recommended: **AeroSpace**.

Why:
- It is an i3-like tiling window manager for macOS.
- It has plain-text TOML config at `~/.aerospace.toml`.
- It supports workspaces, focus/move/resize/layout commands, app launching via `exec-and-forget`, startup commands, and workspace-change callbacks.
- It does not require disabling SIP, unlike many advanced yabai workflows.
- It can integrate with SketchyBar by triggering events on workspace changes.
- A follow-up comparison against yabai, including official docs and Reddit/community themes, is documented in `docs/window-manager-decision.md`.

Alternative: **yabai + skhd**.

Why not first:
- It is powerful and mature, but advanced space/window control can require partial SIP disable and more fragile permissions.
- `skhd` is useful as a hotkey daemon, but AeroSpace already supports the keybinding layer we need for the first version.

Decision: start with AeroSpace. Revisit yabai only if AeroSpace cannot cover a required workflow, or if we explicitly decide the extra scripting/native-Spaces power is worth the setup and SIP tradeoffs.

### Shortcut strategy

Important caveat: using plain `Cmd-T`, `Cmd-Z`, `Cmd-V`, and `Cmd-Q` globally is technically possible with AeroSpace/skhd-style hotkeys, but it will break core macOS/app shortcuts:
- `Cmd-T`: new tab in browsers/editors/terminal.
- `Cmd-Z`: undo.
- `Cmd-V`: paste.
- `Cmd-Q`: quit app.

Current decision: **do not bind plain Command shortcuts for now**. Create a **HyprMod** key and keep normal macOS `Cmd` behavior intact.

Best options:
1. Map **right Command** to HyprMod via Karabiner-Elements, leaving left Command normal.
2. Map **Caps Lock** to HyprMod, common in Linux ricing.
3. Later, research whether any app-aware/remapping strategy can make plain Command launch bindings usable without breaking common app shortcuts.

Deferred problem: the original desired `Cmd+T`, `Cmd+Z`, `Cmd+V`, `Cmd+E`, and `Cmd+Q` launcher model should be revisited after the base setup works. We need to decide whether to keep HyprMod permanently, use app-specific exceptions, use a modal launcher layer, or intentionally override some macOS defaults.

Initial binding design:

| Action | Initial binding | Deferred plain-Cmd target |
| --- | --- | --- |
| Open terminal | HyprMod+T | Cmd+T |
| Open Zen Browser | HyprMod+Z | Cmd+Z |
| Open VS Code | HyprMod+V | Cmd+V |
| Open Yazi | HyprMod+E | Cmd+E |
| Close focused window | HyprMod+Q | Cmd+Q |
| Workspace 1-9 | HyprMod+1..9 | Cmd+1..9 |
| Move window to workspace | HyprMod+Shift+1..9 | Cmd+Shift+1..9 |
| Focus windows | HyprMod+H/J/K/L | Cmd+H/J/K/L |
| Move windows | HyprMod+Shift+H/J/K/L | Cmd+Shift+H/J/K/L |
| Toggle fullscreen | HyprMod+Shift+F | Cmd+Shift+F |
| Toggle floating | HyprMod+F | Cmd+F |
| Back/forth workspace | HyprMod+Tab | Cmd+Tab |

Implementation detail: Karabiner can turn the chosen physical key into a modifier chord. The first implementation uses `cmd+alt+ctrl` rather than full Hyper because leaving Shift outside the base chord keeps `HyprMod+Shift+...` bindings distinct. This gives a Linux-style Super key without sacrificing normal Mac shortcuts.

### Top bar

Recommended: **SketchyBar**.

Why:
- Fully scriptable macOS status bar replacement.
- Works well with AeroSpace workspace events.
- Can show workspaces, focused workspace, active app, battery, Wi-Fi, clock, media, CPU/memory, and custom scripts.
- Config lives in `~/.config/sketchybar/`, which is dotfile-friendly.

Supporting tool: **JankyBorders**.

Why:
- Adds colored borders around focused/inactive windows.
- Integrates cleanly with AeroSpace startup commands.
- Good visual feedback like Hyprland active border styling.

macOS native menu bar cannot be truly replaced system-wide without compromises, but we can auto-hide the native menu bar and run SketchyBar as the visible top bar.

### Terminal

Recommended: **Ghostty** first.

Why:
- Native macOS terminal with GPU acceleration.
- Plain config in `~/.config/ghostty/config`.
- Homebrew cask exists: `brew install --cask ghostty`.
- Built-in Nerd Font support and easy theme/font settings.

Alternative: **WezTerm** if we later want Lua config, cross-platform behavior, or a more programmable terminal.

Initial terminal look:
- Theme: Nord.
- Font: Hack Nerd Font or JetBrainsMono Nerd Font.
- Font size: tuned after install.
- Cursor: block.
- Shell: zsh initially, with Starship prompt.

Font note: Apple's default Terminal font is SF Mono. It is excellent, but a Nerd Font-patched SF Mono is not a clean Homebrew-standard option. For now, use Hack Nerd Font because SketchyBar already recommends it and it is stable via Homebrew. Later we can test SF Mono plus Symbols Nerd Font fallback, or a manually patched SF Mono Nerd Font if you really want that exact look.

### File manager

Recommended: **Yazi**.

Install with optional preview/search dependencies:

```sh
brew install yazi ffmpeg sevenzip jq poppler fd ripgrep fzf zoxide resvg imagemagick font-symbols-only-nerd-font
```

Config lives in `~/.config/yazi/`.

Initial behavior:
- `HyprMod+E` opens Ghostty running Yazi in the home directory or current project directory.
- Add Yazi plugins later for full borders, chmod, starship integration, and better previews.

### Browser and editor

Browser: **Zen Browser**.

Finding:
- Zen is Firefox-based and available for macOS from the official Zen download/GitHub release.
- Homebrew cask is available as `zen`.

Editor: **VS Code**.

Finding:
- Homebrew cask exists: `brew install --cask visual-studio-code`.
- VS Code settings/keybindings can be dotfile-managed under `~/Library/Application Support/Code/User/`.
- Add Nord theme extension and set the same font family as the terminal.

### Shell and CLI developer tools

Recommended CLI layer:
- `zsh` as the login shell for least friction with macOS.
- `starship` for prompt.
- `fzf`, `zoxide`, `eza`, `bat`, `fd`, `ripgrep`, `jq`, `git-delta`, `btop`, `neovim`, `tmux`, `lazygit`, `yazi`.
- Nord themes/configs for Ghostty, Starship, bat, btop, Yazi, VS Code, and SketchyBar.

### Dotfiles strategy

Recommended: **chezmoi** plus a `Brewfile`.

Why:
- Better than raw symlinks for a Mac because it supports templates, machine-specific values, scripts, and secrets handling.
- Homebrew formula exists: `brew install chezmoi`.
- We can later version:
  - `~/.aerospace.toml`
  - `~/.config/ghostty/config`
  - `~/.config/sketchybar/`
  - `~/.config/yazi/`
  - `~/.config/starship.toml`
  - shell files like `.zshrc`, `.zprofile`, `.gitconfig`
  - VS Code settings/keybindings
  - Karabiner config
  - macOS defaults bootstrap script
  - Brewfile

## Recommended tools and alternatives

### 1. Homebrew

What it is:
- The package manager for macOS.
- Installs CLI tools, GUI apps through casks, fonts, services, and developer dependencies.
- Lets us later create a `Brewfile` so the whole machine can be rebuilt with one command.

Why recommended:
- It is the standard way to install developer tooling on macOS.
- Most tools in this setup are available through it.
- It keeps installs reproducible for dotfiles.

Alternatives:
- **Nix**: more reproducible and Linux-like, but more complex and less native for macOS GUI apps.
- **MacPorts**: solid package manager, but less common in modern Mac developer dotfiles.
- **Manual installers**: sometimes needed for apps like Zen Browser, but worse for reproducibility.

### 2. chezmoi

What it is:
- A dotfiles manager.
- Tracks config files from many locations and applies them safely across machines.
- Supports templates, machine-specific settings, scripts, and secret-aware workflows.

Why recommended:
- Better than raw symlinks for a Mac setup because some files live under `~/.config`, some under `~/Library`, and some need host-specific values.
- Good long-term base for turning this rice into a portable dotfiles repo.

Alternatives:
- **GNU Stow**: simple symlink-based dotfiles manager; great for Linux, less flexible for macOS-specific setup.
- **yadm**: Git-based dotfiles manager; simpler than chezmoi but less template/script focused.
- **Bare Git repo**: minimal and powerful, but easier to mess up and less guided.

### 3. AeroSpace

What it is:
- An i3-like tiling window manager for macOS.
- Provides workspaces, tiling layouts, focus/move/resize commands, app launch shortcuts, callbacks, and plain TOML config.

Why recommended:
- Closest safe macOS equivalent to a Hyprland/i3 workflow.
- Does not require disabling SIP.
- Dotfile-friendly via `~/.aerospace.toml`.
- Integrates with SketchyBar for workspace indicators.

Alternatives:
- **yabai + skhd**: very powerful and scriptable, but advanced features can require partial SIP disable and more fragile permissions.
- **Amethyst**: easier tiling window manager, but less scriptable and less ricing-friendly.
- **Rectangle**: great manual window snapping, but not a full tiling workspace manager.

### 4. Karabiner-Elements

What it is:
- Low-level keyboard remapping tool for macOS.
- Can map a physical key, like right Command or Caps Lock, to a custom Hyper/HyprMod modifier.

Why recommended:
- Lets us get a Linux-like Super/HyprMod key without breaking normal `Cmd` shortcuts.
- Avoids taking over `Cmd+Z`, `Cmd+V`, `Cmd+T`, etc. during the first setup.

Alternatives:
- **AeroSpace direct bindings only**: simpler, but cannot distinguish left/right Command in the way we want.
- **skhd**: hotkey daemon that can bind shortcuts, but does not replace Karabiner for robust modifier remapping.
- **macOS Keyboard settings**: can remap basic modifiers, but not complex Hyper-style behavior.

### 5. SketchyBar

What it is:
- A scriptable macOS status/top bar.
- Can display workspaces, focused workspace, active app, clock, battery, Wi-Fi, media, CPU, memory, and custom scripts.

Why recommended:
- Closest macOS equivalent to a Linux rice bar like Waybar/polybar.
- Works well with AeroSpace events.
- Fully configurable through shell scripts and dotfiles in `~/.config/sketchybar`.

Alternatives:
- **simple-bar with Übersicht**: nice looking and simpler for some setups, but less direct and less shell-native.
- **Übersicht custom widgets**: flexible desktop widgets, but not as direct as a bar replacement.
- **Keep native macOS menu bar**: most stable, but least Linux-riced.

### 6. JankyBorders

What it is:
- A lightweight focused-window border tool for macOS.
- Draws active/inactive colored borders around windows.

Why recommended:
- Gives Hyprland-like active window feedback.
- Integrates with AeroSpace startup commands.
- Nord colors can be applied directly.

Alternatives:
- **AeroSpace without borders**: simpler and fewer moving parts, but less visual feedback.
- **yabai borders**: works well in yabai setups, but we are starting with AeroSpace.
- **No border tool + SketchyBar active app**: stable, but less rice-like.

### 7. Ghostty

What it is:
- A modern native terminal emulator for macOS with GPU acceleration.
- Configured through plain files under `~/.config/ghostty`.

Why recommended:
- Fast, native, modern, and minimal.
- Easy Nord theme and Nerd Font setup.
- Good default behavior with less config than heavier terminals.

Alternatives:
- **WezTerm**: extremely configurable with Lua and cross-platform; better if we want deep programmability.
- **Alacritty**: fast and simple, but less native and fewer built-in conveniences.
- **Kitty**: powerful and scriptable, but less native-feeling on macOS.
- **Apple Terminal**: stable and has SF Mono feel, but much less riceable.

### 8. Hack Nerd Font / JetBrainsMono Nerd Font

What it is:
- A programming font patched with Nerd Font icons.
- Needed for icons in terminal prompts, Yazi, SketchyBar, and CLI tools.

Why recommended:
- Hack Nerd Font is easy through Homebrew and recommended by SketchyBar docs.
- JetBrainsMono Nerd Font is another excellent developer default.

Alternatives:
- **SF Mono**: closest to the default macOS Terminal look, but not a clean Homebrew Nerd Font option.
- **Symbols Nerd Font fallback**: keep SF Mono for text and use Nerd Font symbols separately; may be harder to make consistent everywhere.
- **Monaspace / Iosevka / FiraCode Nerd Font**: good alternatives depending on visual taste.

### 9. Starship

What it is:
- A fast cross-shell prompt.
- Shows Git state, language versions, directory, command status, and other context.

Why recommended:
- Easy to theme with Nord.
- Works with zsh now and other shells later.
- Config lives in `~/.config/starship.toml`.

Alternatives:
- **Powerlevel10k**: very popular and feature-rich for zsh, but zsh-specific and heavier.
- **Oh My Posh**: powerful cross-platform prompt, but more config-heavy.
- **Pure / Spaceship**: simpler zsh prompts, less visually rich.

### 10. zsh

What it is:
- The default shell on modern macOS.

Why recommended:
- Already integrated with macOS.
- Avoids changing the login shell before the rest of the setup is stable.
- Supports Starship, fzf, zoxide, completions, and aliases well.

Alternatives:
- **fish**: friendlier interactive shell with great completions, but not POSIX-like and can complicate scripts.
- **bash**: familiar and portable, but macOS ships an old version unless installed separately.
- **nushell**: interesting structured shell, but too different for a first development-machine setup.

### 11. Yazi

What it is:
- Terminal file manager.
- Supports previews, tabs, search, plugins, and image/media/document preview helpers.

Why recommended:
- Gives a Linux terminal-file-manager workflow.
- Works well launched inside Ghostty with HyprMod+E.
- Config is dotfile-friendly under `~/.config/yazi`.

Alternatives:
- **lf**: lightweight ranger-like file manager; simpler but less visually rich.
- **ranger**: classic Python terminal file manager; mature but slower/heavier.
- **nnn**: extremely fast and minimal; less visual by default.
- **Finder**: native macOS GUI file manager, but not Linux-like.

### 12. Zen Browser

What it is:
- A Firefox-based browser focused on productivity.

Why recommended:
- Fits the desired modern, riced browser workflow better than stock Safari/Chrome.
- Firefox base means many theme/customization options.

Alternatives:
- **Firefox Developer Edition**: stable developer browser with strong customization and easier package availability.
- **Arc**: polished productivity browser, but less open/dotfile-friendly.
- **Brave**: Chromium-based, privacy-oriented, easy Homebrew install.
- **Safari**: best macOS integration and battery life, least riceable.

### 13. Visual Studio Code

What it is:
- Main GUI code editor.

Why recommended:
- Easy Homebrew install.
- Settings and keybindings can be dotfile-managed.
- Nord theme and terminal font can match the rest of the system.

Alternatives:
- **Cursor / Windsurf**: VS Code-like AI editors, if you want more built-in AI tooling.
- **Zed**: fast native editor, good macOS feel, less extension-compatible than VS Code.
- **Neovim**: best terminal-native editor path, but requires a larger config investment.
- **JetBrains IDEs**: powerful full IDEs, heavier and less unified with lightweight rice.

### 14. CLI developer toolkit

What it is:
- Modern replacements and helpers: `fzf`, `zoxide`, `eza`, `bat`, `fd`, `ripgrep`, `jq`, `git-delta`, `btop`, `neovim`, `tmux`, `lazygit`.

Why recommended:
- These are common Linux-rice/dev tools.
- They make terminal navigation, search, Git, file viewing, and monitoring faster and nicer.
- Most can be Nord-themed or integrated into shell aliases.

Alternatives:
- Keep default BSD/macOS tools for maximum simplicity.
- Use GNU coreutils for a more Linux-compatible CLI.
- Use heavier all-in-one environments like Oh My Zsh plugin bundles, though the plan prefers explicit tools.

### 15. Nord theme

What it is:
- A consistent color palette using dark purple/gray backgrounds and muted lavender accents.

Why recommended:
- Available or easy to implement across terminals, editors, bars, prompts, and file managers.
- Calm, readable, and common in Linux ricing.

Alternatives:
- **Catppuccin**: very popular modern pastel palette with excellent app coverage.
- **Tokyo Night**: high-quality dark theme with strong editor/terminal support.
- **Gruvbox**: warmer retro Linux look.
- **Dracula**: broad app support and high contrast.

## Implementation todos

### Phase 1: Bootstrap package management

Create the base install path:
- Install Xcode Command Line Tools if missing.
- Install Homebrew if missing.
- Install chezmoi for future dotfiles management.
- Create an initial Brewfile or package manifest.

### Phase 2: Install core apps and tools

Install:
- AeroSpace.
- Ghostty.
- SketchyBar.
- JankyBorders.
- Karabiner-Elements.
- VS Code.
- Zen Browser through the `zen` Homebrew cask.
- Hack Nerd Font or JetBrainsMono Nerd Font.
- Yazi and preview/search dependencies.
- Shell/dev CLI tools.

### Phase 3: Apply safe macOS system settings

Configure macOS for tiling/keyboard use:
- Enable "Displays have separate Spaces".
- Disable automatic rearranging of Spaces.
- Auto-hide Dock.
- Auto-hide native menu bar if using SketchyBar as the visible bar.
- Increase keyboard repeat speed and reduce initial repeat delay.
- Disable or reduce window animations where safe.
- Enable dragging windows from any point with `ctrl+cmd` if desired.

Manual permission steps will be required for Accessibility/Input Monitoring/Screen Recording depending on the app.

### Phase 4: Configure the HyprMod key

Use Karabiner-Elements to map either:
- right Command -> HyprMod, or
- Caps Lock -> HyprMod.

Default recommendation: right Command -> HyprMod, left Command remains normal.

Then bind AeroSpace shortcuts to that HyprMod chord.

### Phase 5: Configure AeroSpace

Create `~/.aerospace.toml` with:
- Startup commands for SketchyBar and JankyBorders.
- Nord-colored border launch command.
- Gaps and default tiling layout.
- Persistent workspaces 1-9, plus named workspaces if wanted later.
- Focus, move, resize, fullscreen, float, workspace switch, and move-to-workspace bindings.
- App launch bindings:
  - terminal
  - Zen Browser
  - VS Code
  - Yazi in terminal
  - close focused window
- Workspace-change event that updates SketchyBar.
- Optional app-to-workspace rules after we confirm exact app names/bundle IDs.

### Phase 6: Configure Ghostty

Create `~/.config/ghostty/config` with:
- Nord palette/theme.
- Hack Nerd Font or JetBrainsMono Nerd Font.
- Cursor/block settings.
- Window padding.
- Shell integration.
- Sensible copy/paste and tab/window shortcuts that do not conflict with HyprMod.

### Phase 7: Configure shell environment

Create/update:
- `~/.zprofile` for Homebrew path setup.
- `~/.zshrc` for Starship, fzf, zoxide, aliases, and completions.
- `~/.config/starship.toml` with Nord styling.
- Aliases/functions:
  - `y` for Yazi with directory changing on exit.
  - `ls` -> `eza`.
  - `cat` -> `bat` or `bat --paging=never`.
  - Git helpers if useful.

### Phase 8: Configure Yazi

Create `~/.config/yazi/` files:
- `yazi.toml` for manager/preview behavior.
- `keymap.toml` for preferred navigation.
- `theme.toml` using Nord colors.
- Optional plugins after base install works.

Then create a launcher script so HyprMod+E opens Ghostty directly into Yazi.

### Phase 9: Configure SketchyBar

Create `~/.config/sketchybar/` with:
- Nord color variables.
- Workspace items driven by AeroSpace.
- Focused workspace highlight.
- Active app item.
- Clock.
- Battery.
- Wi-Fi.
- Optional CPU/memory/media modules.

Make plugin scripts executable and run SketchyBar as a service.

### Phase 10: Configure VS Code and keep Zen stock

VS Code:
- Install Nord theme extension.
- Set font family/size.
- Set integrated terminal font.
- Add preferred settings and keybindings to dotfiles later.

Zen:
- Keep browser visuals stock so tabs/history/profile data stay managed by Zen.
- Do not track profile CSS or theme preferences unless explicitly requested again.

### Phase 11: Validate the setup

Check:
- HyprMod app launch shortcuts work.
- Workspace switch/move shortcuts work.
- Focus/move/resize works.
- Yazi opens in Ghostty.
- SketchyBar updates when AeroSpace workspace changes.
- JankyBorders highlights focused windows.
- Nord styling is consistent across terminal, bar, prompt, Yazi, and VS Code.

### Phase 12: Convert into dotfiles

Once the setup feels right:
- Initialize chezmoi source directory.
- Add configs gradually.
- Add Brewfile.
- Add macOS defaults script.
- Add bootstrap script.
- Document manual permission steps.
- Test by applying from a clean user profile or dry-run where possible.

This document records the original macOS implementation plan. The current
cross-platform layout and install flow are documented in `README.md`; the
historical file list below is retained as a record of the first implementation.

## First implementation decisions

1. HyprMod physical key: right Command.
2. HyprMod chord: `Command+Option+Control`, intentionally not Shift, so `HyprMod+Shift` bindings remain distinct.
3. Font: Hack Nerd Font first, with JetBrainsMono Nerd Font also installed as an alternative.
4. Zen Browser: managed through the Brewfile with the `zen` cask.
5. Linux-style macOS UI: auto-hide both the Dock and native menu bar. SketchyBar becomes the visible top bar.

## Implemented files

```text
Brewfile
scripts/bootstrap.sh
scripts/install-dotfiles.sh
scripts/apply-macos-defaults.sh
scripts/start-services.sh
dotfiles/macos/.yabairc
dotfiles/macos/.config/karabiner/karabiner.json
dotfiles/macos/.config/karabiner/assets/complex_modifications/hyprmod-right-command.json
dotfiles/macos/.config/ghostty/config
dotfiles/macos/.config/sketchybar/
dotfiles/common/.config/starship.toml
dotfiles/macos/.config/yazi/
dotfiles/macos/.zprofile
dotfiles/macos/.zshrc
```

## Applied state

- Dotfiles have been copied into the home directory with backups under `~/.macbook-linux-rice-backup/`.
- Linux-style macOS defaults have been applied, including auto-hiding the Dock and native menu bar.
- Bootstrap supports user-local Homebrew under `~/.homebrew` when standard Homebrew cannot be installed without administrator authentication.
- Standard Homebrew is installed under `/opt/homebrew`, packages and apps are installed, SketchyBar runs as a Homebrew service, and borders runs through a custom LaunchAgent with Nord colors.
- Karabiner has an active `MacBook Linux Rice` profile that maps right Command to HyprMod.
- AeroSpace was used for the first implementation, then removed during the yabai migration.
- VS Code settings are tracked for Nord and Hack Nerd Font.
- Zen profile visual customization is now provided by the shared `dotfiles/common/zen` layer.
- SketchyBar is topmost with yabai reserving external bar space so windows do not cover it.
- Plain `Command+1..9` and `Command+Shift+1..9` are now intentionally bound for workspace switching and moving windows.
- `Command+Space` now enters a Karabiner leader launcher instead of Spotlight.
- macOS screenshot shortcuts are disabled to prevent `Command+Shift+3` creating Desktop screenshots.
- Desktop icons are hidden and screenshots were removed from the Desktop.
- Trackpad tap-to-click is enabled and pointer speed is set to `1.65`.
- yabai is configured with mouse-follows-focus and focus-follows-mouse.
- `albrp97/artzen-dotfiles` was used as reference for segmented Starship layout, Waybar-like bar grouping, Yazi layout, and Super-style shortcuts while keeping Nord/macOS tooling.
- yabai/skhd are installed and configured, but macOS Accessibility permission is required before their services can stay running.
- yabai animation/scripting-addition features require the documented partial SIP change from Recovery.
