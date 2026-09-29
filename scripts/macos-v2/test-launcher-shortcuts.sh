#!/usr/bin/env bash
set -euo pipefail

TEST_TMPDIR="${TMPDIR:-/tmp}"
TEST_TMPDIR="${TEST_TMPDIR%/}"
TEST_DIR="$(mktemp -d "$TEST_TMPDIR/rice-v2-launcher.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT

export PATH="$HOME/.local/bin:$HOME/.homebrew/bin:$HOME/.homebrew/sbin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

fish_binary="$(command -v fish || true)"
if [[ -z "$fish_binary" ]]; then
  echo "Fish is missing. Run scripts/macos-v2/bootstrap-tools.sh." >&2
  exit 127
fi

window_count() {
  local app_running
  app_running="$(/usr/bin/osascript -e 'application "Ghostty" is running')" || return 1
  if [[ "$app_running" != "true" ]]; then
    echo 0
    return
  fi
  /usr/bin/osascript \
    -e 'tell application "System Events" to tell process "Ghostty" to count windows'
}

wait_for_window_count() {
  local minimum="$1"
  local current
  for _ in {1..50}; do
    current="$(window_count 2>/dev/null || true)"
    if [[ "$current" =~ ^[0-9]+$ ]] && ((current >= minimum)); then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

close_test_window() {
  "$HOME/.local/bin/rice-v2-send-ghostty-command" exit >/dev/null 2>&1 || true
}

terminal_baseline="$(window_count)"
terminal_marker="$TEST_DIR/ghostty-terminal-ran"
"$HOME/.local/bin/rice-v2-open-terminal" "$HOME"
if ! wait_for_window_count "$((terminal_baseline + 1))"; then
  echo "The Ghostty launcher did not create a new window." >&2
  exit 1
fi
if ! "$HOME/.local/bin/rice-v2-send-ghostty-command" "touch \"$terminal_marker\""; then
  close_test_window
  exit 1
fi
for _ in {1..50}; do
  [[ -f "$terminal_marker" ]] && break
  sleep 0.1
done
if [[ ! -f "$terminal_marker" ]]; then
  close_test_window
  echo "The new Ghostty window did not execute a shell command." >&2
  exit 1
fi
close_test_window
rm -f "$terminal_marker"

yazi_baseline="$(window_count)"
yazi_before="$(pgrep -x yazi || true)"
"$HOME/.local/bin/rice-v2-open-yazi"
if ! wait_for_window_count "$((yazi_baseline + 1))"; then
  echo "The Yazi launcher did not create a new Ghostty window." >&2
  exit 1
fi
yazi_pid=""
for _ in {1..100}; do
  while IFS= read -r candidate; do
    if [[ -n "$candidate" && $'\n'"$yazi_before"$'\n' != *$'\n'"$candidate"$'\n'* ]]; then
      yazi_pid="$candidate"
      break
    fi
  done < <(pgrep -x yazi || true)
  [[ -n "$yazi_pid" ]] && break
  sleep 0.1
done
if [[ -z "$yazi_pid" ]]; then
  close_test_window
  echo "The E launcher opened Ghostty but did not start Yazi." >&2
  exit 1
fi
if ! /usr/bin/osascript - "$yazi_pid" <<'APPLESCRIPT'
on run argv
  tell application "System Events"
    tell process "Ghostty"
      set frontmost to true
      delay 0.2
      keystroke "q"
    end tell
  end tell
end run
APPLESCRIPT
then
  close_test_window
  echo "Could not quit Yazi after the launcher test." >&2
  exit 1
fi
for _ in {1..50}; do
  kill -0 "$yazi_pid" 2>/dev/null || break
  sleep 0.1
done
if kill -0 "$yazi_pid" 2>/dev/null; then
  close_test_window
  echo "Yazi did not exit after the test quit key." >&2
  exit 1
fi
close_test_window

test_home="$TEST_DIR/home"
test_yazi_directory="$TEST_DIR/yazi working directory"
mkdir -p "$test_home/.config/fish" "$test_home/.local/bin" "$test_yazi_directory"
ln -s "$HOME/.config/fish/config.fish" "$test_home/.config/fish/config.fish"
cat >"$test_home/.local/bin/yazi" <<'FAKE_YAZI'
#!/usr/bin/env bash
set -euo pipefail
for argument in "$@"; do
  case "$argument" in
    --cwd-file=*)
      printf '%s\0' "$RICE_TEST_YAZI_CWD" >"${argument#--cwd-file=}"
      exit 0
      ;;
  esac
