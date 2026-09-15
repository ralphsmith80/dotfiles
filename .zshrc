# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Starship owns the prompt; keep Oh My Zsh for its plugins.
ZSH_THEME=""

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# PATH setup must happen before Oh My Zsh loads plugins so plugins can find
# Homebrew tools such as bat.
export FLATPAK_HOME="$HOME/.local/share/flatpak/exports/"
export PATH="$FLATPAK_HOME/bin:$PATH"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$PATH:$HOME/.local/bin" ;;
esac

# Plugins loaded from ~/.zsh-plugins (single source of truth)
# Add/remove plugins there — bootstrap.sh auto-installs custom ones
plugins=()
if [[ -f "$HOME/.zsh-plugins" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    plugins+=("${line%% *}")
  done < "$HOME/.zsh-plugins"
fi

# Oh My Zsh handles both current and older fzf shell integrations.
if [[ -o zle && -t 0 ]] && command -v fzf >/dev/null 2>&1; then
  plugins+=(fzf)
fi
source "$ZSH/oh-my-zsh.sh"

# Keep a hostname prompt when Starship is unavailable or TERM=dumb.
PROMPT=$'\n%m %~\n%# '

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"
# export BROWSER='flatpak run app.zen_browser.zen'

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi
export SUDO_EDITOR="${commands[nvim]:-$EDITOR}"

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

alias config="git --git-dir=\$HOME/.cfg/ --work-tree=\$HOME"
alias nvim-kickstart='NVIM_APPNAME="nvim-kickstart" nvim'
alias nvim-lazy='NVIM_APPNAME="nvim-lazyvim" nvim'
if [[ -d "$HOME/.config/nvim-lazyvim" ]]; then
  alias nvim='NVIM_APPNAME="nvim-lazyvim" nvim'
fi
alias claudeyolo='claude --dangerously-skip-permissions'

# Volta PATH (and Cursor real-binary ordering) lives in ~/.zshenv — do not prepend $VOLTA_HOME/bin here
# or interactive shells undo the fix after .zshenv runs.

# Worktrunk (git worktree manager) shell completions
if command -v wt &> /dev/null; then
  eval "$(wt config shell init zsh)"
fi

# Keep the Omarchy tool environment when running Zsh.
export BAT_THEME=ansi
if command -v omarchy-launch-browser >/dev/null 2>&1; then
  export BROWSER="${BROWSER:-omarchy-launch-browser}"
fi
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi
if command -v eza >/dev/null 2>&1; then
  alias ls='eza -lh --group-directories-first --icons=auto'
  alias lsa='ls -a'
  alias lt='eza --tree --level=2 --long --icons --git'
  alias lta='lt -a'
fi
if [[ ${TERM:-} != dumb ]] && command -v starship >/dev/null 2>&1; then
  export STARSHIP_CONFIG="$HOME/.config/starship-zsh.toml"
  eval "$(starship init zsh)"
fi
