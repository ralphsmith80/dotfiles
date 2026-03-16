#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Dotfiles Bootstrap — works on Fedora, PopOS, Ubuntu (incl. WSL2), and macOS
# =============================================================================

REPO_SSH="git@github.com:ralphsmith80/dotfiles.git"
REPO_HTTPS="https://github.com/ralphsmith80/dotfiles.git"
GIT_DIR="$HOME/.cfg"
WORK_TREE="$HOME"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*" >&2; }

# =============================================================================
# OS Detection
# =============================================================================
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif grep -qi "pop" /etc/os-release 2>/dev/null; then
    echo "popos"
  elif grep -qi "fedora" /etc/os-release 2>/dev/null; then
    echo "fedora"
  elif grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
    if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
      echo "wsl2"
    else
      echo "ubuntu"
    fi
  else
    echo "unknown"
  fi
}

OS=$(detect_os)
info "Detected OS: $OS"

# =============================================================================
# Package Manager Helpers
# =============================================================================
pkg_install() {
  case "$OS" in
    macos)
      brew install "$@" 2>/dev/null || true
      ;;
    fedora)
      sudo dnf install -y "$@" 2>/dev/null || true
      ;;
    popos|ubuntu|wsl2)
      sudo apt-get install -y "$@" 2>/dev/null || true
      ;;
  esac
}

need() {
  command -v "$1" >/dev/null 2>&1 || {
    error "Missing required command: $1"
    exit 1
  }
}

has() {
  command -v "$1" >/dev/null 2>&1
}

# =============================================================================
# 1. System Prerequisites
# =============================================================================
info "Installing system prerequisites..."

case "$OS" in
  fedora)
    sudo dnf install -y git zsh curl util-linux-user 2>/dev/null || true
    ;;
  popos|ubuntu|wsl2)
    sudo apt-get update -qq
    sudo apt-get install -y git zsh curl 2>/dev/null || true
    ;;
  macos)
    # Xcode CLI tools provide git; brew installed below
    ;;
esac

need git

# =============================================================================
# 2. Homebrew
# =============================================================================
if ! has brew; then
  info "Installing Homebrew..."
  if [[ "$OS" == "macos" ]]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
  else
    # Linux — ensure /home/linuxbrew exists
    if [[ ! -d /home/linuxbrew/.linuxbrew ]]; then
      sudo mkdir -p /home/linuxbrew/.linuxbrew
      sudo chown -R "$(whoami)" /home/linuxbrew/.linuxbrew
    fi
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
  info "Homebrew installed"
