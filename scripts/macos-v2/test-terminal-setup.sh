#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
TEST_TMPDIR="${TMPDIR:-/tmp}"
TEST_TMPDIR="${TEST_TMPDIR%/}"
TEST_DIR="$(mktemp -d "$TEST_TMPDIR/rice-v2-terminal.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT

export PATH="$HOME/.local/bin:$HOME/.homebrew/bin:$HOME/.homebrew/sbin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

FISH_BIN="$(command -v fish)"
FISH_CONFIG="$HOME/.config/fish/config.fish"
GHOSTTY_CONFIG="$HOME/.config/ghostty/config"
STARSHIP_CONFIG="$HOME/.config/starship.toml"
YAZI_CONFIG="$HOME/.config/yazi"
FASTFETCH_CONFIG="$HOME/.config/fastfetch/config.jsonc"
HUSHLOGIN_FILE="$HOME/.hushlogin"
VSCODE_SETTINGS_SOURCE="$ROOT_DIR/dotfiles/macos/Library/Application Support/Code/User/settings.json"
VSCODE_SETTINGS="$HOME/Library/Application Support/Code/User/settings.json"
VSCODE_EXTENSION="$HOME/.vscode/extensions/macbook-linux-rice-eva01-pastel-0.1.0"
COPILOT_SETTINGS_SOURCE="$ROOT_DIR/dotfiles/macos-v2/.copilot/settings.json"
COPILOT_SETTINGS="$HOME/.copilot/settings.json"

for command_name in fish starship fastfetch ffmpeg ffprobe yazi ya tmux copilot code az; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required terminal command: $command_name. Run scripts/macos-v2/bootstrap-tools.sh." >&2
    exit 1
  fi
done

"$SCRIPT_DIR/test-azure-cli-setup.sh"

if [[ ! -d "$HOME/Applications/Visual Studio Code.app" &&
  ! -d "/Applications/Visual Studio Code.app" ]]; then
  echo "Visual Studio Code is missing. Run scripts/macos-v2/bootstrap-tools.sh." >&2
  exit 1
fi
if [[ ! -f "$VSCODE_SETTINGS" ]] ||
  ! cmp -s "$VSCODE_SETTINGS_SOURCE" "$VSCODE_SETTINGS"; then
  echo "VS Code settings are missing or differ from the tracked legacy rice settings. Run scripts/macos-v2/install-desktop.sh." >&2
  exit 1
fi
if [[ ! -f "$VSCODE_EXTENSION/package.json" ||
  ! -f "$VSCODE_EXTENSION/themes/eva01-pastel-color-theme.json" ||
  ! -f "$VSCODE_EXTENSION/icons/eva01-pastel-icon-theme.json" ]]; then
  echo "The EVA-01 VS Code color/icon theme is incomplete. Run scripts/macos-v2/install-desktop.sh." >&2
  exit 1
fi
if ! code --version >/dev/null; then
  echo "The VS Code 'code' CLI did not run successfully." >&2
  exit 1
fi
if ! grep -Fq \
  "cmd-alt-ctrl-v = 'exec-and-forget /usr/bin/open -a \"Visual Studio Code\"'" \
  "$ROOT_DIR/dotfiles/macos-v2/.aerospace.toml"; then
  echo "HyprMod+V is not configured to launch Visual Studio Code." >&2
  exit 1
fi

if [[ ! -d "$HOME/Applications/Raycast.app" && ! -d "/Applications/Raycast.app" ]]; then
  echo "Raycast is missing. Run scripts/macos-v2/bootstrap-tools.sh." >&2
  exit 1
fi

command_handler_id="com.macbook-rice-v2.command-file-opener"
command_handler_app="$HOME/Applications/MacBook Rice V2 Command File Opener.app"
command_handler_info=""
if [[ ! -d "$command_handler_app" ]] || ! command -v duti >/dev/null 2>&1; then
  echo "The Ghostty .command handler is missing. Run scripts/macos-v2/bootstrap-tools.sh and install-desktop.sh." >&2
  exit 1
fi
command_handler_info="$(duti -x .command)"
if [[ "$command_handler_info" != *"$command_handler_id"* ]]; then
  echo "Double-clicked .command files are not assigned to the Ghostty handler." >&2
  exit 1
