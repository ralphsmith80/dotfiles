#!/usr/bin/env bash
# Phase 10 — install system packages declared in ~/.apps-manifest.
# pkg: entries are portable Linux packages installed with apt/dnf/rpm-ostree.
# sys: entries are Fedora-only packages installed with dnf/rpm-ostree.

set -uo pipefail
# shellcheck disable=SC1091
source "$HOME/script/lib/log.sh"
# shellcheck disable=SC1091
source "$HOME/script/lib/detect.sh"
# shellcheck disable=SC1091
source "$HOME/script/lib/pkg.sh"

MANIFEST="$HOME/.apps-manifest"

log_step "Phase 10: system packages"

if [[ ! -f "$MANIFEST" ]]; then
  log_warn "No manifest at $MANIFEST — skipping"
  exit 0
fi

pkgs=()

case "$OS" in
  popos|ubuntu|fedora)
    while IFS= read -r p; do
      [[ -z "$p" ]] && continue
      pkgs+=("$p")
    done < <(parse_manifest "$MANIFEST" pkg)
    ;;
  *)
    log_warn "Skipping pkg: entries on OS ($OS)"
    ;;
esac

if [[ "$OS" == "fedora" ]]; then
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    pkgs+=("$p")
  done < <(parse_manifest "$MANIFEST" sys)
else
  log_warn "Skipping sys: entries on non-Fedora OS ($OS)"
fi

if [[ ${#pkgs[@]} -eq 0 ]]; then
  log_dim "  no system packages for this OS"
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
