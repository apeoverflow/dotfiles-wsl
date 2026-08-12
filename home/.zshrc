export ZSH="$HOME/.oh-my-zsh"


# For subprocess / non-TTY shells (nvim plugin terminals, :terminal -c wrappers,
# CI, pipes), skip p10k entirely — gitstatus can't init without a controlling TTY
# and its stderr noise ("can't change option: monitor/zle", gitstatus failed)
# leaks into the subprocess output. Real interactive shells still get p10k.
if [[ -n "$NVIM" ]] || [[ ! -t 0 ]]; then
  ZSH_THEME=""
  POWERLEVEL9K_INSTANT_PROMPT=off
  POWERLEVEL9K_DISABLE_GITSTATUS=true
else
  ZSH_THEME="powerlevel10k/powerlevel10k"
  # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
  if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
  fi
fi
DEFAULT_USER=`whoami`

# History configuration
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.cache/zsh/history

# Create cache directory if it doesn't exist
mkdir -p ~/.cache/zsh

# History options
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY
setopt APPEND_HISTORY

# Basic auto/tab complete:
autoload -U compinit
zstyle ':completion:*' menu select
zmodload zsh/complist
compinit
_comp_options+=(globdots)		# Include hidden files.



plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  fzf-tab
  vi-mode
  docker
  docker-compose
  npm
  yarn
  node
  brew
  history-substring-search
)

source $ZSH/oh-my-zsh.sh


# vi mode settings 
# {{
  bindkey -M viins ^z vi-cmd-mode

  # function zle-line-init zle-keymap-select {
  #   RPS1=${${KEYMAP/vicmd/-- NORMAL --}/(main|viins)/-- INSERT --}"
  #   RPS2=$RPS1
  #   zle reset-prompt
  # }

  # zle -N zle-line-init
  # zle -N zle-keymap-select
  
  # Remove mode switching delay.
KEYTIMEOUT=5

# Change cursor shape for different vi modes.
function zle-keymap-select {
  if [[ ${KEYMAP} == vicmd ]] ||
     [[ $1 = 'block' ]]; then
    echo -ne '\e[1 q'

  elif [[ ${KEYMAP} == main ]] ||
       [[ ${KEYMAP} == viins ]] ||
       [[ ${KEYMAP} = '' ]] ||
       [[ $1 = 'beam' ]]; then
    echo -ne '\e[5 q'
  fi
}
zle -N zle-keymap-select

# Use beam shape cursor on startup.
echo -ne '\e[5 q'

# Use beam shape cursor for each new prompt.
preexec() {
   echo -ne '\e[5 q'
}


# }}

alias c="clear"
alias o="wslview"           # WSL: open in the default Windows app (wslu)
alias o.="wslview ."
alias v="nvim"
alias vd="nvim-dev"
alias p="python3"
alias ts="ts-node"
alias cwd="pwd | clip.exe"  # WSL: copy cwd to the Windows clipboard
alias ex="exit"
alias :q="exit"
# Modern CLI aliases — eza replaces the abandoned exa
alias ls="eza --icons --group-directories-first"
alias ll="eza -la --icons --group-directories-first"
alias la="eza -a --icons --group-directories-first"
alias lt="eza --tree --icons"
# alias cat="bat"
alias grep="rg"
alias find="fd"
# Optional modern replacements — only alias if installed, so a missing tool
# never shadows the real command (learned the hard way with `ps`→procs).
command -v dust  >/dev/null && alias du="dust"
command -v duf   >/dev/null && alias df="duf"
command -v btop  >/dev/null && alias top="btop"
command -v procs >/dev/null && alias ps="procs"
alias jc="javac -d ./build"
alias j="java -cp ./build"
alias lg="lazygit"

alias u="~/Uni/y3"
alias hh="npx hardhat"


export PATH="$HOME/bin:$PATH"

# WSL: JAVA_HOME only if a JDK is present (no macOS java_home helper here).
if [[ -z "${JAVA_HOME:-}" ]]; then
  for _j in /usr/lib/jvm/java-17-openjdk-amd64 /usr/lib/jvm/default-java; do
    [[ -d "$_j" ]] && { export JAVA_HOME="$_j"; break; }
  done
fi
export EDITOR="nvim"


bindkey '^ ' autosuggest-accept 

# Load custom configurations

# Enable fzf-tab completions
enable-fzf-tab

# Configure fzf-tab
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath 2>/dev/null || ls -1 $realpath'
zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
zstyle ':fzf-tab:*' popup-min-size 80 20

# History substring search key bindings
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^P' history-substring-search-up
bindkey '^N' history-substring-search-down

export FZF_DEFAULT_COMMAND='ag -g ""'
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

# >>> conda initialize >>> (COMMENTED OUT - uncomment if needed)
# !! Contents within this block are managed by 'conda init' !!
# __conda_setup="$('$HOME/opt/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
# if [ $? -eq 0 ]; then
#     eval "$__conda_setup"
# else
#     if [ -f "$HOME/opt/anaconda3/etc/profile.d/conda.sh" ]; then
#         . "$HOME/opt/anaconda3/etc/profile.d/conda.sh"
#     else
#         export PATH="$HOME/opt/anaconda3/bin:$PATH"
#     fi
# fi
# unset __conda_setup
# <<< conda initialize <<< (COMMENTED OUT)


