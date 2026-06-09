#!/usr/bin/env bash
# Phase 20 — install Homebrew packages declared in ~/.apps-manifest (brew: entries).

set -uo pipefail
# shellcheck disable=SC1091
source "$HOME/script/lib/log.sh"
# shellcheck disable=SC1091
source "$HOME/script/lib/detect.sh"
# shellcheck disable=SC1091
source "$HOME/script/lib/pkg.sh"

MANIFEST="$HOME/.apps-manifest"

log_step "Phase 20: brew packages"

cleanup_legacy_codex_standalone() {
  local shim="$HOME/.local/bin/codex"
  local target

  [[ -L "$shim" ]] || return 0
  target="$(readlink -f "$shim" 2>/dev/null || true)"
  [[ "$target" == "$HOME/.codex/packages/standalone/"* ]] || return 0
  brew list codex >/dev/null 2>&1 || return 0

  rm -f "$shim"
  log_info "  removed legacy Codex standalone shim"
}

if ! has brew; then
  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  elif [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

if ! has brew; then
  log_error "brew not found — did phase 00 succeed?"
  exit 0
fi

if [[ ! -f "$MANIFEST" ]]; then
  log_warn "No manifest at $MANIFEST — skipping"
  exit 0
fi

while IFS= read -r p; do
  [[ -z "$p" ]] && continue
  brew_install "$p"
  [[ "$p" == "codex" ]] && cleanup_legacy_codex_standalone
done < <(parse_manifest "$MANIFEST" brew)
