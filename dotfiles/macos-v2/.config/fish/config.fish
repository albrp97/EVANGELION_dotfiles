fish_add_path --prepend \
    "$HOME/bin" \
    "$HOME/.local/bin" \
    "$HOME/.homebrew/bin" \
    "$HOME/.homebrew/sbin" \
    /opt/homebrew/bin \
    /opt/homebrew/sbin \
    /usr/local/bin \
    /usr/local/sbin

set -gx EDITOR vi
set -gx VISUAL vi
set -gx SHELL (status fish-path)
set -gx STARSHIP_CONFIG "$HOME/.config/starship.toml"
set -e COPILOT_ALLOW_ALL
set -g fish_color_error brmagenta

function shutdown --description 'Shut down macOS immediately'
    command rice-v2-power-menu --shutdown
end

function reboot --description 'Restart macOS immediately'
    command rice-v2-power-menu --reboot
end

function sleep --description 'Put macOS to sleep or wait for a duration'
    if test (count $argv) -eq 0
        command pmset sleepnow
    else
        command sleep $argv
    end
end

function fish_greeting
    if set -q FASTFETCH_DISABLE
        return
    end

    if type -q fastfetch
        fastfetch --config "$HOME/.config/fastfetch/config.jsonc"
        or printf 'Fastfetch startup failed; see the command above.\n' >&2
        echo
    end
end

function y --wraps yazi --description 'Open Yazi and change directory on exit'
    set -l tmp (mktemp -t yazi-cwd.XXXXXX)
    or return 1

    command yazi $argv --cwd-file="$tmp"
    set -l exit_status $status

    if test $exit_status -eq 0
        set -l cwd
        if read -z cwd < "$tmp"; and test -n "$cwd"; and test "$cwd" != "$PWD"
            builtin cd -- "$cwd"
        end
    end

    command rm -f -- "$tmp"
    return $exit_status
end

function copilot --wraps copilot --description 'Run Copilot with terminal colors and standard approvals'
    command /usr/bin/env -u COLORTERM FORCE_COLOR=1 TERM=xterm-256color copilot $argv
end

if status is-interactive; and type -q starship
    starship init fish | source
end

if test "$TERM" = xterm-ghostty; or test "$TERM" = xterm-kitty
    function __rice_v2_block_cursor --on-event fish_prompt
        printf '\e[2 q'
    end

    function __rice_v2_block_cursor_postexec --on-event fish_postexec
        printf '\e[2 q'
    end
end