done
echo "test Yazi shim did not receive --cwd-file" >&2
exit 1
FAKE_YAZI
chmod u+x "$test_home/.local/bin/yazi"

if ! HOME="$test_home" \
  XDG_CONFIG_HOME="$test_home/.config" \
  PATH="$test_home/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  FASTFETCH_DISABLE=1 \
  RICE_TEST_YAZI_CWD="$test_yazi_directory" \
  "$fish_binary" -l -i -C y -c 'test "$PWD" = "$RICE_TEST_YAZI_CWD"'; then
  echo "Launching Yazi through Fish's y function did not return to its selected directory." >&2
  exit 1
fi

tmux_tmpdir="$TEST_DIR/tmux"
mkdir -p "$tmux_tmpdir"
python3 - "$HOME/.local/bin/rice-v2-fastfetch-console" "$tmux_tmpdir" <<'PY'
import errno
import fcntl
import os
import pty
import select
import shutil
import signal
import struct
import subprocess
import sys
import termios
import time

helper, tmux_tmpdir = sys.argv[1:]
tmux = shutil.which("tmux")
if not tmux:
    raise SystemExit("tmux is required to test the pinned Fastfetch console.")

environment = os.environ.copy()
environment["TMUX_TMPDIR"] = tmux_tmpdir
environment["TERM"] = "xterm-256color"

def run_tmux(*arguments):
    return subprocess.run(
        [tmux, *arguments],
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


pid, terminal = pty.fork()
if pid == 0:
    os.environ.update(environment)
    os.execv(helper, [helper])

fcntl.ioctl(terminal, termios.TIOCSWINSZ, struct.pack("HHHH", 36, 120, 0, 0))
os.set_blocking(terminal, False)
output = bytearray()
session = None
status = None
started = time.monotonic()
try:
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

        sessions = run_tmux("list-sessions", "-F", "#{session_name}")
        if sessions.returncode == 0:
            session = next(
                (
                    name
                    for name in sessions.stdout.splitlines()
                    if name.startswith("rice-v2-fetch-")
                ),
                None,
            )
            if session:
                break

        finished, child_status = os.waitpid(pid, os.WNOHANG)
        if finished:
            status = child_status
            break

    if not session:
        raise SystemExit(
            "The Fastfetch console did not create a tmux session: "
            + output.decode("utf-8", errors="replace")
        )

    panes = run_tmux(
        "list-panes",
        "-t",
        session,
        "-F",
        "#{pane_current_command}",
    )
    pane_commands = panes.stdout.splitlines()
    if panes.returncode != 0 or len(pane_commands) != 2 or "fish" not in pane_commands:
        raise SystemExit(
            f"The pinned console should have Fish and a Fastfetch pane; got {pane_commands!r}."
        )

    os.write(terminal, b"\x02d")
    for _ in range(50):
        readable, _, _ = select.select([terminal], [], [], 0.1)
        if readable:
            try:
                output.extend(os.read(terminal, 8192))
            except BlockingIOError:
                pass
            except OSError as error:
                if error.errno != errno.EIO:
                    raise
        finished, child_status = os.waitpid(pid, os.WNOHANG)
        if finished:
            status = child_status
            break
    if status is None:
        raise SystemExit("The Fastfetch console did not detach cleanly after the test.")
    if not os.WIFEXITED(status) or os.WEXITSTATUS(status) != 0:
        raise SystemExit("The Fastfetch console exited unsuccessfully.")
finally:
    if status is None:
        try:
            os.kill(pid, signal.SIGTERM)
            os.waitpid(pid, 0)
        except ProcessLookupError:
            pass
    run_tmux("kill-server")

print("Pinned Fastfetch console functionality passed with two tmux panes.")
PY

echo "Launcher functionality passed: new Ghostty window, Yazi in Ghostty, Fish handoff, and pinned Fastfetch console."
