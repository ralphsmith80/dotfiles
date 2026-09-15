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

if ! load_brew; then
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
done < <(parse_manifest "$MANIFEST" brew)
