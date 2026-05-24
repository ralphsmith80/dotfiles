#!/usr/bin/env bash
# Phase 30 — install Flatpak apps declared in ~/.apps-manifest (flatpak: entries).
# Uses user-scope flathub (no sudo needed for installs).

set -uo pipefail
# shellcheck disable=SC1091
source "$HOME/script/lib/log.sh"
# shellcheck disable=SC1091
source "$HOME/script/lib/detect.sh"
# shellcheck disable=SC1091
source "$HOME/script/lib/pkg.sh"

MANIFEST="$HOME/.apps-manifest"

log_step "Phase 30: flatpak apps"

if ! has flatpak; then
  log_warn "flatpak not installed (phase 00 should have installed it) — skipping"
  exit 0
fi

if [[ ! -f "$MANIFEST" ]]; then
  log_warn "No manifest at $MANIFEST — skipping"
  exit 0
fi

while IFS= read -r app; do
  [[ -z "$app" ]] && continue
  flatpak_install "$app"
done < <(parse_manifest "$MANIFEST" flatpak)
