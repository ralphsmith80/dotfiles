#!/usr/bin/env bash
# Phase 10 — install system packages declared in ~/.apps-manifest (sys: entries).
# On Fedora Workstation/Cosmic spin: uses dnf. On Silverblue: rpm-ostree (layered, reboot required).
# On non-Fedora: skips with a notice.

set -uo pipefail
# shellcheck disable=SC1091
source "$HOME/script/lib/log.sh"
# shellcheck disable=SC1091
source "$HOME/script/lib/detect.sh"
# shellcheck disable=SC1091
source "$HOME/script/lib/pkg.sh"

MANIFEST="$HOME/.apps-manifest"

log_step "Phase 10: system packages"

if [[ "$OS" != "fedora" ]]; then
  log_warn "Skipping sys: entries on non-Fedora OS ($OS)"
  exit 0
fi

if [[ ! -f "$MANIFEST" ]]; then
  log_warn "No manifest at $MANIFEST — skipping"
  exit 0
fi

pkgs=()
while IFS= read -r p; do
  [[ -z "$p" ]] && continue
  pkgs+=("$p")
done < <(parse_manifest "$MANIFEST" sys)

if [[ ${#pkgs[@]} -eq 0 ]]; then
  log_dim "  no sys: entries in manifest"
  exit 0
fi

# Batch rpm-ostree install for atomic — one transaction, one reboot.
if [[ "$PKG_MGR" == "rpm-ostree" ]]; then
  log_info "  rpm-ostree install (${#pkgs[@]} pkgs, batched)"
  if sudo rpm-ostree install --idempotent "${pkgs[@]}"; then
    mark_reboot_needed
  else
    log_warn "  rpm-ostree batch install failed — falling back to per-pkg"
    for p in "${pkgs[@]}"; do pkg_install "$p"; done
  fi
else
  for p in "${pkgs[@]}"; do
    pkg_install "$p"
  done
fi
