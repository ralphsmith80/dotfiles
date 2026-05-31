# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Homebrew formulae are part of the bootstrap manifest. Keep them available in
# bash too, especially before the default shell switch to zsh takes effect.
if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
elif [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv bash)"
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv bash)"
elif command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv bash)"
fi

# If a terminal still starts bash because it inherited an old SHELL value,
# hand interactive sessions back to the configured zsh login shell.
if [[ $- == *i* && -z "${DOTFILES_BASH_ZSH_FALLBACK:-}" ]] && ZSH_BIN="$(command -v zsh)"; then
    export DOTFILES_BASH_ZSH_FALLBACK=1
    export SHELL="$ZSH_BIN"
    exec "$ZSH_BIN" -l
fi

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc
