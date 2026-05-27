#!/usr/bin/env bash
# Phase 70 — configure screenshot shortcut.

set -uo pipefail
# shellcheck disable=SC1091
source "$HOME/script/lib/log.sh"
# shellcheck disable=SC1091
source "$HOME/script/lib/detect.sh"

log_step "Phase 70: screenshot shortcut"

shortcut_cmd="$HOME/script/shutter-wayland-capture.sh"

configure_cosmic_system_action() {
  [[ "${XDG_CURRENT_DESKTOP:-}" == *"COSMIC"* || -d "$HOME/.config/cosmic" ]] || return 0

  local shortcuts_dir="$HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1"
  local actions_file="$shortcuts_dir/system_actions"

  mkdir -p "$shortcuts_dir"

  if [[ ! -f "$actions_file" ]]; then
    cat > "$actions_file" <<EOF
{
    Screenshot: "$shortcut_cmd",
}
EOF
    log_info "  COSMIC Screenshot action -> Shutter Wayland capture wrapper"
    return 0
  fi

  if grep -q '^[[:space:]]*Screenshot:' "$actions_file"; then
    sed -i "s#^[[:space:]]*Screenshot:.*#    Screenshot: \"$shortcut_cmd\",#" "$actions_file"
  else
    sed -i "\$i\\    Screenshot: \"$shortcut_cmd\"," "$actions_file"
  fi

  log_info "  COSMIC Screenshot action -> Shutter Wayland capture wrapper"
}

configure_cosmic_shortcut() {
  [[ "${XDG_CURRENT_DESKTOP:-}" == *"COSMIC"* || -d "$HOME/.config/cosmic" ]] || return 0

  local shortcuts_dir="$HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1"
  local shortcuts_file="$shortcuts_dir/custom"

  mkdir -p "$shortcuts_dir"

  if [[ ! -f "$shortcuts_file" ]]; then
    cat > "$shortcuts_file" <<EOF
{
    (
        modifiers: [
            Ctrl,
            Shift,
        ],
        key: "s",
    ): System(Screenshot),
}
EOF
    log_info "  COSMIC Ctrl+Shift+S -> Shutter Wayland capture wrapper"
    return 0
  fi

  if grep -q 'System(Screenshot)' "$shortcuts_file"; then
    log_dim "  COSMIC shortcut already configured"
    return 0
  fi

  if grep -q 'Spawn("cosmic-screenshot --interactive")' "$shortcuts_file" \
    || grep -q 'Spawn("shutter -s")' "$shortcuts_file" \
    || grep -q "Spawn(\"$shortcut_cmd\")" "$shortcuts_file"; then
    sed -i \
      -e 's#Spawn("cosmic-screenshot --interactive")#System(Screenshot)#' \
      -e 's#Spawn("shutter -s")#System(Screenshot)#' \
      -e "s#Spawn(\"$shortcut_cmd\")#System(Screenshot)#" \
      "$shortcuts_file"
    log_info "  COSMIC Ctrl+Shift+S -> Shutter Wayland capture wrapper"
  else
    log_warn "  COSMIC custom shortcuts exist, but Ctrl+Shift+S was not the known screenshot binding"
    log_warn "  Set it manually to: $shortcut_cmd"
  fi
}

configure_gnome_shortcut() {
  command -v gsettings >/dev/null 2>&1 || return 0
  gsettings writable org.gnome.settings-daemon.plugins.media-keys custom-keybindings >/dev/null 2>&1 || return 0

  local binding_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/shutter-wayland-capture/"
  local schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$binding_path"
  local current

  gsettings set "$schema" name "Shutter Area Screenshot"
  gsettings set "$schema" command "$shortcut_cmd"
  gsettings set "$schema" binding "<Control><Shift>s"

  current="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)"
  if [[ "$current" == "@as []" || "$current" == "[]" ]]; then
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['$binding_path']"
  elif [[ "$current" != *"$binding_path"* ]]; then
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "${current%]}, '$binding_path']"
  fi

  log_info "  GNOME Ctrl+Shift+S -> Shutter Wayland capture wrapper"
}

case "$OS" in
  popos|ubuntu|fedora)
    configure_cosmic_system_action
    configure_cosmic_shortcut
    configure_gnome_shortcut
    ;;
  *)
    log_dim "  skipping screenshot shortcut on $OS"
    ;;
esac
