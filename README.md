# EVA-01 Cross-Platform Rice

Reproducible Pastel EVA-01 dotfiles for macOS and Arch-based Linux, with a shared terminal and application theme plus an OS-specific desktop layer.

## Layout

```text
dotfiles/common/   Shared Starship, Yazi, btop, Fastfetch, Kitty, Copilot,
                   VS Code theme/icons, and Zen browser styling.
dotfiles/macos/    yabai, skhd, SketchyBar, Karabiner, macOS helpers,
                   macOS application settings, and launch agents.
dotfiles/linux/    Hyprland, Noctalia, Fish, Kitty/Ghostty, Code OSS,
                   qBittorrent, staged updates, clipboard/screenshot helpers,
                   and UWSM.
scripts/           Platform bootstrap, installation, Zen, and transparency tools.
```

The installer applies `common` first and the selected platform layer second. A platform file can therefore override a shared default without duplicating the whole home directory.

## Install

Run the bootstrap for the current operating system:

```sh
./scripts/bootstrap.sh
```

The platform can also be selected explicitly:

```sh
./scripts/bootstrap.sh macos
./scripts/bootstrap.sh linux
```

Install the dotfiles with a timestamped backup:

```sh
./scripts/install-dotfiles.sh
```

On Linux, finish the Code OSS transparency bundle after Code OSS is installed:

```sh
./scripts/linux/apply-code-transparency.sh
```

The generated Code OSS bundle stays in `~/.local/share/rice-code-transparent` and is not tracked. Re-run the script after Code OSS updates.

On macOS, apply the system settings and start the rice services:

```sh
./scripts/apply-macos-defaults.sh
./scripts/start-services.sh
```

Zen profiles are detected automatically by the installer. If Zen was installed after the dotfiles, run:

```sh
./scripts/configure-zen.sh
```

## Shared behavior

- Pastel EVA-01 colors are used by Ghostty, Kitty, btop, Starship, Yazi, Fastfetch, VS Code, Zen, qBittorrent, and Copilot.
- `~/bin/copilot` forces the Copilot CLI into the terminal's EVA ANSI palette and enables the existing approval behavior.
- The local VS Code/Code OSS extension provides the `EVA-01 Pastel` color theme and icons.
- Yazi plugins, archive helpers, the Starship header, and Git metadata are shared between both systems.
- Linux uses `~/bin/update` for categorized pacman, AUR, and Flatpak reports. Non-important packages wait three days after first observation; important system packages are due immediately.

## macOS layer

The macOS configuration uses yabai/skhd for tiling and bindings, Karabiner for the right-Command HyprMod, SketchyBar for the top bar, JankyBorders for focus borders, and Ghostty for the terminal.

After installation, grant Accessibility/Input Monitoring permissions to the applications macOS requests. See [docs/user-guide.md](docs/user-guide.md), [docs/manual-config.md](docs/manual-config.md), and [docs/yabai-migration.md](docs/yabai-migration.md).

## Linux layer

The Linux configuration targets CachyOS/Arch with Hyprland under UWSM, Noctalia, Fish, Kitty or Ghostty, Solaar, Satty, and the EVA geometry-aware window grid. The bootstrap installs the available repository dependencies and uses `paru` or `yay` for `zen-browser-bin` when possible.

The Linux Code OSS launcher is `~/bin/code`. It uses the system Code OSS CLI and Electron while loading a patched, user-owned main bundle so package updates do not modify `/usr/lib/code`.

See [docs/user-guide.md](docs/user-guide.md) for the shared workflow and OS-specific shortcuts. The detailed configuration map is in [docs/manual-config.md](docs/manual-config.md).

## Backups and safety

Every dotfile installation preserves existing target files under:

```text
~/.macbook-linux-rice-backup/<platform>/<timestamp>/
```

The repository does not contain generated Code OSS bundles, browser profiles, package caches, or secrets.

Theme roles and the palette update workflow are documented in
[docs/guides/theme-system.md](docs/guides/theme-system.md). Zen browser
chrome and website styling are documented in
[docs/guides/web-styling.md](docs/guides/web-styling.md).