else
  if [[ "$OS" == "macos" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
  else
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
  info "Homebrew already installed"
fi

# =============================================================================
# 3. Oh My Zsh
# =============================================================================
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  info "Installing Oh My Zsh..."
  RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  info "Oh My Zsh installed"
else
  info "Oh My Zsh already installed"
fi

# =============================================================================
# 4. ZSH Custom Plugins (auto-detect from .zshrc)
# =============================================================================
info "Installing ZSH custom plugins..."

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Map of plugin name → git clone URL
# Add new plugins here and they'll auto-install
declare -A PLUGIN_REPOS=(
  [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions"
  [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting"
  [zsh-bat]="https://github.com/fdellwing/zsh-bat"
  [autoswitch_virtualenv]="https://github.com/MichaelAquilina/zsh-autoswitch-virtualenv"
)

for plugin in "${!PLUGIN_REPOS[@]}"; do
  target="$ZSH_CUSTOM/plugins/$plugin"
  if [[ ! -d "$target" ]]; then
    info "  Installing plugin: $plugin"
    git clone --depth 1 "${PLUGIN_REPOS[$plugin]}" "$target" 2>/dev/null || warn "  Failed to clone $plugin"
  else
    info "  Plugin already installed: $plugin"
  fi
done

# =============================================================================
# 5. Brew packages
# =============================================================================
info "Installing brew packages..."

BREW_PACKAGES=(
  bat          # zsh-bat dependency + better cat
  neovim       # editor
  gh           # GitHub CLI
  worktrunk    # git worktree management
)

for pkg in "${BREW_PACKAGES[@]}"; do
  if ! brew list "$pkg" &>/dev/null; then
    info "  Installing: $pkg"
    brew install "$pkg" 2>/dev/null || warn "  Failed to install $pkg"
  else
    info "  Already installed: $pkg"
  fi
done

# Platform-specific packages
case "$OS" in
  popos|ubuntu|wsl2)
    pkg_install xclip xsel  # copyfile plugin dependency
    pkg_install pipx
    has pipx && pipx ensurepath 2>/dev/null || true
    has pipx && pipx install virtualenv 2>/dev/null || true
    ;;
esac

# =============================================================================
# 6. Volta (Node version manager)
# =============================================================================
if [[ ! -d "$HOME/.volta" ]]; then
  info "Installing Volta..."
  curl https://get.volta.sh | bash -s -- --skip-setup
  export VOLTA_HOME="$HOME/.volta"
  export PATH="$VOLTA_HOME/bin:$PATH"
  info "Volta installed"
else
  export VOLTA_HOME="$HOME/.volta"
  export PATH="$VOLTA_HOME/bin:$PATH"
  info "Volta already installed"
fi

# Install default Node if not present
if ! has node; then
  info "Installing Node via Volta..."
  volta install node@24
  info "Node $(node --version) installed"
fi

# Install pnpm if not present
if ! has pnpm; then
  info "Installing pnpm via Volta..."
  volta install pnpm
  info "pnpm installed"
fi

# =============================================================================
# 7. Set default shell to zsh
# =============================================================================
if [[ "$SHELL" != *"zsh"* ]]; then
  info "Setting default shell to zsh..."
  if has chsh; then
    chsh -s "$(which zsh)" 2>/dev/null || warn "Could not change shell (may need sudo: sudo chsh -s $(which zsh) $USER)"
  fi
fi

# =============================================================================
# 8. Dotfiles checkout (bare repo)
# =============================================================================
config() {
  git --git-dir="$GIT_DIR" --work-tree="$WORK_TREE" "$@"
}

if [[ ! -d "$GIT_DIR" ]]; then
  info "Cloning dotfiles..."
  # Try SSH first, fall back to HTTPS
  if git clone --bare "$REPO_SSH" "$GIT_DIR" 2>/dev/null; then
    info "Cloned via SSH"
  else
    warn "SSH clone failed, trying HTTPS..."
    git clone --bare "$REPO_HTTPS" "$GIT_DIR"
    info "Cloned via HTTPS"
  fi
else
  info "Dotfiles repo already exists"
fi

config config --local status.showUntrackedFiles no

if ! config checkout 2>/dev/null; then
  warn "Checkout conflict — backing up existing files to: $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"

  files="$(
    config checkout 2>&1 | sed -n 's/^[[:space:]]\{1,\}\(.*\)$/\1/p' || true
  )"

  if [[ -z "${files}" ]]; then
    error "Could not parse conflicting files. Try running: config checkout"
    exit 1
  fi

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    mkdir -p "$BACKUP_DIR/$(dirname "$f")"
    mv -f "$HOME/$f" "$BACKUP_DIR/$f"
  done <<<"$files"

  config checkout
fi

info "Dotfiles checked out"

# =============================================================================
# 9. Neovim config
# =============================================================================
NVIM_DIR="$HOME/.config/nvim-lazyvim"
if [[ -d "$NVIM_DIR" ]]; then
  info "LazyVim config present at $NVIM_DIR"
else
  warn "LazyVim config not found — may need to run: config checkout"
fi

# =============================================================================
# Done
# =============================================================================
echo ""
info "Bootstrap complete! 🎉"
echo ""
echo "  Restart your shell or run:"
echo "    exec zsh"
echo ""
echo "  Dotfiles alias available:"
echo "    config status"
echo "    config add <file>"
echo "    config commit -m 'msg'"
echo "    config push"
