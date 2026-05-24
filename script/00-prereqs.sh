#!/usr/bin/env bash
# Phase 00 — package-source prerequisites + Homebrew install.
# Sets up the channels later phases install from: RPMFusion, Flathub, Brew.

set -uo pipefail
# shellcheck disable=SC1091
source "$HOME/script/lib/log.sh"
# shellcheck disable=SC1091
source "$HOME/script/lib/detect.sh"
# shellcheck disable=SC1091
source "$HOME/script/lib/pkg.sh"

# --- RPMFusion (Fedora) ------------------------------------------------------
# Provides nonfree codecs, NVIDIA drivers, etc.
setup_rpmfusion() {
  local fedora_ver
  fedora_ver=$(rpm -E %fedora 2>/dev/null || echo "")
  [[ -z "$fedora_ver" ]] && return
  local free_url="https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm"
  local nonfree_url="https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm"

  if rpm -q rpmfusion-free-release >/dev/null 2>&1 && rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
    log_dim "  RPMFusion already enabled"
    return
  fi

  case "$PKG_MGR" in
    dnf)
      sudo dnf install -y "$free_url" "$nonfree_url" || log_warn "  RPMFusion enable failed"
      ;;
    rpm-ostree)
      if sudo rpm-ostree install --idempotent "$free_url" "$nonfree_url"; then
        mark_reboot_needed
      else
        log_warn "  RPMFusion enable failed"
      fi
      ;;
  esac
}

# --- Flathub -----------------------------------------------------------------
setup_flathub() {
  if ! command -v flatpak >/dev/null 2>&1; then
    pkg_install flatpak
  fi
  if ! flatpak remotes --user 2>/dev/null | grep -q '^flathub'; then
    log_info "  adding flathub remote (user scope)"
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
      || log_warn "  flathub add failed"
  else
    log_dim "  flathub remote already configured"
  fi
}

# --- Homebrew ----------------------------------------------------------------
setup_brew() {
  if command -v brew >/dev/null 2>&1; then
    log_dim "  homebrew already installed"
  else
    log_info "  installing homebrew"
    if [[ "$OS" == "macos" ]]; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
      if [[ ! -d /home/linuxbrew/.linuxbrew ]]; then
        sudo mkdir -p /home/linuxbrew/.linuxbrew
        sudo chown -R "$(whoami)" /home/linuxbrew
      fi
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
  fi

  # Make brew available in this script's process
  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  elif [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

log_step "Phase 00: prerequisites"

case "$OS" in
  fedora)
    setup_rpmfusion
    setup_flathub
    setup_brew
    ;;
  popos|ubuntu|wsl2)
    sudo apt-get update -qq
    setup_flathub
    setup_brew
    ;;
  macos)
    setup_brew
    ;;
  *)
    log_warn "Unknown OS — skipping prereqs"
    ;;
esac
