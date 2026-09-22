# Linux Features and Behavior Reference

This document is the behavior contract for the Linux layer of the EVA-01
dotfiles. It covers the Linux-specific files under `dotfiles/linux`, the
shared files installed on Linux from `dotfiles/common`, and the Linux setup
scripts.

The repository is designed for Arch Linux and CachyOS. A path beginning with
`~` is the installed path in the user's home directory. A path beginning with
`dotfiles/` is the source of truth in this repository.

## Status vocabulary

- **Automatic** means the installer, session, or a user service applies it.
- **Manual** means the configuration is installed, but the user must invoke
  the command or application.
- **Optional** means it depends on hardware, a package, or an external
  project.
- **Recovery** means the operation is normally needed after a package update
  or a clean system reinstall.

## 1. Installation and lifecycle

### Bootstrap

`scripts/bootstrap-linux.sh` installs the base Linux environment with pacman.
The package groups are:

| Group | Main components |
| --- | --- |
| Desktop session | Hyprland, UWSM, Noctalia, Fish, Kitty, Ghostty |
| File and terminal workflow | Yazi, Starship, eza, bat, ripgrep, fd, fzf, zoxide, lazygit, tmux |
| System inspection | btop, Fastfetch, jq, neovim |
| Media and previews | FFmpeg, SMPlayer, ImageMagick, Poppler, resvg, Satty |
| Hardware and Wayland | Solaar, grim, slurp, wl-clipboard |
| Development/build | Code OSS, Electron 42, Python, CMake, Meson, Ninja, nlohmann-json, stb |
| Archive support | 7zip |
| AUR applications | `zen-browser-bin` and `losslesscut-bin`, through `paru` or `yay` |

The bootstrap targets Arch-family systems and refuses to run without `pacman`
and `sudo`.

### Layered installation

Run:

```sh
scripts/install-dotfiles.sh linux
```

The installer:

1. Installs `dotfiles/common` first.
2. Installs `dotfiles/linux` second, so Linux files override shared defaults.
3. Creates a timestamped backup under
   `~/.macbook-linux-rice-backup/linux/<timestamp>/`.
4. Configures the Linux sudo session and automatic greetd login.
5. Builds the Noctalia hover-anchor helper. The patched Noctalia binary itself
   is built separately with `scripts/build-noctalia-eva.sh`.
6. Enables Baloo video metadata indexing when available.
7. Assigns SMPlayer to common video and Matroska MIME types.
8. Enables the wallpaper and Yazi video-indexer user timers.
9. Builds the LosslessCut runtime overlay when LosslessCut is installed.
10. Installs the shared Code OSS EVA extension and the PDF extension.
11. Copies repository wallpapers to `~/Pictures/Wallpapers/EVANGELION`.
12. Applies the shared EVA Zen browser profile files when a Linux Zen profile
    already exists, backing up the previous `userChrome.css`,
    `userContent.css`, and `user.js`.

The installer never replaces an existing target without first preserving it in
the backup directory.

### Package-update recovery

These generated or patched runtimes are intentionally user-owned and must be
rebuilt after their package updates:

| Component | Recovery command |
| --- | --- |
| Code OSS transparency | `scripts/linux/apply-code-transparency.sh` |
| LosslessCut EVA theme | `scripts/linux/apply-losslesscut-theme.sh` |
| Patched Noctalia bar | `scripts/build-noctalia-eva.sh` |
| Yazi package plugins | `ya pkg install` |

The generated Code OSS and LosslessCut overlays are not tracked in Git.

## 2. Login, session, and environment

### Automatic login path

The login path is:

```text
greetd -> UWSM -> Hyprland -> Noctalia and session helpers
```

`scripts/configure-linux-greetd.sh` writes the current user's name into
`/etc/greetd/config.toml` and starts:

```text
/usr/bin/uwsm start -e -D Hyprland hyprland.desktop
```

The previous greetd configuration is kept at
`/etc/greetd/config.toml.eva-noctalia-backup`. The change applies after a
reboot or a greetd restart.

Because this is an automatic login, no password is entered during the session
start. GNOME Keyring is not connected to a password-authenticated PAM login by
this repository. Applications such as Vivaldi may therefore ask for the
password of the locked `Default Keyring` when they first need saved secrets.

### UWSM environment

`dotfiles/linux/.config/uwsm/env` provides:

| Variable | Behavior |
| --- | --- |
| `BROWSER=zen-browser` | Default browser for applications that consult the environment |
| `TERM=xterm-kitty` | Terminal identity for session-launched tools |
| `QT_QPA_PLATFORM="wayland;xcb"` | Prefer Wayland while retaining X11 fallback |
| `QT_QPA_PLATFORMTHEME=qt6ct` | Use the Qt platform theme |
| `ELECTRON_OZONE_PLATFORM_HINT=auto` | Let Electron select the Wayland/XWayland path |
| `HYPRCURSOR_THEME=Bibata-Modern-Ice` | Hyprland cursor theme |
| `HYPRCURSOR_SIZE=24` | Hyprland cursor size |
| `XCURSOR_THEME=Bibata-Modern-Ice` | X cursor theme |
| `XCURSOR_SIZE=24` | X cursor size |
| `PATH` | Puts `~/bin` and `~/.local/bin` before system binaries |

The Hyprland launcher variables in
`dotfiles/linux/.config/hypr/config/variables.lua` remain separate from this
environment. In particular, `Super+W` launches the configured Hyprland
browser command (`firefox`), while applications that use `$BROWSER` see
`zen-browser`.

### Hyprland startup

`config/autostart.lua` runs when Hyprland starts:

- Updates the D-Bus activation environment for systemd.
- Starts the user-local Noctalia binary with `LC_TIME=C`.
- Starts `eva-hdmi-audio`.
- Grants local root access to the X server with
  `xhost +SI:localuser:root`.

The `launchPrefix` for GUI applications is `uwsm app --`, so Hyprland
launchers use UWSM-managed application processes.

## 3. Hyprland layout and desktop behavior

### Monitors and workspaces

The current monitor definitions are:

| Role | Output | Behavior |
| --- | --- | --- |
| Primary | `DP-1` | `3440x1440@180`, automatic position and scale |
| TV/audio | `HDMI-A-1` | Workspace `tv-audio` |

There are nine numbered workspaces per monitor. Workspaces 1-4 are persistent
on the primary monitor. The `tv-audio` workspace is persistent on the HDMI
monitor and is kept separate from the numbered workspace workflow.

### EVA geometry-aware grid

The active layout is `lua:eva-grid`, implemented by
`config/grid.lua`.

- One tiled window fills the available workspace.
- Two or more tiled windows are divided into two columns.
- Rows are split between the columns to keep the layout balanced.
- The active window receives a temporary size bias.
- `Super+Equal` increases the active window's bias by 5%.
- `Super+Minus` decreases it by 5%.
- The bias is clamped between `-35%` and `+35%`.
- Focusing a different window resets the bias.
- Directional focus prefers geometrically aligned windows and then nearest
  distance.
- The layout recalculates after opening, closing, moving, or focusing windows.

### Appearance and compositor behavior

`config/decorations.lua`, `config/animations.lua`, and `config/misc.lua`
provide:

- Inner gaps of 3 and outer gaps of 8.
- Three-pixel borders with a green active gradient.
- Lavender inactive borders.
- Rounded corners with radius 10.
- Active opacity `1.0`, inactive opacity `0.94`.
- Compositor blur with size 5 and four passes.
- Sliding window and workspace animations.
- Special-workspace animations from the top and bottom.
- VRR mode 3.
- XWayland zero scaling.
- Suppressed Hyprland update and donation notices.
- Disabled terminal swallowing.

Terminal swallowing is intentionally disabled. Opening SMPlayer, Code OSS, or
another GUI program from Kitty or Yazi must leave the terminal visible.

The Noctalia bar has its own layer rule that disables compositor blur for the
transparent bar while retaining blur elsewhere.

### Input and gestures

`config/inputs.lua` uses adaptive pointer acceleration and defines:

| Gesture | Action |
| --- | --- |
| Four-finger horizontal | Change workspace |
| Three-finger down | Close the active window |
| Three-finger up | Fullscreen |
| Three-finger left | Toggle floating |

The mouse bindings also support dragging a window with `Super+left-click` and
resizing it with `Super+right-click`.

### Window rules

The rules in `config/windowrules.lua` establish these behaviors:

- Picture-in-picture windows float, keep their aspect ratio, use a bounded
  size, and stay pinned.
- Games and Gamescope use the `gaming` workspace and fullscreen behavior.
- Calculators, Satty, settings tools, network/audio tools, and common dialogs
  float and are centered where appropriate.
- SMPlayer floats with a persistent size.
- Dolphin's main window is intentionally not forced to float, so it
  participates in the EVA grid beside Yazi and LosslessCut.
- Modal dialogs, file choosers, upload dialogs, wallpaper choosers, and
  XDG portal dialogs float.
- Terminals, browsers, mpv-compatible players, and image viewers keep their
  own opacity settings.
- Application maximize requests are suppressed.

## 4. Complete Linux keybinding reference

`Super` is the Hyprland main modifier. The bindings are defined in
`dotfiles/linux/.config/hypr/config/binds.lua`.

### Window management

| Shortcut | Behavior |
| --- | --- |
| `Super+Escape` | Kill the focused window |
| `Super+Q` | Close the focused window |
| `Super+Alt+Space` | Toggle floating |
| `Super+D` | Fullscreen |
| `Super+J` | Toggle the current split |
| `Super+Left/Right/Up/Down` | Focus by EVA grid geometry |
| `Alt+Tab` | Cycle to the next window |
| `Super+Tab` | Open Noctalia's window switcher |
| `Super+Shift+Arrow` | Move the active window in that direction |
| `Super+Shift+mouse wheel` | Move the active window to the adjacent monitor |
| `Super+Ctrl+Shift+Left/Right` | Move to the adjacent workspace |
| `Super+Ctrl+Shift+mouse wheel` | Move to the adjacent workspace |
| `Super+Shift+1..9` | Move to numbered workspace 1-9 |
| `Super+Ctrl+Shift+1..9` | Move to the same numbered workspace on the other monitor |
| `Super+left-click` | Drag the active window |
| `Super+right-click` | Resize the active window |
| `Super+Equal` | Increase active grid space |
| `Super+Minus` | Decrease active grid space |
| `Super+keypad zoom controls` | Decrease or increase cursor zoom; raw key codes 82 and 86 |

### Launchers and session panels

| Shortcut | Behavior |
| --- | --- |
| `Super+Shift+E` | Open Dolphin, the default file manager |
| `Super+E` | Open Yazi in Kitty |
| `Super+Shift+Y` | Ask the focused Dolphin window to open its current folder in Yazi |
| `Super+Shift+T` | Open the default file manager; compatibility alias |
| `Super+T` | Open Kitty |
| `Super+Alt+T` | Open `gnome-text-editor` |
| `Super+Shift+C` | Open `gnome-calculator` |
| `XF86Calculator` | Open `gnome-calculator` |
| `Super+W` | Close the active Zen tab when Zen is focused; otherwise launch Firefox |
| `Ctrl+Shift+Escape` | Open btop in Kitty |
| `Super+Space` | Toggle the Noctalia launcher |
| `Super+Period` | Toggle the Noctalia launcher with the `/emo` route |
| `Super+L` | Lock the session through Noctalia |
| `Super+Alt+C` | Toggle the Noctalia session panel |
| `Super+Shift+X` | Toggle the Noctalia control center |

### Hardware and media keys

These bindings are marked locked so they continue to work from lock screens
and other restricted states.

| Key | Behavior |
| --- | --- |
| `XF86AudioRaiseVolume` | Increase volume |
| `XF86AudioLowerVolume` | Decrease volume |
| `XF86AudioMute` | Mute or unmute output |
| `XF86AudioMicMute` | Mute or unmute the microphone |
| `XF86AudioPlay` / `XF86AudioPause` | Toggle media playback |
| `XF86AudioNext` | Next track |
| `XF86AudioPrev` | Previous track |
| `XF86MonBrightnessUp` | Increase brightness |
| `XF86MonBrightnessDown` | Decrease brightness |

### Screenshots, clipboard, and editing

| Shortcut | Behavior |
| --- | --- |
| `Super+P` | Select a region with `slurp`, capture with `grim`, copy PNG with `wl-copy` |
| `Print` | Open Noctalia's region screenshot flow, piped to Satty |
| `Super+Print` | Open Noctalia's fullscreen screenshot flow |
| `Super+Shift+W` | Open the Noctalia wallpaper panel |
| `Super+Shift+V` | Open the Noctalia clipboard panel |
| `Super+A` | Send `Ctrl+A` to the focused application |
| `Super+F` | Send `Ctrl+F` |
| `Super+S` | Send `Ctrl+S` |
| `Super+Z` | Send `Ctrl+Z` |
| `Super+C` | Send `Ctrl+C` |
| `Super+V` | Smart-paste clipboard data |
| `Super+X` | Send `Ctrl+X` |

#### `Super+P` region-capture workflow

1. Press `Super+P`.
2. `slurp` displays the region selector. Click and drag over the area to
   capture, then release.
3. `grim` captures that region as a PNG.
4. `wl-copy` places the PNG in the Wayland clipboard with the
   `image/png` MIME type.
5. The temporary PNG is deleted. No screenshot file is kept on disk.

Press `Escape` or cancel the selector to leave the clipboard unchanged. Paste
the result with `Super+V` in applications that accept image clipboard data.
The smart-paste helper sends `Ctrl+V` for the image path, including image
attachments in applications such as Copilot. This is separate from `Print`,
which opens Noctalia's region capture flow and routes its clipboard image to
Satty, and `Super+Print`, which uses Noctalia's fullscreen capture flow.

The smart-paste helper sends `Ctrl+Shift+V` to Kitty when the clipboard does
not contain an image, because Kitty's native paste action uses that chord. In
other cases it sends `Ctrl+V`, which allows image clipboard data to reach
applications such as Copilot.

Hyprland's `xdph.conf` sets `screencopy.allow_token_by_default = true`, so
screen-capture clients can obtain the normal screencopy permission without an
additional prompt.

### Workspaces

| Shortcut | Behavior |
| --- | --- |
| `Super+1..9` | Focus numbered workspace 1-9 |
| `Super+0` | Focus the HDMI `tv-audio` workspace |
| `Super+Shift+0` | Move the active window to `tv-audio` |
| `Super+Ctrl+1..9` | Focus a relative numbered workspace |
| `Super+Ctrl+Right/Left` | Focus the next or previous workspace |
| `Super+Ctrl+Down` | Focus the next empty workspace on the monitor |
| `Super+mouse wheel` | Scroll through existing workspaces |
| `Super+Ctrl+mouse wheel` | Scroll workspaces using the relative direction |
| `Super+Shift+S` | Move the active window to the special workspace |
| `Super+Alt+S` | Toggle the special workspace |

## 5. Wallpapers, theme, and Noctalia

### Wallpaper behavior

Wallpapers are installed into:

```text
~/Pictures/Wallpapers/EVANGELION
```

`~/.local/bin/rice-random-wallpaper`:

- Reads `RICE_WALLPAPER_DIR` when set.
- Defaults to `~/Pictures/Wallpapers/EVANGELION` and falls back to
  `~/.local/share/macbook-linux-rice/wallpapers` if that directory is absent.
- Accepts JPG, JPEG, PNG, and WebP files.
- Avoids selecting the current wallpaper when more than one image exists.
- Applies the image through `noctalia msg wallpaper-set`.
- Records the selected path in
  `~/.cache/macbook-linux-rice-current-wallpaper`.

The user timer `eva-wallpaper-rotation.timer` runs the service after 30
minutes and then every 30 minutes. Noctalia uses a fade transition.

The wallpaper panel is opened with `Super+Shift+W`. Noctalia greeter
synchronization is disabled, so a wallpaper rotation does not trigger a
polkit password prompt or modify the login greeter.

### Noctalia bar

