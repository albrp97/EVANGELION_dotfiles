# EVA-01 theme system guide

The rice uses one shared palette and small platform layers. Shared application
themes live under `dotfiles/common`; Hyprland and macOS desktop colors live
under `dotfiles/linux` and `dotfiles/macos`.

## Palette roles

| Role | Color | Use |
| --- | --- | --- |
| Background | `#0F1020` | Transparent-compatible terminal and editor base |
| Panel/base | `#191724` | Solid panels and terminal ANSI black |
| Surface/overlay | `#1F1D2E` / `#26233A` | Menus, borders, inactive surfaces |
| Identity purple | `#7C5FB8` | Focus, selections, active workspaces, headings |
| Pastel lavender | `#C4A7E7` | Structure, links, types, and secondary emphasis |
| Muted lavender | `#9A86B8` | Inactive labels, comments, hints, and low-priority text |
| Signal green | `#A3D977` | Success, live state, functions, and active borders |
| Soft green | `#6FAF6E` | Secondary green ramps and lower-intensity live state |
| Warning orange | `#F6C177` | Warnings, numbers, cursors, and attention |
| Rose accent | `#D98BC4` | Errors and rare secondary emphasis |

The previous icy blue-gray role was removed. Some APIs still call an ANSI
slot or chart property `blue` because that is the API's protocol name; those
slots now resolve to muted lavender or purple and do not introduce a blue
visual accent.

## Where colors are defined

| Surface | Source |
| --- | --- |
| Starship, Kitty, btop, and Yazi | `dotfiles/common/.config/` |
| Zen browser and websites | `dotfiles/common/zen/` |
| VS Code and Code OSS theme/icons | `dotfiles/common/.vscode/` |
| Linux window borders | `dotfiles/linux/.config/hypr/config/` |
| macOS completion and menu bar | `dotfiles/macos/.zshrc` and `dotfiles/macos/.config/sketchybar/` |
| Palette preview | `theme-preview/` and `docs/eva01-palette.svg` |

The common layer is installed first. The selected OS layer is installed
second, so platform-specific settings can override a shared default without
copying the whole configuration.

## Changing the palette

1. Change the role in every shared consumer that uses it.
2. Update the preview JSON, SVG, and documentation.
3. Update platform aliases, such as the Hyprland color names.
4. Install the selected layer:

   ```sh
   scripts/install-dotfiles.sh linux
   scripts/install-dotfiles.sh macos
   ```

5. Run `scripts/configure-zen.sh` for browser profiles.
6. Restart the affected application. Kitty, btop, Yazi, Zen, and Code OSS
   read most theme files at startup.

For a Linux Code OSS update, rerun
`scripts/linux/apply-code-transparency.sh` only when the application bundle
itself changed. The generated transparency bundle is machine-specific and is
not a palette source.

## Generated and third-party files

Noctalia-generated themes, the user-owned Code OSS bundle, Zen profile
backups, and third-party Sine mods are not authoritative palette sources.
Changing them by hand can be overwritten or can make the result diverge from
the repository. Update the tracked source layer instead, then reinstall or
regenerate the relevant application files.
