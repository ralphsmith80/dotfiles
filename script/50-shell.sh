#!/usr/bin/env bash
# Phase 50 — Oh My Zsh install, custom zsh plugins (from ~/.zsh-plugins),
# and default shell switch to zsh.

set -uo pipefail
# shellcheck disable=SC1091
source "$HOME/script/lib/log.sh"
# shellcheck disable=SC1091
source "$HOME/script/lib/detect.sh"
# shellcheck disable=SC1091
source "$HOME/script/lib/pkg.sh"

log_step "Phase 50: shell + plugins"

# --- ensure zsh present ------------------------------------------------------
if ! has zsh; then
  case "$OS" in
    fedora)            pkg_install zsh ;;
    popos|ubuntu|wsl2) sudo apt-get install -y zsh ;;
  esac
fi

# --- Oh My Zsh ---------------------------------------------------------------
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  log_info "  installing oh-my-zsh"
  RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    || log_warn "  oh-my-zsh install failed"
else
  log_dim "  oh-my-zsh already installed"
fi

# --- Custom zsh plugins (from ~/.zsh-plugins) --------------------------------
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
PLUGINS_FILE="$HOME/.zsh-plugins"

if [[ -f "$PLUGINS_FILE" ]]; then
  log_info "  installing custom zsh plugins from $PLUGINS_FILE"
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    # Parse: plugin-name  [clone-url]  [system-deps...]
    read -r name url deps <<< "$line"
    [[ -z "$url" ]] && continue  # built-in plugin, no clone

    target="$ZSH_CUSTOM/plugins/$name"
    if [[ ! -d "$target" ]]; then
      log_info "    plugin clone: $name"
      git clone --depth 1 "$url" "$target" 2>/dev/null || log_warn "    failed to clone $name"
    else
      log_dim "    plugin skip: $name"
    fi

    if [[ -n "${deps:-}" ]]; then
      for dep in $deps; do
        if ! has "$dep"; then
          log_info "    plugin dep: $dep"
          has brew && brew install "$dep" 2>/dev/null || pkg_install "$dep"
        fi
      done
    fi
  done < "$PLUGINS_FILE"
else
  log_warn "no ~/.zsh-plugins — skipping custom plugins"
fi

# --- default shell -----------------------------------------------------------
if [[ "$SHELL" != *"zsh"* ]]; then
  log_info "  setting default shell to zsh"
  if has chsh; then
    chsh -s "$(command -v zsh)" 2>/dev/null \
      || log_warn "  chsh failed — try: sudo chsh -s $(command -v zsh) $USER"
  fi
fi