`dotfiles/linux/.config/noctalia/config.toml` defines a transparent,
full-width, EVA-styled bar with rounded lower corners and capsule groups:

| Position | Contents |
| --- | --- |
| Left | Power, clock, CPU/RAM/GPU, download/upload |
| Center | Dynamic workspace dots |
| Right | Active media, volume, weather, notifications, power profile |

The custom `evangelion/control-center` plugin supplies the widgets. Hovering
a capsule opens the corresponding native Noctalia panel and leaving both the
capsule and panel closes it after a short grace period.

The widgets behave as follows:

- Power opens the session panel.
- Clock shows `HH:MM DD Mon` and opens the calendar.
- CPU, RAM, and GPU open the system panel.
- Download and upload show live rates and open the network panel.
- Workspace dots always show at least workspaces 1-3 and add detected
  workspaces dynamically. The active dot is green; inactive dots are violet.
- Media appears while an MPRIS player is active and opens media controls.
- Volume shows percentage or mute state and opens audio controls.
- Weather shows Celsius and maps weather codes to icons.
- Notifications turn orange when unread entries exist.
- The power-profile pill cycles `performance`, `balanced`, and
  `power-saver` on click. Its labels are `PERF`, `BAL`, and `SAVE`.

The native control center remains responsible for the underlying data and
actions. The plugin adds the EVA presentation, routing, and hover behavior.

The hover behavior uses the installed `eva-vclick` helper and its
`eva-vclick-current` wrapper. They send a Wayland virtual-pointer click at the
current cursor position so a panel opens from the capsule being hovered. The
installer builds this helper from the tracked protocol definition and C
source, requiring `wayland-scanner`, a C compiler, and Wayland client
development files.

### Noctalia session actions

The session panel contains:

| Panel key | Action |
| --- | --- |
| `1` | Lock |
| `2` | Log out |
| `3` | Lock and suspend after three seconds |
| `4` | Reboot after three seconds |
| `5` | Shutdown after three seconds |

The Noctalia shell uses English, metric weather, 1.20 UI scale, the
`Liga SFMono Nerd Font`, visible card/button/input borders, a polkit agent,
and systemd services for launched applications. It uses dark mode with the
custom `eva01` palette, automatic weather location, a 1.10 bar scale, a
35-pixel bar, and no bar shadow or contact shadow.

### EVA Noctalia build

The transparent bar needs the tracked patch in
`patches/noctalia/transparent-bar-no-blur.patch`. It prevents a transparent
bar from asking Hyprland to blur its full surface. Rebuild the user-local
Noctalia binary with:

```sh
scripts/build-noctalia-eva.sh
```

Run this after the initial package bootstrap if `~/.local/bin/noctalia` does
not already exist, and run it again after a Noctalia package update. The
script does not modify the package-managed binary.

The script fetches the pinned Noctalia tag, validates the expected upstream
source, applies the patch, and installs into `~/.local/bin/noctalia`.

## 6. Terminals, shell, and command-line workflow

### Fish

`dotfiles/linux/.config/fish/config.fish`:

- Sources the CachyOS Fish configuration when installed.
- Prepends `~/bin` and `~/.local/bin`.
- Sets Fish errors to bright magenta.
- Defines `update` as a wrapper around `~/bin/update`.
- Defines `y` as a Yazi wrapper that changes the Fish working directory to
  Yazi's exit directory.
- Initializes Starship in interactive shells.
- Forces a block cursor in Kitty and Ghostty.
- Requests the first global sudo ticket in an interactive shell when the EVA
  sudoers drop-in exists.

To apply shell changes without opening a new terminal, run `exec fish`.

The shared `~/.hushlogin` file suppresses the login-shell `Last login` banner
in terminals that start a login shell.

### Kitty

Kitty is the Hyprland default terminal and the terminal used by Yazi launchers.
The Linux configuration:

- Includes the shared EVA-01 Kitty theme.
- Uses `Liga SFMono Nerd Font`.
- Uses a transparent background with opacity `0.60`.
- Enables pixel and momentum scrolling.
- Uses an orange block cursor with a purple cursor trail.
- Disables the close confirmation.
- Maps `Ctrl+C` to copy and clear or interrupt.
- Maps `Ctrl+V` to send the terminal paste control character.
- Maps `Ctrl+Shift+V` to paste from the clipboard.

### Ghostty

Ghostty is available as an alternative terminal with the same EVA palette. It
uses:

- `Liga SFMono Nerd Font`.
- `#0F1020` background and lavender text.
- Orange block cursor with blinking disabled.
- Background opacity `0.70` and blur `76`.
- The tracked orange cursor-smear shader.
- No close confirmation.
- Explicit clipboard bindings for Shift+Insert and Ctrl+Insert.
- A tuned mouse scroll multiplier.

### btop

The btop profile uses the shared EVA-01 Pastel theme with transparent terminal
backgrounds, truecolor, rounded boxes, synchronized output, and Braille graph
symbols. It shows process, memory, network, and CPU boxes, refreshes every
two seconds, sorts processes by memory, displays CPU temperatures in Celsius,
and keeps the terminal background visible.

### Starship, Fastfetch, and Copilot

The shared Starship configuration provides:

- Green OS/user segment.
- Lavender full-path directory segment.
- Orange Git branch and status segment.
- Green success prompt and purple error prompt.
- EVA icons and path substitutions for common directories.

