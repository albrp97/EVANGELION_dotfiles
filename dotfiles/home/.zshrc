if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif [[ -x "$HOME/.homebrew/bin/brew" ]]; then
  eval "$("$HOME/.homebrew/bin/brew" shellenv)"
fi

export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-code --wait}"
export BAT_THEME="Nord"
export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export COPILOT_ALLOW_ALL="true"
export LS_COLORS="di=38;2;163;217;119:ln=38;2;196;167;231:ex=38;2;163;217;119:fi=38;2;216;199;255:*.md=38;2;196;167;231:*.markdown=38;2;196;167;231:*.json=38;2;180;141;219:*.toml=38;2;180;141;219:*.yml=38;2;180;141;219:*.yaml=38;2;180;141;219:*.py=38;2;180;141;219:*.sh=38;2;163;217;119:*.zsh=38;2;163;217;119:*.png=38;2;246;193;119:*.jpg=38;2;246;193;119:*.jpeg=38;2;246;193;119:*.webp=38;2;246;193;119:or=38;2;217;139;196:mi=38;2;217;139;196:ma=48;2;75;58;104;38;2;242;234;255"

if [[ -r /opt/homebrew/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh ]]; then
  zmodload zsh/terminfo 2>/dev/null || true
  zstyle ':autocomplete:*' min-input 1
  zstyle ':autocomplete:*' delay 0.05
  zstyle ':autocomplete:*:*' list-lines 8
  zstyle ':autocomplete:*complete*:*' insert-unambiguous yes
  zstyle ':autocomplete:*:unambiguous' format $'%{\e[38;2;140;169;191m%}common:%{\e[0m%} %{\e[38;2;180;141;219m%}%d%{\e[0m%}'
  zstyle ':completion:*:*' matcher-list 'm:{[:lower:]-}={[:upper:]_}' '+r:|[.]=**'
  zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
  zstyle ':completion:*' menu select
  zstyle ':completion:*' group-name ''
  zstyle ':completion:*:descriptions' format $'%{\e[38;2;180;141;219m%}%B%d%b%{\e[0m%}'
  zstyle ':completion:*:messages' format $'%{\e[38;2;140;169;191m%}%d%{\e[0m%}'
  zstyle ':completion:*:warnings' format $'%{\e[38;2;246;193;119m%}%d%{\e[0m%}'
  zstyle ':completion:*:corrections' format $'%{\e[38;2;246;193;119m%}%d%{\e[0m%}'
  source /opt/homebrew/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
  zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
  zstyle ':completion:*:descriptions' format $'%{\e[38;2;180;141;219m%}%B%d%b%{\e[0m%}'
  zstyle ':completion:*:messages' format $'%{\e[38;2;140;169;191m%}%d%{\e[0m%}'
  zstyle ':completion:*:warnings' format $'%{\e[38;2;246;193;119m%}%d%{\e[0m%}'
  zstyle ':completion:*:corrections' format $'%{\e[38;2;246;193;119m%}%d%{\e[0m%}'
fi

alias ls="eza --icons=auto --group-directories-first"
alias ll="eza -lah --icons=auto --group-directories-first --git"
alias la="eza -a --icons=auto --group-directories-first"
alias cat="bat --paging=never"
alias grep="rg"
alias top="btop"
alias lg="lazygit"

copilot() {
  "$HOME/bin/copilot" "$@"
}

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

if command -v carapace >/dev/null 2>&1; then
  export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
  source <(carapace _carapace zsh)
fi

if [[ -r /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#8CA9BF'
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  bindkey '^[[C' .forward-char
  bindkey '^[OC' .forward-char
  bindkey '^[f' forward-word
  bindkey '^[[1;3C' forward-word
  bindkey '^[^[[C' forward-word
  bindkey '^[[1;9C' autosuggest-accept
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

if [[ -r /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  typeset -gA ZSH_HIGHLIGHT_STYLES
  ZSH_HIGHLIGHT_STYLES[default]='fg=#D8C7FF'
  ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#D98BC4'
  ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#C4A7E7,bold'
  ZSH_HIGHLIGHT_STYLES[alias]='fg=#A3D977'
  ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=#A3D977'
  ZSH_HIGHLIGHT_STYLES[global-alias]='fg=#A3D977'
  ZSH_HIGHLIGHT_STYLES[builtin]='fg=#C4A7E7'
  ZSH_HIGHLIGHT_STYLES[function]='fg=#A3D977'
  ZSH_HIGHLIGHT_STYLES[command]='fg=#A3D977'
  ZSH_HIGHLIGHT_STYLES[precommand]='fg=#C4A7E7'
  ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#B48DDB'
  ZSH_HIGHLIGHT_STYLES[path]='fg=#C4A7E7,underline'
  ZSH_HIGHLIGHT_STYLES[path_pathseparator]='fg=#7C5FB8'
  ZSH_HIGHLIGHT_STYLES[globbing]='fg=#B48DDB'
  ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=#F6C177'
  ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#B48DDB'
  ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#B48DDB'
  ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#B48DDB'
  ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#B48DDB'
  ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#B48DDB'
  ZSH_HIGHLIGHT_STYLES[redirection]='fg=#F6C177'
  ZSH_HIGHLIGHT_STYLES[comment]='fg=#8CA9BF,italic'
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

if [[ -o interactive && -z "${RICE_FASTFETCH_SHOWN:-}" && -z "${FASTFETCH_DISABLE:-}" ]]; then
  export RICE_FASTFETCH_SHOWN=1
  if command -v fastfetch >/dev/null 2>&1; then
    fastfetch --config "$HOME/.config/fastfetch/config.jsonc"
    echo
  fi
fi

y() {
  local tmp
  tmp="$(mktemp -t yazi-cwd.XXXXXX)"
  yazi "$@" --cwd-file="$tmp"
  local cwd
  cwd="$(cat "$tmp")"
  rm -f "$tmp"
  if [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
    cd "$cwd" || return
  fi
}