fi

if [[ -x "$HOME/Applications/Ghostty.app/Contents/MacOS/ghostty" ]]; then
  GHOSTTY_BIN="$HOME/Applications/Ghostty.app/Contents/MacOS/ghostty"
elif [[ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]]; then
  GHOSTTY_BIN="/Applications/Ghostty.app/Contents/MacOS/ghostty"
elif command -v ghostty >/dev/null 2>&1; then
  GHOSTTY_BIN="$(command -v ghostty)"
else
  echo "Ghostty's command-line executable is missing." >&2
  exit 1
fi

for config_path in "$FISH_CONFIG" "$GHOSTTY_CONFIG" "$STARSHIP_CONFIG" "$FASTFETCH_CONFIG"; do
  if [[ ! -f "$config_path" ]]; then
    echo "Missing installed terminal config: $config_path. Run scripts/macos-v2/install-desktop.sh." >&2
    exit 1
  fi
done

if ! grep -Fq "command = $FISH_BIN -l -i" "$GHOSTTY_CONFIG"; then
  echo "Ghostty is not configured to launch the installed Fish binary." >&2
  exit 1
fi
if ! grep -Fq "working-directory = home" "$GHOSTTY_CONFIG" ||
  ! grep -Fq "window-inherit-working-directory = false" "$GHOSTTY_CONFIG"; then
  echo "Ghostty is not configured to open new windows in their requested directory." >&2
  exit 1
fi
if [[ "$(grep -Ec '^[[:space:]]*macos-auto-secure-input[[:space:]]*=[[:space:]]*false[[:space:]]*$' "$GHOSTTY_CONFIG")" -ne 1 ]] ||
  [[ "$(grep -Ec '^[[:space:]]*macos-auto-secure-input[[:space:]]*=' "$GHOSTTY_CONFIG")" -ne 1 ]] ||
  ! grep -Eq '^[[:space:]]*macos-auto-secure-input[[:space:]]*=[[:space:]]*false[[:space:]]*$' \
    "$ROOT_DIR/dotfiles/macos-v2/.config/ghostty/config.in"; then
  echo "Ghostty must disable automatic Secure Input in the installed and tracked v2 configs." >&2
  exit 1
fi
for helper in \
  rice-v2-open-terminal \
  rice-v2-new-ghostty-window \
  rice-v2-send-ghostty-command \
  rice-v2-open-yazi \
  rice-v2-open-fastfetch-console \
  rice-v2-fastfetch-console; do
  if [[ ! -x "$HOME/.local/bin/$helper" ]]; then
    echo "Missing launcher helper: $HOME/.local/bin/$helper. Run scripts/macos-v2/install-desktop.sh." >&2
    exit 1
  fi
done
"$SCRIPT_DIR/test-launcher-shortcuts.sh"
"$SCRIPT_DIR/test-vscode-setup.sh"
"$SCRIPT_DIR/test-zen-shortcut.sh"
if [[ ! -f "$HUSHLOGIN_FILE" ]]; then
  echo "The macOS Last login banner is not suppressed for new terminal sessions." >&2
  exit 1
fi

fish -n "$FISH_CONFIG"
"$GHOSTTY_BIN" +validate-config --config-file="$GHOSTTY_CONFIG"
if ! "$GHOSTTY_BIN" +show-config | grep -Fxq 'macos-auto-secure-input = false'; then
  echo "Ghostty's effective configuration still enables automatic Secure Input." >&2
  exit 1
fi
STARSHIP_CONFIG="$STARSHIP_CONFIG" starship prompt >/dev/null
"$SCRIPT_DIR/test-power-commands.sh"

command_file="$TEST_DIR/command file with spaces.command"
command_marker="$TEST_DIR/command-file-ran"
python3 - "$command_file" "$command_marker" <<'PY'
import os
import shlex
import sys

command_file, marker = sys.argv[1:]
with open(command_file, "w", encoding="utf-8") as script:
    script.write("#!/bin/sh\n")
    script.write(f"printf ran > {shlex.quote(marker)}\n")
os.chmod(command_file, 0o755)
PY
/usr/bin/open "$command_file"
for _ in {1..50}; do
  [[ -f "$command_marker" ]] && break
  sleep 0.1