The Linux Fastfetch profile uses the tracked EVA logo and the
`rice-fastfetch-info` helper to show a two-column panel with hardware, OS,
uptime, shell, terminal, weather, power, and update information. It is
available with:

```sh
fastfetch --config ~/.config/fastfetch/config.jsonc
```

The Linux Fish configuration does not invoke Fastfetch automatically.

The shared `~/bin/copilot` wrapper forces terminal ANSI colors, exports
`COPILOT_ALLOW_ALL=true`, and invokes the installed Copilot CLI with
`--allow-all`. This is an intentional convenience setting and means tool
approval prompts are bypassed for that wrapper.

## 7. Yazi file manager

Yazi is available through `Super+E`, the Fish `y` function, and the Dolphin
integration. The Linux configuration is split between:

- `dotfiles/linux/.config/yazi/yazi.toml`
- `dotfiles/linux/.config/yazi/keymap.toml`
- `dotfiles/common/.config/yazi/init.lua`
- `dotfiles/common/.config/yazi/theme.toml`
- `dotfiles/common/.config/yazi/package.toml`
- `dotfiles/common/.config/yazi/plugins/`

### Base behavior

- Layout ratio is `[1, 4, 3]`: small parent, wide current pane, medium
  preview.
- Natural sorting is case-insensitive with directories first.
- Hidden files are initially hidden.
- Git status is the default linemode.
- Symlinks are shown.
- Mouse click and scroll events are enabled, with five lines of scrolloff.
- The window title follows the current directory as `Yazi: <path>`.
- The preview uses large cached image bounds and triangle filtering.
- Preview image quality is 75, with a sixel preview fraction of 15.
- Normal surfaces use the terminal's transparent background so Kitty and
  Hyprland blur remain visible.
- Video files open through SMPlayer.
- Text, JSON, Markdown, shell, Lua, Python, JavaScript, TypeScript, Rust,
  Go, CSS, and HTML open through Code OSS.
- Directories can open in Code OSS, Kitty, or Dolphin.
- Torrents open through qBittorrent.
- Archives offer extraction and ZIP creation.

### Yazi keymap

| Key sequence | Behavior |
| --- | --- |
| `a` | Create a file or extensionless folder |
| `l`, `Right`, `Enter` | Enter a directory or open a file |
| `' h` | Go home |
| `' c` | Go to `~/code` |
| `' d` | Go to `~/Downloads` |
| `' D` | Go to `~/Documents` |
| `' .` | Go to `~/.config` |
| `' p` | Go to `~/Pictures` |
| `' m` | Go to `~/Music` |
| `' v` | Go to `~/Videos` |
| `' t` | Go to `/tmp` |
| `' e` | Mount and enter the Elements HDD |
| `' w` | Mount and enter the Windows partition |
| `; c` | Open the current folder in Code OSS |
| `; t` | Open Kitty in the current folder |
| `; f` | Reveal the hovered item in Dolphin |
| `; s` | Open a shell in the current directory |
| `; o` | Open with the default application |
| `; p` | Smart-paste into the hovered directory or current directory |
| `; /` | Smart filter |
| `; x` | Extract the hovered archive |
| `; z` | ZIP selected files or folders |
| `; Z` | ZIP the hovered file or folder |
| `; v` | Hide or show the preview pane |
| `; V` | Maximize or restore the preview pane |
| `; m` | Change selected file modes with chmod |
| `; g` | Jump to the Git repository root |
| `; .` or `.` | Toggle hidden files |
| `; l g` | Git linemode |
| `; l s` | Size linemode |
| `; l m` | Modified-time linemode |
| `; l n` | No linemode |
| `, l` | Sort the current directory by video duration, shortest first |
| `, L` | Sort the current directory by video duration, longest first |
| `Ctrl+O` | Open the interactive opener selector |

### Installed Yazi plugins

The pinned plugin set provides:

- Smart enter for one key that enters directories or opens files.
- Smart paste into the hovered directory.
- Smart filtering that enters a unique directory or opens a unique file.
- Smart file creation for files and extensionless directories.
- Rounded full-pane borders.
- Git status signs in the file list.
- Starship prompt content in Yazi's header.
- Preview pane show/hide and maximize/restore.
- Unix chmod actions.
- Video metadata, frame previews, movie enrichment, and duration sorting.

### Video metadata and movie enrichment

The shared `video-info.yazi` plugin uses `ffprobe` to display:

- Resolution.
- Frame rate.
- Duration.
- Video codec and profile.
- Pixel format and container.
- Audio codecs, layouts, languages, and track titles.

Yazi's native FFmpeg frame preview remains active above the text details.
Technical metadata is cached by path, file size, and modification time.

For local files below `~/Videos`, the Linux indexer can identify movies from
names such as `Title (Year)` or `Title.Year`. It skips trailers, featurettes,
interviews, commentaries, deleted scenes, and other known extras. When a title
matches:

- Wikidata supplies identity and credits.
- FilmAffinity is queried best effort for rating, synopsis, and additional
  credits.
- Results are persisted in
  `~/.cache/yazi/video-info/movie-cache.json`.

Only normalized title and year values are sent to those public services. The
file contents, absolute path, and media data are not sent. Files outside
`~/Videos` still receive local technical metadata but not online enrichment.

The `eva-video-movie-indexer.timer` runs two minutes after boot and every ten
minutes. Each normal run performs at most ten online movie lookups. Yazi also
starts the service non-blocking when the plugin loads. Use:

