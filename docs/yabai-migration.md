# yabai migration

## Current state

- AeroSpace has been stopped, uninstalled, and removed from the active dotfiles.
- `yabai` and `skhd` are installed from `asmvik/formulae`.
- `~/.yabairc` and `~/.skhdrc` are installed.
- SketchyBar now uses `yabai` space events and the workspace indicators are on the top-left to avoid the notch.
- `skhd` and `yabai` launch agents are installed, but macOS is currently blocking both at Accessibility permission.
- After Accessibility is granted, yabai/skhd can run. If `Command+2..9` still does not switch, check how many native macOS Spaces exist with `scripts/check-yabai-status.sh`.

## Permission step

Open:

```text
System Settings -> Privacy & Security -> Accessibility
```

Allow:

```text
/opt/homebrew/bin/yabai
/opt/homebrew/bin/skhd
```

If they are not visible in the list, add them with the `+` button. After granting permission, run:

```sh
scripts/start-services.sh
scripts/check-yabai-status.sh
```

## Animation / scripting addition step

The animation-related yabai features require the scripting addition, and the scripting addition requires partial SIP changes from Recovery.

On this Apple Silicon Mac:

1. Shut down.
2. Hold the power button until startup options appear.
3. Open `Options -> Continue`.
4. In Recovery, open `Utilities -> Terminal`.
5. Run:

```sh
csrutil enable --without fs --without debug --without nvram
```

6. Reboot normally.
7. In macOS, run:

```sh
sudo nvram boot-args=-arm64e_preview_abi
sudo shutdown -r now
```

8. After the reboot, run:

```sh
sudo yabai --load-sa
scripts/start-services.sh
scripts/check-yabai-status.sh
```

The sudoers entry for `sudo yabai --load-sa` has already been created for the installed yabai binary.

Current note: the boot arg has been written to NVRAM, but yabai will still report it as missing until the Mac reboots normally.

For animations, also grant Screen Recording to:

```text
/opt/homebrew/bin/yabai
```

Without the scripting addition, yabai cannot create native macOS Spaces. The bar shows placeholders 1-9, but `Command+2..9` only works for spaces that actually exist. After the scripting addition is enabled, the helper scripts behind `Command+1..9` can create missing spaces automatically.

Current observed state:

```text
yabai and skhd are running.
The scripting addition is loaded.
Native macOS Spaces 1-9 exist.
Command+1..9 switches Spaces through skhd.
```

If Spaces are ever lost after macOS updates or display changes, create Desktops manually with Mission Control:

1. Open Mission Control.
2. Move the pointer to the top Spaces strip.
3. Press the `+` button until Desktop 1 through Desktop 9 exist.
4. Run `scripts/check-yabai-status.sh`.

After those native Spaces exist, `Command+1..9` and `Command+Shift+1..9` work. With the scripting addition loaded, the helper scripts can also create missing spaces automatically.

## Active shortcut model

| Action | Shortcut |
| --- | --- |
| Launcher mode | Command+Space |
| Search apps/files | Command+Space then Space |
| Workspace 1-9 | Command+1..9 |
| Move focused window to workspace 1-9 | Command+Shift+1..9 |
| Open Ghostty | HyprMod+T or Command+Space then T |
| Open Yazi | HyprMod+E or Command+Space then E |
| Open pinned fastfetch console | Command+Space then Y |
| Open Zen | HyprMod+Z or Command+Space then Z |
| Open VS Code | HyprMod+V or Command+Space then V |
| Open btop | HyprMod+R or Command+Space then R |
| Focus windows | HyprMod+H/J/K/L |
| Swap windows | HyprMod+Shift+H/J/K/L |
| Toggle fullscreen zoom | HyprMod+Shift+F |
| Toggle floating | HyprMod+F |
| Balance space | HyprMod+B |
| Close focused window | HyprMod+Q or Command+Q |

HyprMod is still right Command through Karabiner, mapped to `Command+Option+Control`.
