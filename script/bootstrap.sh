#!/usr/bin/env bash
# =============================================================================
# Dotfiles Bootstrap — entrypoint
# Works on Fedora (Workstation / Silverblue / Cosmic spin), Pop!_OS, Ubuntu/WSL2, macOS.
#
# Two phases:
#   Phase 1 (this file): minimal prereqs + clone dotfiles bare-repo into $HOME.
#   Phase 2: numbered scripts in $HOME/script/[0-9][0-9]-*.sh — sourced in order.
#
# Quick start (any fresh machine):
#   curl -fsSL https://raw.githubusercontent.com/ralphsmith80/dotfiles/master/script/bootstrap.sh | bash
# =============================================================================

set -euo pipefail

REPO_SSH="git@github.com:ralphsmith80/dotfiles.git"
REPO_HTTPS="https://github.com/ralphsmith80/dotfiles.git"
BOOTSTRAP_BRANCH="${BOOTSTRAP_BRANCH:-feat/fedora-bootstrap}"
GIT_DIR="$HOME/.cfg"
WORK_TREE="$HOME"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
SCRIPT_DIR="$HOME/script"

# --- inline log helpers (phase 1 has no source deps) -------------------------
if [[ -t 1 ]]; then
  C_R='\033[0;31m'; C_G='\033[0;32m'; C_Y='\033[1;33m'; C_B='\033[0;34m'; C_D='\033[2m'; C_N='\033[0m'
else
  C_R='' C_G='' C_Y='' C_B='' C_D='' C_N=''
fi
info()  { printf '%b[\xe2\x9c\x93]%b %s\n' "$C_G" "$C_N" "$*"; }
warn()  { printf '%b[!]%b %s\n' "$C_Y" "$C_N" "$*"; }
error() { printf '%b[\xe2\x9c\x97]%b %s\n' "$C_R" "$C_N" "$*" >&2; }
step()  { printf '\n%b==>%b %s\n' "$C_B" "$C_N" "$*"; }

# --- minimal OS detect (phase 1 only) ----------------------------------------
detect_os_min() {
  if [[ "$OSTYPE" == "darwin"* ]]; then echo "macos"; return; fi
  [[ -r /etc/os-release ]] || { echo "unknown"; return; }
  # shellcheck disable=SC1091
  . /etc/os-release
  case "$ID" in
    fedora) echo "fedora" ;;
    pop)    echo "popos" ;;
    ubuntu) [[ -n "${WSL_DISTRO_NAME:-}" ]] && echo "wsl2" || echo "ubuntu" ;;
    *)
      case "${ID_LIKE:-}" in
        *fedora*) echo "fedora" ;;
        *debian*) echo "ubuntu" ;;
        *) echo "unknown" ;;
      esac
      ;;
  esac
}
OS_MIN=$(detect_os_min)
info "Detected OS: $OS_MIN"

# --- Phase 1: minimal prereqs (git, curl) ------------------------------------
step "Phase 1: install minimal prereqs"
case "$OS_MIN" in
  fedora)
    if command -v rpm-ostree >/dev/null 2>&1 && rpm-ostree status >/dev/null 2>&1; then
      # Atomic — git/curl are baked into the base image; nothing to do.
      info "atomic Fedora detected; git/curl assumed present"
    else
      sudo dnf install -y git curl util-linux-user || warn "dnf prereqs failed"
    fi
    ;;
  popos|ubuntu|wsl2)
    sudo apt-get update -qq
    sudo apt-get install -y git curl || warn "apt prereqs failed"
    ;;
  macos)
    if ! command -v git >/dev/null 2>&1; then
      xcode-select --install 2>/dev/null || true
      warn "If xcode CLI tools aren't installed, complete the GUI prompt and re-run"
    fi
    ;;
  *)
    warn "Unknown OS — attempting to continue"
    ;;
esac

command -v git >/dev/null 2>&1 || { error "git missing after prereq install"; exit 1; }