```sh
~/.local/bin/rice-yazi-video-indexer --refresh
YAZI_VIDEO_INFO_OFFLINE=1 yazi
```

The first command reprocesses every matching file. The environment variable
disables online enrichment for that Yazi session.

### Archive and storage helpers

The common archive helpers:

- Create ZIP files with `7zz` or `zip`.
- Extract ZIP, RAR, 7z, tar, gzip, bzip2, and xz formats with `7zz`, `7z`, or
  `unar`.
- Create a destination directory based on the archive name.
- Flatten a single nested directory after extraction.
- Add a timestamp when the destination already exists.

The storage shortcuts mount fixed UUIDs with `udisksctl`, then emit a Yazi
directory change:

- Elements HDD: `/dev/disk/by-uuid/36D69E09D69DC98F`.
- Windows partition: `/dev/disk/by-uuid/BC2494582494180A`.

## 8. File manager, media, and desktop applications

### Dolphin integration

Dolphin is the default graphical file manager and is intentionally tiled by
Hyprland. It has:

- `Super+Shift+E` and `Super+Shift+T` launchers.
- A right-click **Open in Yazi** service menu for folders.
- `Super+Shift+Y`, which activates that service menu through Dolphin's D-Bus
  action when Dolphin is focused.

The service menu launches Kitty in the selected directory with Yazi.

### Baloo video metadata

The user-service override at
`~/.config/systemd/user/kde-baloo.service.d/override.conf`:

- Removes the unavailable KDE-only start condition.
- Sets `QT_QPA_PLATFORM=offscreen` for the FFmpeg metadata extractor.

Baloo supplies Dolphin's video **Height**, **Width**, and **Frame Rate**
columns. The installer enables and restarts `kde-baloo.service` when
`balooctl6` is available.

### SMPlayer and mpv

SMPlayer is the default application for common video, Matroska, and related
audio/video MIME types.

The EVA configuration provides:

- Compact dark UI with EVA controls and icons.
- Fusion Qt style.
- Default volume of 30%.
- Preferred audio track 2.
- Saved media settings and playback position.
- A compact window that stays on top, starts playback when a playlist loads,
  and advances automatically through the playlist.
- A default window size of 640x360.
- `Q` and `Ctrl+Q` quit actions.
- Fullscreen and compact-mode actions from the SMPlayer UI.

`rice-smplayer-mpv` removes obsolete X11 keyboard arguments and SMPlayer's
duplicated volume/OSD flags before starting `/usr/bin/mpv`. It:

- Hides mpv's OSD level and seek bar.
- Starts standalone files at 30%.
- Loops a single file.
- Does not force looping when multiple files or a playlist are detected.

### LosslessCut

LosslessCut is launched through `~/bin/losslesscut` and the tracked desktop
entry. The launcher prefers the user-owned EVA overlay at
`~/.local/share/rice-losslesscut` and falls back to the stock package with a
warning if the overlay is missing.

The overlay:

- Makes the Electron window transparent.
- Applies the EVA CSS palette.
- Uses green for primary actions, orange for warnings, and rose for danger
  states.
- Preserves package-managed files through symlinks.

After a LosslessCut package update, rebuild the overlay and restart the app.

### qBittorrent

The qBittorrent theme is a dark EVA Qt stylesheet with:

- Purple selection and progress surfaces.
- Green downloading and successful movement states.
- Lavender uploading and checking states.
- Orange queued and warning states.
- Rose missing-file and error states.
- A matching EVA icon set for connection, transfer, queue, tracker, and
  session actions.

Enable the custom theme in qBittorrent if needed, then restart qBittorrent.

### Vivaldi

The repository installs the EVA-01 theme files under
`~/.config/vivaldi/themes/eva01/`. Import `eva01.zip` from Vivaldi's theme
settings, install the preview if desired, and select **EVA-01**.

The browser uses GNOME Keyring for saved secrets. With automatic greetd login,
the `Default Keyring` may remain locked until its password is entered.

### Zen browser and web styling

Zen is installed from the AUR as `zen-browser-bin` and is the browser named by
the session's `BROWSER=zen-browser` environment variable. The Hyprland
`Super+W` binding remains separate and launches its configured `firefox`
command instead.

When a Linux Zen profile exists, `scripts/configure-zen.sh` copies the shared
files from `dotfiles/common/zen/` into the profile's `chrome/` directory and
backs up the previous files. `user.js` enables legacy custom stylesheets,
`userChrome.css` makes Zen's browser chrome transparent for the wallpaper and
compositor background, and `userContent.css` applies EVA styling to GitHub,
Reddit, Gmail, and YouTube. Run the script again after changing these files,
then fully restart Zen. The detailed selector and troubleshooting rules are
in `docs/guides/web-styling.md`.

### Code OSS

The Linux Code OSS desktop entry and `~/bin/code` wrapper provide:

- A user-owned transparent Electron runtime.
- `VSCODE_TRANSPARENT=1` and `--ozone-platform=wayland` for the generated
  runtime.
- Additional non-comment lines from `~/.config/code-flags.conf` are passed to
  Code OSS before command-line arguments.
- Detached UWSM application launch for normal GUI commands.
- Foreground behavior for `code --wait`, `code -w`, and `--verbose`.
- The standard system Code OSS installation as the source of immutable assets.

The transparency generator:

1. Copies the system `out/main.js`.
2. Patches Electron's `BrowserWindow` to honor `VSCODE_TRANSPARENT=1`.
3. Makes native background updates transparent.
4. Patches the workbench root to `#141218CC`.
5. Copies `node_modules.asar` as a regular file for Electron resolution.
6. Keeps the result in `~/.local/share/rice-code-transparent`.

