#!/usr/bin/env bash
# Phase 15 — Volta + default Node + pnpm.
# Volta is preferred over brew node/pnpm because it auto-switches per-project.

set -uo pipefail
# shellcheck disable=SC1091
source "$HOME/script/lib/log.sh"
# shellcheck disable=SC1091
source "$HOME/script/lib/pkg.sh"

log_step "Phase 15: Volta + Node + pnpm"

if [[ ! -d "$HOME/.volta" ]]; then
  log_info "  installing volta"
  curl -fsSL https://get.volta.sh | bash -s -- --skip-setup
else
  log_dim "  volta already installed"
fi

export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

log_info "  ensuring default node"
volta install node || log_warn "  volta install node failed"

log_info "  ensuring pnpm"
volta install pnpm || log_warn "  volta install pnpm failed"