# (macOS iTerm2 shell integration removed — not applicable on WSL)


# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
# Lazy load NVM for faster startup
nvm() {
    unset -f nvm
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    nvm "$@"
}
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

export NARGO_HOME="$HOME/.nargo"

export PATH="$PATH:$NARGO_HOME/bin"
export PATH="${HOME}/.bb:${PATH}"
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Additional modern dev tools
export EDITOR="nvim"
export VISUAL="nvim"
export BROWSER="wslview"     # WSL: open URLs in the Windows default browser (wslu)

# Better defaults
export LESS="-R"
# On Debian/Ubuntu `bat` is packaged as `batcat`; setup.sh symlinks it to `bat`.
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# (macOS-only PATH entries removed: /opt/homebrew, gcloud in ~/Downloads,
#  ~/.bb, ~/.fvm_flutter, dart-cli-completion. Add WSL/work equivalents here as
#  needed — e.g. gcloud from its Linux install, rbenv, etc.)

# Launch nvim using a worktree config for testing
nvim-dev() {
  local wt_dir="$HOME/.config/nvim/.claude/worktrees"
  local worktrees=()

  if [[ ! -d "$wt_dir" ]]; then
    echo "No nvim worktrees found at $wt_dir"
    return 1
  fi

  worktrees=($(ls "$wt_dir" 2>/dev/null))

  if [[ ${#worktrees[@]} -eq 0 ]]; then
    echo "No nvim worktrees found"
    return 1
  fi

  local choice
  local nvim_args=("$@")

  if [[ -n "$1" ]] && [[ -d "$wt_dir/$1" ]]; then
    choice="$1"
    nvim_args=("${@:2}")
  elif [[ ${#worktrees[@]} -eq 1 ]]; then
    choice="${worktrees[1]}"
  else
    echo "Available worktrees:"
    for i in {1..${#worktrees[@]}}; do
      echo "  $i) ${worktrees[$i]}"
    done
    echo -n "Select: "
    read -r idx
    choice="${worktrees[$idx]}"
  fi

  local target="$wt_dir/$choice"
  if [[ ! -d "$target" ]]; then
    echo "Worktree '$choice' not found"
    return 1
  fi

  local link="$HOME/.config/nvim-dev"
  ln -sfn "$target" "$link"
  NVIM_APPNAME=nvim-dev nvim "${nvim_args[@]}"
}

# cwcd — checkout a test branch created by Prefix+b
cwcd() {
  local branch
  branch=$(~/.local/bin/cwcd "$@") || return
  git checkout "$branch"
}

# cwr — refresh working directory after Prefix+b updated the branch pointer
cwr() {
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "You have local changes — stash or commit first"
    git diff --stat
    return 1
  fi
  git reset --hard HEAD
}

# cw — tab-complete existing worktree names from the current repo
_cw() {
  local repo_root wt_dir names
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || return
  wt_dir="${repo_root}/.claude/worktrees"
  if [[ -d "$wt_dir" ]]; then
    names=($(ls "$wt_dir" 2>/dev/null))
  fi
  _arguments \
    '1:worktree:(($names))' \
    '-c[use GitHub Copilot CLI]' \
    '-d[dangerously-skip-permissions]' \
    '-s[use Sonnet model]' \
    '-sd[Sonnet + dangerously-skip-permissions]' \
    '-n[normal mode, prompts enabled]'
}
compdef _cw cw

# cwcd — tab-complete test/ branch names (strip test/ prefix for display)
_cwcd() {
  local names
  names=($(git branch --list 'test/*' --format='%(refname:short)' 2>/dev/null | sed 's|^test/||'))
  _arguments '1:test branch:($names)'
}
compdef _cwcd cwcd

# tns — tmux new session with current directory
tns() {
  if [ -z "$1" ]; then
    echo "Usage: tns <session-name>"
    return 1
  fi
  tmux new-session -s "$1" -c "$PWD"
}

# ta — attach to a tmux session (mirrored, shared view).
#   ta            -> fzf picker of sessions (with a window preview)
#   ta <name>     -> attach straight to that session
ta() {
  local s="$1"
  if [ -z "$s" ]; then
    s=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | fzf --height 40% --reverse \
        --prompt 'attach ❯ ' \
        --preview 'tmux list-windows -t {} -F "#{window_index}: #{window_name}  (#{pane_current_path})"') || return
  fi
  [ -z "$s" ] && return
  # from inside tmux, switch instead of nesting an attach
  if [ -n "$TMUX" ]; then
    tmux switch-client -t "$s"
  else
    tmux attach -t "$s"
  fi
}

# tag — attach to a tmux session in a new grouped session (independent window navigation)
tag() {
  if [ -z "$1" ]; then
    echo "Usage: tag <session-name>"
    return 1
  fi
  tmux new-session -s "${1}-$$" -t "$1"
}

# Tab-complete ta/tag with live tmux SESSION NAMES (not filenames/dirs).
if (( $+functions[compdef] )); then
  _tmux_session_names() {
    local -a s
    s=(${(f)"$(tmux list-sessions -F '#{session_name}' 2>/dev/null)"})
    compadd -a s
  }
  compdef _tmux_session_names ta tag
fi