done
if [[ ! -f "$command_marker" ]]; then
  echo "The default .command handler did not execute the script in Ghostty." >&2
  exit 1
fi

for plugin in chmod full-border git smart-create smart-enter smart-filter smart-paste starship toggle-pane video-info; do
  if [[ ! -f "$YAZI_CONFIG/plugins/$plugin.yazi/main.lua" ]]; then
    echo "Yazi plugin is not installed: $plugin" >&2
    exit 1
  fi
done

cmp -s \
  "$ROOT_DIR/dotfiles/common/.config/yazi/plugins/video-info.yazi/main.lua" \
  "$YAZI_CONFIG/plugins/video-info.yazi/main.lua" || {
  echo "Installed video-info plugin differs from its tracked shared source." >&2
  exit 1
}
cmp -s \
  "$ROOT_DIR/dotfiles/common/.config/yazi/theme.toml" \
  "$YAZI_CONFIG/theme.toml" || {
  echo "Installed Yazi theme differs from its tracked shared source." >&2
  exit 1
}
cmp -s \
  "$ROOT_DIR/dotfiles/macos-v2/.config/yazi/init.lua" \
  "$YAZI_CONFIG/init.lua" || {
  echo "Installed Yazi plugin setup differs from its tracked v2 source." >&2
  exit 1
}
for dependency in smart-enter smart-paste full-border toggle-pane smart-filter chmod git; do
  if ! grep -Fq "use = \"yazi-rs/plugins:$dependency\"" "$YAZI_CONFIG/package.toml"; then
    echo "Yazi package pins are missing: $dependency" >&2
    exit 1
  fi
done
for registration in \
  '{ mime = "video/*", run = "video-info" }' \
  '{ mime = "video/*", run = "video-info", group = "video-info" }'; do
  if ! grep -Fq "$registration" "$YAZI_CONFIG/yazi.toml"; then
    echo "Yazi is missing a video-info preview, fetcher, or spotter registration." >&2
    exit 1
  fi
done
grep -Fq 'on = [ ",", "l" ], run = "plugin video-info duration"' "$YAZI_CONFIG/keymap.toml" || {
  echo "Yazi is missing the ascending video duration shortcut." >&2
  exit 1
}
grep -Fq 'on = [ ",", "L" ], run = "plugin video-info duration-reverse"' "$YAZI_CONFIG/keymap.toml" || {
  echo "Yazi is missing the descending video duration shortcut." >&2
  exit 1
}

if ! diff -u \
  <(grep -vE '^[[:space:]]*(#|$)' "$ROOT_DIR/dotfiles/macos-v2/.config/yazi/package.toml") \
  <(grep -vE '^[[:space:]]*(#|$)' "$YAZI_CONFIG/package.toml"); then
  echo "Installed Yazi package pins differ from their tracked v2 source." >&2
  exit 1
fi

video_fixture="$TEST_DIR/video-info-test.mp4"
ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i "color=c=black:s=32x32:d=2" \
  -an "$video_fixture"
ffprobe_output="$(ffprobe -v error \
  -show_entries format=duration:stream=codec_type,width,height \
  -of json "$video_fixture")"
FFPROBE_JSON="$ffprobe_output" python3 - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["FFPROBE_JSON"])
video = next(
    (stream for stream in data.get("streams", []) if stream.get("codec_type") == "video"),
    None,
)
duration = float(data.get("format", {}).get("duration", 0))
if not video or video.get("width") != 32 or video.get("height") != 32 or duration < 1.5:
    sys.exit("The Yazi video test fixture did not produce readable metadata.")
PY

mkdir -p "$TEST_DIR/source with spaces"
fish_target="$("$FISH_BIN" -c 'string escape -- "$argv[1]"' "$TEST_DIR/source with spaces")"
python3 - "$FISH_BIN" "$fish_target" "$TEST_DIR/source with spaces" <<'PY'
import errno
import fcntl
import os
import pty
import select
import signal
import struct
import sys
import termios
import time

launcher = sys.argv[1]
fish_target = sys.argv[2]
expected_cwd = os.fsencode(sys.argv[3])
pid, terminal = pty.fork()
if pid == 0:
    os.environ.pop("FASTFETCH_DISABLE", None)
    os.environ["TERM"] = "xterm-256color"
    os.execv(launcher, [launcher, "-l", "-i", "-C", f"cd -- {fish_target}"])

