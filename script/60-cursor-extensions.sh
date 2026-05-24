#!/usr/bin/env bash
# Phase 60 — install Cursor extensions from ~/.cursor-extensions-manifest.
# Uses the cursor wrapper installed by 40-direct.sh (~/.local/bin/cursor).

set -uo pipefail
# shellcheck disable=SC1091
source "$HOME/script/lib/log.sh"
# shellcheck disable=SC1091
source "$HOME/script/lib/pkg.sh"

MANIFEST="$HOME/.cursor-extensions-manifest"
CURSOR_BIN="$HOME/.local/bin/cursor"

log_step "Phase 60: cursor extensions"

if [[ ! -x "$CURSOR_BIN" ]]; then
  log_warn "cursor wrapper not found at $CURSOR_BIN — did phase 40 install cursor?"
  exit 0
fi

if [[ ! -f "$MANIFEST" ]]; then
  log_warn "no manifest at $MANIFEST — skipping"
  exit 0
fi

# Cursor lists installed extensions via --list-extensions
mapfile -t installed < <("$CURSOR_BIN" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')

while IFS= read -r ext; do
  [[ -z "$ext" ]] && continue
  ext_lc=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
  if printf '%s\n' "${installed[@]}" | grep -qx "$ext_lc"; then
    log_dim "  skip $ext (installed)"
  else
    log_info "  install $ext"
    "$CURSOR_BIN" --install-extension "$ext" --force >/dev/null 2>&1 \
      || log_warn "  failed: $ext"
  fi
done < <(parse_manifest "$MANIFEST")
