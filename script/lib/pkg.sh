# Package install dispatchers + manifest parser.
# Depends on lib/log.sh and lib/detect.sh being sourced first.

# Returns true if a command is available on PATH.
has() { command -v "$1" >/dev/null 2>&1; }

# Returns true if a flatpak app ID is installed (user or system scope).
flatpak_has() {
  flatpak info --user "$1" >/dev/null 2>&1 || flatpak info --system "$1" >/dev/null 2>&1
}

# Install a system package using the detected package manager.
# Idempotent. On atomic Fedora, layered changes need a reboot to take effect —
# callers should batch and notify (handled in 99-post.sh).
pkg_install() {
  local pkg="$1"
  case "$PKG_MGR" in
    dnf)
      if ! rpm -q "$pkg" >/dev/null 2>&1; then
        sudo dnf install -y "$pkg" || log_warn "dnf install $pkg failed"
      fi
      ;;
    rpm-ostree)
      if ! rpm-ostree status --json 2>/dev/null | grep -q "\"$pkg\""; then
        if sudo rpm-ostree install --idempotent "$pkg"; then
          mark_reboot_needed
        else
          log_warn "rpm-ostree install $pkg failed"
        fi
      fi
      ;;
    apt)
      if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        sudo apt-get install -y "$pkg" || log_warn "apt install $pkg failed"
      fi
      ;;
    brew)
      brew_install "$pkg"
      ;;
    *)
      log_warn "Unknown package manager — skipping $pkg"
      ;;
  esac
}

# Install a brew formula. Idempotent.
brew_install() {
  local pkg="$1"
  if ! brew list "$pkg" >/dev/null 2>&1; then
    log_info "  brew install $pkg"
    brew install "$pkg" || log_warn "  brew install $pkg failed"
  else
    log_dim "  brew skip $pkg (installed)"
  fi
}

# Install a flatpak app. Idempotent.
flatpak_install() {
  local app="$1"
  if ! flatpak_has "$app"; then
    log_info "  flatpak install $app"
    local attempt
    for attempt in 1 2 3; do
      if flatpak install -y --noninteractive --user flathub "$app"; then
        return 0
      fi
      [[ "$attempt" -lt 3 ]] || break
      log_warn "  flatpak install $app failed (attempt $attempt/3); retrying"
      sleep 5
    done
    log_warn "  flatpak install $app failed"
  else
    log_dim "  flatpak skip $app (installed)"
  fi
}

# Strip comments + whitespace from a manifest line.
_manifest_clean_line() {
  local line="$1"
  line="${line%%#*}"
  # ltrim
  line="${line#"${line%%[![:space:]]*}"}"
  # rtrim
  line="${line%"${line##*[![:space:]]}"}"
  echo "$line"
}

# Read a manifest file and emit lines matching a given source prefix.
# Usage:  parse_manifest <file> [prefix]
#         prefix is one of: sys | brew | flatpak | direct
parse_manifest() {
  local file="$1"
  local prefix="${2:-}"
  [[ -f "$file" ]] || { log_warn "manifest not found: $file"; return; }
  local line cleaned id
  while IFS= read -r line || [[ -n "$line" ]]; do
    cleaned=$(_manifest_clean_line "$line")
    [[ -z "$cleaned" ]] && continue
    if [[ -z "$prefix" ]]; then
      echo "$cleaned"
    elif [[ "$cleaned" == "${prefix}:"* ]]; then
      id="${cleaned#${prefix}:}"
      [[ -n "$id" ]] && echo "$id"
    fi
  done < "$file"
}

# Reboot marker — phases run in subshells, so we use a file (not an env var)
# to communicate that rpm-ostree changes require a restart.
REBOOT_MARKER="$HOME/.cache/bootstrap-reboot-pending"
mark_reboot_needed() {
  mkdir -p "$(dirname "$REBOOT_MARKER")"
  touch "$REBOOT_MARKER"
}
reboot_is_pending() { [[ -f "$REBOOT_MARKER" ]]; }
clear_reboot_marker() { rm -f "$REBOOT_MARKER"; }
export REBOOT_MARKER
