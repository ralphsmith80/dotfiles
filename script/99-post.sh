#!/usr/bin/env bash
# Phase 99 — post-install: rclone Google Drive setup, default browser,
# reboot prompt for atomic systems, summary.

set -uo pipefail
# shellcheck disable=SC1091
source "$HOME/script/lib/log.sh"
# shellcheck disable=SC1091
source "$HOME/script/lib/detect.sh"
# shellcheck disable=SC1091
source "$HOME/script/lib/pkg.sh"

log_step "Phase 99: post-install"

# --- rclone Google Drive -----------------------------------------------------
# Mount unit is at ~/.config/systemd/user/rclone-gdrive.service (in dotfiles).
# rclone.conf may not exist yet; seed from template, then OAuth interactively.
# Set BOOTSTRAP_SKIP_RCLONE=1 to bypass (e.g. when running in a Boxes VM).
post_rclone_gdrive() {
  if [[ "${BOOTSTRAP_SKIP_RCLONE:-0}" == "1" ]]; then
    log_warn "  BOOTSTRAP_SKIP_RCLONE=1 — skipping rclone setup"
    return
  fi

  local rclone_conf="$HOME/.config/rclone/rclone.conf"
  local rclone_tmpl="$HOME/.config/rclone/rclone.conf.template"
  local unit="rclone-gdrive.service"

  if ! has rclone; then
    log_warn "  rclone not on PATH — skipping (was phase 20 successful?)"
    return
  fi
  if [[ ! -f "$HOME/.config/systemd/user/$unit" ]]; then
    log_warn "  $unit not present in dotfiles — skipping mount setup"
    return
  fi

  # Seed config from template if user hasn't reconnected yet
  if [[ ! -f "$rclone_conf" && -f "$rclone_tmpl" ]]; then
    log_info "  seeding rclone.conf from template"
    mkdir -p "$(dirname "$rclone_conf")"
    cp "$rclone_tmpl" "$rclone_conf"
  fi

  # If google-drive remote works, skip OAuth
  if rclone lsd google-drive: --max-depth 1 >/dev/null 2>&1; then
    log_dim "  google-drive remote already authenticated"
  else
    log_info "  connecting google-drive (browser will open for OAuth)"
    if [[ -t 0 || -t 1 ]]; then
      # Force tty stdin so it works under curl-pipe-bash
      rclone config reconnect google-drive: </dev/tty || log_warn "  rclone reconnect failed"
    else
      log_warn "  no tty available — run manually: rclone config reconnect google-drive:"
      return
    fi
  fi

  log_info "  enabling rclone mount user service"
  systemctl --user daemon-reload
  systemctl --user enable --now "$unit" || log_warn "  systemd enable failed"
}

# --- default browser ---------------------------------------------------------
post_default_browser() {
  # Zen browser, installed via flatpak. xdg-settings handles the registration.
  local zen_desktop="app.zen_browser.zen.desktop"
  if has xdg-settings && [[ -f "$HOME/.local/share/flatpak/exports/share/applications/$zen_desktop" \
                         || -f "/var/lib/flatpak/exports/share/applications/$zen_desktop" ]]; then
    log_info "  setting default browser to Zen"
    xdg-settings set default-web-browser "$zen_desktop" 2>/dev/null \
      || log_warn "  could not set default browser (run manually in settings)"
  fi
}

# --- reboot prompt for atomic systems ----------------------------------------
post_reboot_prompt() {
  if reboot_is_pending; then
    log_warn "Layered rpm-ostree changes pending — reboot required for drivers/system pkgs to apply"
    log_warn "Run:  systemctl reboot"
    clear_reboot_marker
  fi
}

# --- run -------------------------------------------------------------------
post_rclone_gdrive
post_default_browser
post_reboot_prompt

echo ""
log_info "Bootstrap complete."
echo ""
echo "  Restart your shell or run:"
echo "    exec zsh"
echo ""
echo "  Manage dotfiles with:"
echo "    config status"
echo "    config add <file>"
echo "    config commit -m 'msg'"
echo "    config push"
