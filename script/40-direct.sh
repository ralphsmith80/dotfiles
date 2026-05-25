#!/usr/bin/env bash
# Phase 40 — bespoke direct installers for apps not available via brew/flatpak.
# Each handler is idempotent. Driven by ~/.apps-manifest (direct: entries).

set -uo pipefail
# shellcheck disable=SC1091
source "$HOME/script/lib/log.sh"
# shellcheck disable=SC1091
source "$HOME/script/lib/detect.sh"
# shellcheck disable=SC1091
source "$HOME/script/lib/pkg.sh"

MANIFEST="$HOME/.apps-manifest"
APPS_DIR="$HOME/Applications"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$APPS_DIR" "$BIN_DIR" "$DESKTOP_DIR"

# --- 1Password (official Fedora YUM repo) ------------------------------------
# Works on Workstation (dnf), Silverblue (rpm-ostree layer).
_setup_1password_repo() {
  local key_url="https://downloads.1password.com/linux/keys/1password.asc"
  local repo_file="/etc/yum.repos.d/1password.repo"
  if [[ ! -f "$repo_file" ]]; then
    log_info "  registering 1Password RPM repo"
    sudo rpm --import "$key_url" || log_warn "  GPG import failed"
    sudo tee "$repo_file" >/dev/null <<EOF
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=$key_url
EOF
  fi
}

install_1password() {
  [[ "$OS" != "fedora" ]] && { log_warn "  1password installer: Fedora-only path"; return; }
  if rpm -q 1password >/dev/null 2>&1; then
    log_dim "  1password already installed"; return
  fi
  _setup_1password_repo
  pkg_install 1password
}

install_1password_cli() {
  [[ "$OS" != "fedora" ]] && { log_warn "  1password-cli installer: Fedora-only path"; return; }
  if rpm -q 1password-cli >/dev/null 2>&1; then
    log_dim "  1password-cli already installed"; return
  fi
  _setup_1password_repo
  pkg_install 1password-cli
}

# --- Cursor (AppImage) -------------------------------------------------------
# Cursor distributes Linux as AppImage. We place it in ~/Applications, then
# create a wrapper in ~/.local/bin and a .desktop entry so the cursor CLI works
# and the app shows up in the launcher.
install_cursor() {
  local appimage="$APPS_DIR/Cursor.AppImage"
  local wrapper="$BIN_DIR/cursor"
  local desktop="$DESKTOP_DIR/cursor.desktop"
  local url

  case "$(uname -m)" in
    x86_64)  url="https://api2.cursor.sh/updates/download/golden/linux-x64/cursor/latest" ;;
    aarch64|arm64) url="https://api2.cursor.sh/updates/download/golden/linux-arm64/cursor/latest" ;;
    *) log_warn "  cursor installer: unsupported architecture $(uname -m)"; return ;;
  esac

  if [[ -x "$appimage" ]]; then
    log_dim "  cursor AppImage already present (re-run: rm $appimage to refresh)"
  else
    log_info "  downloading cursor AppImage"
    if curl -fSL "$url" -o "$appimage"; then
      chmod +x "$appimage"
    else
      log_warn "  cursor download failed (URL may have changed)"; return
    fi
  fi

  if [[ ! -x "$wrapper" ]]; then
    cat > "$wrapper" <<EOF
#!/bin/sh
exec "$appimage" --no-sandbox "\$@"
EOF
    chmod +x "$wrapper"
  fi

  if [[ ! -f "$desktop" ]]; then
    cat > "$desktop" <<EOF
[Desktop Entry]
Name=Cursor
Comment=AI-first code editor
Exec=$appimage --no-sandbox %U
Icon=cursor
Terminal=false
Type=Application
Categories=Development;IDE;
StartupWMClass=Cursor
MimeType=text/plain;inode/directory;
EOF
  fi
}

# --- t3code (GitHub releases) ------------------------------------------------
# Placeholder — fill in once the release artifact format is verified.
install_t3code() {
  log_warn "  t3code installer not yet implemented — see https://github.com/pingdotgg/t3code/releases"
}

# --- Helium browser ----------------------------------------------------------
# Placeholder — fill in once install method is verified at https://helium.computer
install_helium() {
  log_warn "  helium installer not yet implemented — see https://helium.computer"
}

# --- Dispatcher --------------------------------------------------------------
log_step "Phase 40: direct installs"

if [[ ! -f "$MANIFEST" ]]; then
  log_warn "No manifest at $MANIFEST — skipping"
  exit 0
fi

while IFS= read -r item; do
  [[ -z "$item" ]] && continue
  case "$item" in
    1password)     install_1password ;;
    1password-cli) install_1password_cli ;;
    cursor)        install_cursor ;;
    t3code)        install_t3code ;;
    helium)        install_helium ;;
    *)             log_warn "  unknown direct: $item — add a handler in 40-direct.sh" ;;
  esac
done < <(parse_manifest "$MANIFEST" direct)
