#!/usr/bin/env bash
# Phase 60 — install Cursor extensions from ~/.cursor-extensions-manifest.
# Uses the cursor command installed by 40-direct.sh. Fedora installs the Cursor
# RPM, while other Linux installs may use the ~/.local/bin/cursor AppImage shim.

set -uo pipefail
# shellcheck disable=SC1091
source "$HOME/script/lib/log.sh"
# shellcheck disable=SC1091
source "$HOME/script/lib/pkg.sh"

MANIFEST="$HOME/.cursor-extensions-manifest"
CURSOR_SHIM="$HOME/.local/bin/cursor"

log_step "Phase 60: cursor extensions"

resolve_cursor_bin() {
  if [[ -x "$CURSOR_SHIM" ]]; then
    echo "$CURSOR_SHIM"
  elif command -v cursor >/dev/null 2>&1; then
    command -v cursor
  fi
}

CURSOR_BIN="$(resolve_cursor_bin)"

if [[ -z "$CURSOR_BIN" ]]; then
  log_warn "cursor command not found — did phase 40 install cursor?"
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