Run the generator again after Code OSS updates. The desktop entry always routes
graphical launches through `~/bin/code`.

The Code OSS settings provide:

- `EVA-01 Pastel` color theme and EVA icon theme.
- `Liga SFMono Nerd Font`, 14.7pt, medium weight.
- Block cursors with smooth editor caret motion.
- Smooth editor, list, and terminal scrolling.
- Activity bar at the top.
- Hidden breadcrumbs and command center.
- Transparent editor, sidebar, panel, and terminal surfaces.
- EVA Git graph, diff, bracket, control, and warning colors.
- PDF support through `tomoki1207.pdf`.
- Disabled workspace trust prompts and automatic opening of untrusted files.

Linux keybindings inside Code OSS:

| Shortcut | Behavior |
| --- | --- |
| `Super+,` | Toggle the primary sidebar |
| `Super+/` | Toggle the auxiliary sidebar |
| `Super+.` | Toggle the status bar |

### Notes launcher

Run `notes` to open `~/code/notes/txt/Todo.md` through the Code OSS wrapper.
Set `RICE_NOTES_FILE=/path/to/file` to open a different file. Set
`RICE_CODE_LAUNCHER` when a different Code OSS launcher is required.

## 9. Audio, hardware, and power

### PipeWire upmix

The three PipeWire fragments enable simple stereo-to-multichannel upmixing
with:

- LFE cutoff at 150 Hz.
- Front-center cutoff at 12 kHz.
- Rear delay of 12 ms.

The same stream properties are applied to native PipeWire and PulseAudio
compatibility clients.

### Automatic audio routing

`eva-hdmi-audio` runs from Hyprland autostart and listens for PipeWire/Pulse
audio events.

1. If a Bluetooth sink exists, it becomes the default sink.
2. Otherwise the NVIDIA HDMI card is inspected.
3. A TV-like port matching Google TV, BRAVIA, Sony, Android TV, or Television
   is preferred.
4. A 5.1 HDMI surround profile is preferred when available.
5. HDMI stereo is the fallback profile.
6. The resulting sink becomes the default output.

The helper retries after card, sink, or server events and uses a runtime lock
to prevent duplicate instances.

### Logitech mouse

Solaar stores the MX Master 3S configuration, including DPI 1000, ratcheted
scroll mode, SmartShift, and the saved button mappings. The saved mode is
reapplied when the mouse reconnects.

### Flow 2 keyboard Fn layer

The optional `scripts/lofree-flow2-fn.py` helper talks to the keyboard's raw
USB HID/VIA interface. It can:

- Dump the complete keymap to JSON.
- Apply F1-F12 to the number row in Fn layers 1 and 3.
- Verify every written keycode.

It must be run over USB with `pkexec` and does not modify the keyboard unless
`--apply` is provided.

### Power profile

The Noctalia power-profile widget reads and cycles the system profiles through
`powerprofilesctl`:

```text
performance -> balanced -> power-saver -> performance
```

The media preparation workflow in the external `resolve-media-tui` project
also temporarily selects `performance` during conversion when configured to do
so, then restores the previous profile.

## 10. Package updates and privilege behavior

### Staged updater

Run:

```sh
update
```

or force every pending update with:

```sh
update --now
```

The updater:

- Reports pacman, AUR, and Flatpak packages separately.
- Caches status for 15 minutes.
- Holds non-important packages for three days after first observation.
- Makes boot, security, graphics, Wayland, systemd, PAM, sudo, and similar
  packages immediately eligible.
- Updates only packages marked ready during a normal run.
- Lets pacman promote a waiting package only when it is required for a safe
  dependency transition.
- Defers a package when no safe subset can be found.
- Continues with the remaining source if an individual source fails.
- Requires confirmation before modifying packages.

`rice-update-status` stores its cache under
`~/.cache/rice-update-status.json` unless `XDG_CACHE_HOME` changes the base.

### Global sudo session

`scripts/configure-sudo-session.sh` installs a validated,
root-owned `/etc/sudoers.d/90-eva-sudo-session` entry with:

- `timestamp_type=global`
- `timestamp_timeout=-1`

The first interactive Fish shell after a reboot asks for the password and
warms the global ticket. Other terminals reuse the same ticket. `sudo -k`
invalidates it immediately.

This does not grant `NOPASSWD`; an authentication boundary still exists at
the first use of the session.

## 11. Config ownership and reload map

