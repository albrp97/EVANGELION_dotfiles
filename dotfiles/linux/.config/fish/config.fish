if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end
fish_add_path --prepend "$HOME/bin" "$HOME/.local/bin"
set -g fish_color_error brmagenta

if functions -q update
    functions -e update
end

function update --description 'Run staged package updates'
    command "$HOME/bin/update" $argv
end

function y --wraps yazi --description 'Open Yazi and change directory on exit'
    set -l tmp (mktemp -t yazi-cwd.XXXXXX)
    or return 1

    command yazi $argv --cwd-file="$tmp"
    set -l exit_status $status

    if test $exit_status -eq 0
        if read -z cwd < "$tmp"; and test -n "$cwd"; and test "$cwd" != "$PWD"
            builtin cd -- "$cwd"
        end
    end

    rm -f -- "$tmp"
    return $exit_status
end

if status is-interactive; and type -q starship
    starship init fish | source
end

if test "$TERM" = xterm-ghostty; or test "$TERM" = xterm-kitty
    function __eva_block_cursor --on-event fish_prompt
        printf '\e[2 q'
    end

    function __eva_block_cursor_postexec --on-event fish_postexec
        printf '\e[2 q'
    end
end

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end
