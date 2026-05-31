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

_setup_helium_repo() {
  local fedora_ver repo_file repo_url
  fedora_ver=$(rpm -E %fedora 2>/dev/null || echo "")
  [[ -z "$fedora_ver" ]] && return 1
  repo_file="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:imput:helium.repo"
  repo_url="https://copr.fedorainfracloud.org/coprs/imput/helium/repo/fedora-${fedora_ver}/imput-helium-fedora-${fedora_ver}.repo"

  [[ -f "$repo_file" ]] && return 0

  log_info "  enabling Helium COPR"
  if sudo dnf copr enable -y imput/helium; then
    return 0
  fi

  log_warn "  dnf copr enable failed; falling back to repo file"
  curl -fsSL "$repo_url" | sudo tee "$repo_file" >/dev/null
}

install_helium() {
  [[ "$OS" != "fedora" ]] && { log_warn "  helium installer: Fedora-only path"; return; }
  if rpm -q helium-bin >/dev/null 2>&1; then
    log_dim "  helium already installed"; return
  fi
  if _setup_helium_repo; then
    pkg_install helium-bin
  else
    log_warn "  helium repo setup failed"
  fi
}

_has_libfuse2() {
  if command -v ldconfig >/dev/null 2>&1 && ldconfig -p 2>/dev/null | grep -q 'libfuse[.]so[.]2'; then
    return 0
  fi
  [[ -e /lib/libfuse.so.2 || -e /lib64/libfuse.so.2 || -e /usr/lib/libfuse.so.2 || -e /usr/lib64/libfuse.so.2 ]]
}

_ensure_appimage_fuse2() {
  _has_libfuse2 && return 0

  log_info "  installing AppImage FUSE compatibility library"
  case "$OS" in
    fedora)
      pkg_install fuse-libs
      ;;
    popos|ubuntu|wsl2)
      sudo apt-get install -y libfuse2 2>/dev/null \
        || sudo apt-get install -y libfuse2t64 2>/dev/null \
        || log_warn "  install libfuse2 failed"
      ;;
    *)
      log_warn "  AppImage may not launch: libfuse.so.2 not found"
      ;;
  esac

  _has_libfuse2 || log_warn "  libfuse.so.2 still not found; AppImage launch may require a reboot or manual package install"
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

  if [[ "$OS" == "fedora" ]]; then
    case "$(uname -m)" in
      x86_64)  url="https://api2.cursor.sh/updates/download/golden/linux-x64-rpm/cursor/latest" ;;
      aarch64|arm64) url="https://api2.cursor.sh/updates/download/golden/linux-arm64-rpm/cursor/latest" ;;
      *) log_warn "  cursor installer: unsupported architecture $(uname -m)"; return ;;
    esac

    if rpm -q cursor >/dev/null 2>&1; then
      log_dim "  cursor RPM already installed"
    else
      log_info "  installing cursor RPM"
      sudo dnf install -y "$url" || log_warn "  cursor RPM install failed"
    fi

    # Remove the old AppImage shim created by earlier bootstrap runs so it does
    # not shadow the RPM-provided cursor command.
    if [[ -f "$wrapper" ]] && grep -q "$appimage" "$wrapper" 2>/dev/null; then
      rm -f "$wrapper"
    fi
    if [[ -f "$desktop" ]] && grep -q "$appimage" "$desktop" 2>/dev/null; then
      rm -f "$desktop"
    fi
    return
  fi

  _ensure_appimage_fuse2

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
install_t3code() {
  local appimage="$APPS_DIR/T3-Code.AppImage"
  local wrapper="$BIN_DIR/t3code"
  local desktop="$DESKTOP_DIR/t3code.desktop"
  local icon_dir="$HOME/.local/share/icons/hicolor/1024x1024/apps"
  local icon="$icon_dir/t3code.png"
  local api="https://api.github.com/repos/pingdotgg/t3code/releases/latest"
  local asset_url

  case "$(uname -m)" in
    x86_64) ;;
    *) log_warn "  t3code installer: unsupported architecture $(uname -m)"; return ;;
  esac

  _ensure_appimage_fuse2

  asset_url=$(
    curl -fsSL "$api" |
      awk -F'"' '/"browser_download_url":/ && /T3-Code-.*-x86_64[.]AppImage"/ { print $4; exit }'
  )

  if [[ -z "$asset_url" ]]; then
    log_warn "  t3code AppImage asset not found in latest release"
    return
  fi

  if [[ -x "$appimage" ]]; then
    log_dim "  t3code AppImage already present (re-run: rm $appimage to refresh)"
  else
    log_info "  downloading t3code AppImage"
    if curl -fL "$asset_url" -o "$appimage"; then
      chmod +x "$appimage"
    else
      log_warn "  t3code download failed"; return
    fi
  fi

  log_info "  installing t3code launcher"
  cat > "$wrapper" <<EOF
#!/bin/sh
exec "$appimage" --no-sandbox "\$@"
EOF
  chmod +x "$wrapper"

  log_info "  installing t3code desktop metadata"
  local tmp extract_desktop extract_icon
  tmp=$(mktemp -d)
  if (
    cd "$tmp" &&
      "$appimage" --appimage-extract t3code.desktop >/dev/null 2>&1 &&
      "$appimage" --appimage-extract usr/share/icons/hicolor/1024x1024/apps/t3code.png >/dev/null 2>&1
  ); then
    extract_desktop="$tmp/squashfs-root/t3code.desktop"
    extract_icon="$tmp/squashfs-root/usr/share/icons/hicolor/1024x1024/apps/t3code.png"
    mkdir -p "$icon_dir"
    cp "$extract_icon" "$icon"
    sed "s|^Exec=.*|Exec=$appimage --no-sandbox %U|" "$extract_desktop" > "$desktop"
  else
    log_warn "  t3code metadata extraction failed; writing fallback desktop entry"
    cat > "$desktop" <<EOF
[Desktop Entry]
Name=T3 Code (Alpha)
Comment=T3 Code desktop build
Exec=$appimage --no-sandbox %U
Icon=t3code
Terminal=false
Type=Application
Categories=Development;
StartupWMClass=t3code
MimeType=text/plain;inode/directory;
EOF
  fi
  rm -rf "$tmp"
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