| Feature | Source of truth | Normal reload |
| --- | --- | --- |
| Hyprland | `dotfiles/linux/.config/hypr/` | `hyprctl reload` |
| Noctalia config and palette | `dotfiles/linux/.config/noctalia/config.toml`, `dotfiles/linux/.config/noctalia/palettes/eva01.json` | `noctalia msg config-reload` |
| Noctalia plugin | `dotfiles/linux/.local/share/noctalia/plugins/eva-control-center/` | Restart Noctalia after manifest changes |
| Noctalia hover anchor | `scripts/eva-vclick.c`, `scripts/eva-vclick-current.sh`, `scripts/protocols/` | Re-run `scripts/install-dotfiles.sh linux` when the helper changes |
| Noctalia transparent bar | `patches/noctalia/`, `scripts/build-noctalia-eva.sh` | Rebuild, then restart Noctalia |
| Wallpaper rotation | `rice-random-wallpaper`, `eva-wallpaper-rotation.*` | `systemctl --user restart eva-wallpaper-rotation.timer` |
| Fish | `dotfiles/linux/.config/fish/config.fish` | `exec fish` |
| Login banner | `dotfiles/common/.hushlogin` | Open a new login shell |
| UWSM environment | `dotfiles/linux/.config/uwsm/env` | Log in again or restart the session |
| Kitty | `dotfiles/linux/.config/kitty/kitty.conf` and shared theme | Open a new Kitty window |
| Ghostty | `dotfiles/linux/.config/ghostty/config` | Open a new Ghostty window |
| Starship | `dotfiles/common/.config/starship.toml` | Open a new Fish shell |
| btop | `dotfiles/linux/.config/btop/btop.conf` and shared theme | Restart btop |
| Fastfetch | `dotfiles/linux/.config/fastfetch/config.jsonc` and helper | Run Fastfetch again |
| Yazi | `dotfiles/linux/.config/yazi/`, shared plugins and theme | Restart Yazi |
| Code OSS | `dotfiles/linux/.config/Code - OSS/User/` | Reload the Code OSS window |
| Code OSS launch flags | `dotfiles/linux/.config/code-flags.conf`, `dotfiles/linux/bin/code` | Restart the next Code OSS launch |
| Code OSS transparency | `scripts/linux/apply-code-transparency.sh` | Rebuild after package updates |
| SMPlayer | `dotfiles/linux/.config/smplayer/`, including `input.conf` and `playlist.ini` | Restart SMPlayer |
| Video MIME defaults | `scripts/configure-linux-video-defaults.sh` | Run the script again |
| qBittorrent | `dotfiles/linux/.config/qBittorrent/themes/eva01/` | Restart qBittorrent |
| Vivaldi | `dotfiles/linux/.config/vivaldi/themes/eva01/` | Import/select the theme in Vivaldi |
| Zen and website styling | `dotfiles/common/zen/`, `scripts/configure-zen.sh` | Reapply the script, then fully restart Zen |
| LosslessCut | `dotfiles/linux/.config/losslesscut/eva01.css` | Rebuild the overlay after updates |
| PipeWire | `dotfiles/linux/.config/pipewire/` | Restart the PipeWire user services |
| Screen capture permission | `dotfiles/linux/.config/hypr/xdph.conf` | `hyprctl reload` |
| Solaar | `dotfiles/linux/.config/solaar/config.yaml` | Reconnect the mouse or restart Solaar |
| Dolphin service menu | `dotfiles/linux/.local/share/kio/servicemenus/` | Restart Dolphin |
| Baloo metadata | `dotfiles/linux/.config/systemd/user/kde-baloo.service.d/` | `systemctl --user daemon-reload` and restart Baloo |
| Login session | `scripts/configure-linux-greetd.sh` | Reboot or restart greetd |
| Sudo session | `scripts/configure-sudo-session.sh` | Run the script again |
| Package updater | `dotfiles/linux/bin/update` and `rice-update-status` | Run `update` |

## 12. Expected post-install checklist

A correctly installed Linux session should satisfy the following:

- [ ] greetd starts UWSM-managed Hyprland for the configured user.
- [ ] Noctalia starts with the EVA palette and transparent bar after the
      user-local patched binary has been built.
- [ ] The bar shows clock, workspace dots, system/network metrics, media,
      audio, weather, notifications, and power profile.
- [ ] The wallpaper changes through Noctalia with a fade transition and the
      timer is active.
- [ ] `Super+Arrow` focuses windows using the EVA grid.
- [ ] `Super+Shift+Arrow` moves windows and `Super+Equal/Minus` resizes them.
- [ ] `Super+T` opens Kitty and `Super+E` opens Yazi.
- [ ] Dolphin stays tiled and `Super+Shift+Y` opens its current folder in Yazi.
- [ ] Region screenshots from `Super+P` arrive in the clipboard.
- [ ] Fish initializes Starship and the `y` wrapper changes directories.
- [ ] btop opens with the EVA theme and transparent terminal background.
- [ ] Zen receives the EVA browser and website styles when a profile exists.
- [ ] `code .` returns the shell prompt while `code --wait` remains attached.
- [ ] SMPlayer is the default handler for common video and Matroska types.
- [ ] Yazi shows video dimensions, frame rate, and duration.
- [ ] The Yazi video timer is active and its cache is writable.
- [ ] Bluetooth audio takes priority when connected; HDMI is the fallback.
- [ ] Baloo can populate Dolphin's video metadata columns.
- [ ] `update` distinguishes ready packages from the three-day waiting group.
- [ ] The first Fish shell asks once for sudo after a reboot.

Useful checks:

```sh
systemctl --user --no-pager status eva-wallpaper-rotation.timer
systemctl --user --no-pager status eva-video-movie-indexer.timer
systemctl --user --no-pager status kde-baloo.service
hyprctl monitors
hyprctl workspaces
command -v code
command -v ffprobe
```

## 13. External integrations not owned by this repository

The Linux documentation also describes two workflows whose main source code
lives outside this repository:

- DaVinci Resolve Free, installed from the CachyOS repository.
- `resolve-media-tui`, which provides `resolve-media` and `resolve-concat`.

The dotfiles provide the surrounding launchers, MIME defaults, performance
profile expectations, and media-player behavior, but the conversion and
concatenation implementations must be maintained in the separate
`resolve-media-tui` repository.
