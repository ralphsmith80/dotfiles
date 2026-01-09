#!/usr/bin/env bash
set -euo pipefail

REPO_SSH="git@github.com:ralphsmith80/dotfiles.git"
GIT_DIR="$HOME/.cfg"
WORK_TREE="$HOME"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need git
need sed
need mkdir
need mv
need date

config() {
  git --git-dir="$GIT_DIR" --work-tree="$WORK_TREE" "$@"
}

if [[ ! -d "$GIT_DIR" ]]; then
  git clone --bare "$REPO_SSH" "$GIT_DIR"
fi

config config --local status.showUntrackedFiles no

if ! config checkout; then
  echo "Checkout failed (likely existing dotfiles). Backing up to: $BACKUP_DIR" >&2
  mkdir -p "$BACKUP_DIR"

  files="$(
    config checkout 2>&1 | sed -n 's/^[[:space:]]\{1,\}\(.*\)$/\1/p' || true
  )"

  if [[ -z "${files}" ]]; then
    echo "Could not parse conflicting files from checkout output." >&2
    echo "Try running: config checkout" >&2
    exit 1
  fi

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    mkdir -p "$BACKUP_DIR/$(dirname "$f")"
    mv -f "$HOME/$f" "$BACKUP_DIR/$f"
  done <<<"$files"

  config checkout
fi

cat <<'EOF'

Done.

Add this to your ~/.zshrc (recommended):

  alias config='git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

Then reload:

  source ~/.zshrc
EOF