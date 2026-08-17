if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end
fish_add_path --prepend "$HOME/bin" "$HOME/.local/bin"

if functions -q update
    functions -e update
end

function update --description 'Run staged package updates'
    command "$HOME/bin/update" $argv
end

if status is-interactive; and type -q starship
    starship init fish | source
end

if test "$TERM" = xterm-ghostty
    function __eva_ghostty_block_cursor --on-event fish_prompt
        printf '\e[2 q'
    end

    function __eva_ghostty_block_cursor_postexec --on-event fish_postexec
        printf '\e[2 q'
    end
end

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end