fcntl.ioctl(terminal, termios.TIOCSWINSZ, struct.pack("HHHH", 32, 120, 0, 0))
os.set_blocking(terminal, False)
output = bytearray()
started = time.monotonic()
greeting_seen = False
sent_pwd = False
pwd_seen = False
sent_exit = False
status = None
while time.monotonic() - started < 15:
    readable, _, _ = select.select([terminal], [], [], 0.1)
    if readable:
        try:
            output.extend(os.read(terminal, 8192))
        except BlockingIOError:
            pass
        except OSError as error:
            if error.errno != errno.EIO:
                raise
    if b"Hardware" in output and b"Software" in output:
        greeting_seen = True
        if not sent_pwd:
            os.write(terminal, b"pwd\n")
            sent_pwd = True
    if sent_pwd and expected_cwd in output:
        pwd_seen = True
        if not sent_exit:
            os.write(terminal, b"exit\n")
            sent_exit = True
    finished, status = os.waitpid(pid, os.WNOHANG)
    if finished:
        break
else:
    os.kill(pid, signal.SIGTERM)
    os.waitpid(pid, 0)
    sys.stderr.write(output.decode("utf-8", errors="replace"))
    raise SystemExit("Interactive Fish did not finish its Fastfetch greeting.")

if not greeting_seen or not pwd_seen or b"fish" not in output or not os.WIFEXITED(status) or os.WEXITSTATUS(status) != 0:
    sys.stderr.write(output.decode("utf-8", errors="replace"))
    raise SystemExit("Interactive Fish did not show the Fastfetch panel.")
PY

mkdir -p "$TEST_DIR/fake-bin"
cat >"$TEST_DIR/fake-bin/copilot" <<'FAKE_COPILOT'
#!/usr/bin/env bash
set -euo pipefail
printf 'COLORTERM=%s\n' "${COLORTERM-<unset>}"
printf 'FORCE_COLOR=%s\n' "${FORCE_COLOR-<unset>}"
printf 'TERM=%s\n' "${TERM-<unset>}"
printf 'COPILOT_ALLOW_ALL=%s\n' "${COPILOT_ALLOW_ALL-<unset>}"
printf 'ARG_1=%s\n' "${1-<unset>}"
FAKE_COPILOT
chmod u+x "$TEST_DIR/fake-bin/copilot"

copilot_color_env="$(
  env COPILOT_ALLOW_ALL=true COLORTERM=truecolor FORCE_COLOR=0 TERM=xterm-ghostty \
    RICE_TEST_BIN="$TEST_DIR/fake-bin" fish -c '
      source "$HOME/.config/fish/config.fish"
      set -p PATH "$RICE_TEST_BIN"
      copilot --rice-v2-color-test
    '
)"
for expected in \
  "COLORTERM=<unset>" \
  "FORCE_COLOR=1" \
  "TERM=xterm-256color" \
  "COPILOT_ALLOW_ALL=<unset>" \
  "ARG_1=--rice-v2-color-test"; do
  if ! grep -Fqx "$expected" <<<"$copilot_color_env"; then
    echo "Copilot wrapper did not apply '$expected'. Output: $copilot_color_env" >&2
    exit 1
  fi
done

if ! env COPILOT_ALLOW_ALL=true fish -c '
  source "$HOME/.config/fish/config.fish"
  if set -q COPILOT_ALLOW_ALL
    echo "COPILOT_ALLOW_ALL was not cleared by the v2 shell config." >&2
    exit 1
  end
  copilot --version
' >/dev/null; then
  echo "Copilot wrapper failed or did not preserve standard approvals." >&2
  exit 1
fi

for settings_file in "$COPILOT_SETTINGS_SOURCE" "$COPILOT_SETTINGS"; do
  if [[ ! -f "$settings_file" ]] || ! python3 - "$settings_file" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as settings_file:
        settings = json.load(settings_file)
except (OSError, json.JSONDecodeError) as error:
    sys.exit(f"Copilot CLI settings are invalid: {error}")