# --- Phase 1: clone dotfiles bare repo + checkout ----------------------------
step "Phase 1: clone dotfiles + checkout into \$HOME"
info "Using dotfiles branch: $BOOTSTRAP_BRANCH"

config() { git --git-dir="$GIT_DIR" --work-tree="$WORK_TREE" "$@"; }

if [[ ! -d "$GIT_DIR" ]]; then
  if git clone --bare --branch "$BOOTSTRAP_BRANCH" "$REPO_SSH" "$GIT_DIR" 2>/dev/null; then
    info "cloned via SSH"
  else
    warn "SSH clone failed; falling back to HTTPS"
    git clone --bare --branch "$BOOTSTRAP_BRANCH" "$REPO_HTTPS" "$GIT_DIR"
    info "cloned via HTTPS"
  fi
else
  info "dotfiles repo already exists at $GIT_DIR (skipping clone)"
fi

info "fetching latest $BOOTSTRAP_BRANCH"
config fetch origin "refs/heads/$BOOTSTRAP_BRANCH:refs/remotes/origin/$BOOTSTRAP_BRANCH"

if ! config rev-parse --verify --quiet "refs/heads/$BOOTSTRAP_BRANCH" >/dev/null; then
  config branch "$BOOTSTRAP_BRANCH" "refs/remotes/origin/$BOOTSTRAP_BRANCH"
fi

config config --local status.showUntrackedFiles no

if ! config checkout "$BOOTSTRAP_BRANCH" 2>/dev/null; then
  warn "checkout conflict — backing up clashing files to: $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"
  files="$(config checkout "$BOOTSTRAP_BRANCH" 2>&1 | sed -n 's/^[[:space:]]\{1,\}\(.*\)$/\1/p' || true)"
  if [[ -z "${files}" ]]; then
    error "could not parse conflicting files. Try: config checkout $BOOTSTRAP_BRANCH"
    exit 1
  fi
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    mkdir -p "$BACKUP_DIR/$(dirname "$f")"
    mv -f "$HOME/$f" "$BACKUP_DIR/$f"
  done <<<"$files"
  config checkout "$BOOTSTRAP_BRANCH"
fi
info "dotfiles checked out"

if [[ "$(config rev-parse "refs/heads/$BOOTSTRAP_BRANCH")" != "$(config rev-parse "refs/remotes/origin/$BOOTSTRAP_BRANCH")" ]]; then
  if config merge-base --is-ancestor "HEAD" "refs/remotes/origin/$BOOTSTRAP_BRANCH"; then
    info "fast-forwarding local $BOOTSTRAP_BRANCH"
    config merge --ff-only "refs/remotes/origin/$BOOTSTRAP_BRANCH"
  else
    error "local $BOOTSTRAP_BRANCH has diverged from origin/$BOOTSTRAP_BRANCH; resolve with: config status"
    exit 1
  fi
fi

# --- Phase 2: run numbered installer scripts ---------------------------------
if [[ ! -d "$SCRIPT_DIR" || ! -f "$SCRIPT_DIR/lib/log.sh" ]]; then
  error "phase 2 scripts missing at $SCRIPT_DIR — checkout may have failed"
  exit 1
fi

cd "$HOME"
shopt -s nullglob
phase_scripts=("$SCRIPT_DIR"/[0-9][0-9]-*.sh)
shopt -u nullglob

if [[ ${#phase_scripts[@]} -eq 0 ]]; then
  warn "no phase scripts found — done"
  exit 0
fi

step "Phase 2: running ${#phase_scripts[@]} installer phases"
for phase in "${phase_scripts[@]}"; do
  info "→ $(basename "$phase")"
  # Each phase is run as its own bash process: a failure won't kill bootstrap,
  # phase order is deterministic, and env (PATH, REBOOT_RECOMMENDED) is
  # re-derived per phase via lib/detect.sh + lib/pkg.sh.
  if ! bash "$phase"; then
    warn "$(basename "$phase") exited non-zero (continuing)"
  fi
done

step "All phases done"