tabs = settings.get("tabs")
if not isinstance(tabs, dict) or tabs.get("enabled") is not False:
    sys.exit("Copilot CLI home navigation tabs must be disabled.")
PY
  then
    echo "Copilot CLI tab settings are missing or invalid in $settings_file." >&2
    exit 1
  fi
done

mkdir -p "$TEST_DIR/fake-bin" "$TEST_DIR/source with spaces" "$TEST_DIR/unpacked"
printf 'Yazi round-trip test\n' >"$TEST_DIR/source with spaces/file with spaces.txt"
cat >"$TEST_DIR/fake-bin/yazi" <<'FAKE_YAZI'
#!/usr/bin/env bash
set -euo pipefail
for arg in "$@"; do
  case "$arg" in
    --cwd-file=*)
      printf '%s\0' "$RICE_TEST_CWD" >"${arg#--cwd-file=}"
      exit 0
      ;;
  esac
done
echo "test yazi shim did not receive --cwd-file" >&2
exit 1
FAKE_YAZI
chmod u+x "$TEST_DIR/fake-bin/yazi"

mkdir "$TEST_DIR/selected-directory"
RICE_TEST_BIN="$TEST_DIR/fake-bin" \
RICE_TEST_START="$TEST_DIR/selected-directory" \
RICE_TEST_CWD="$TEST_DIR/source with spaces" \
fish -c '
  source "$HOME/.config/fish/config.fish"
  set -p PATH "$RICE_TEST_BIN"
  cd -- "$RICE_TEST_START"
  y
  if test "$PWD" != "$RICE_TEST_CWD"
    printf "Yazi left Fish in '%s' instead of '%s'.\n" "$PWD" "$RICE_TEST_CWD" >&2
    exit 1
  end
'

(
  cd "$TEST_DIR"
  "$HOME/.local/bin/rice-v2-yazi-compress" "source with spaces" >/dev/null
)
cp "$TEST_DIR/source with spaces.zip" "$TEST_DIR/unpacked/"
"$HOME/.local/bin/rice-v2-yazi-extract" "$TEST_DIR/unpacked/source with spaces.zip" >/dev/null
cmp \
  "$TEST_DIR/source with spaces/file with spaces.txt" \
  "$TEST_DIR/unpacked/source with spaces/file with spaces.txt"

mkdir -p "$TEST_DIR/yazi"
cp "$video_fixture" "$TEST_DIR/yazi/video-info-test.mp4"
python3 - "$TEST_DIR/yazi" <<'PY'
import errno
import fcntl
import os
import pty
import select
import signal
import struct
import sys
import termios
import time

target = sys.argv[1]
os.makedirs(target, exist_ok=True)
pid, terminal = pty.fork()
if pid == 0:
    os.environ["TERM"] = "xterm-256color"
    os.execvp("yazi", ["yazi", target])

fcntl.ioctl(terminal, termios.TIOCSWINSZ, struct.pack("HHHH", 32, 120, 0, 0))
output = bytearray()
started = time.monotonic()
sort_sent = False
quit_sent = False
status = None
while time.monotonic() - started < 15:
    readable, _, _ = select.select([terminal], [], [], 0.1)
    if readable:
        try:
            output.extend(os.read(terminal, 8192))
        except OSError as error:
            if error.errno != errno.EIO:
                raise
    elapsed = time.monotonic() - started
    if not sort_sent and b"video-info-test.mp4" in output:
        os.write(terminal, b",l,L")
        sort_sent = True
    if elapsed > 4 and sort_sent and not quit_sent:
        os.write(terminal, b"q")
        quit_sent = True
    finished, status = os.waitpid(pid, os.WNOHANG)
    if finished:
        break
else:
    os.kill(pid, signal.SIGTERM)
    os.waitpid(pid, 0)
    raise SystemExit("Yazi did not exit after receiving its quit key.")

if not os.WIFEXITED(status) or os.WEXITSTATUS(status) != 0:
    sys.stderr.write(output.decode("utf-8", errors="replace"))
    raise SystemExit("Yazi did not load its v2 configuration successfully.")
PY

echo "Terminal functionality checks passed: Ghostty, quiet login, launcher actions, Fish, Starship, Fastfetch, Copilot, Azure CLI, Yazi plugins, and video metadata."
