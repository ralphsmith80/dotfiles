#!/usr/bin/env bash
set -euo pipefail

has() { command -v "$1" >/dev/null 2>&1; }

log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
log_file="$log_dir/shutter-wayland-capture.log"
lock_open=0
timestamp="$(date +%Y%m%d-%H%M%S)"
screenshots_dir="${XDG_SCREENSHOTS_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots}"
file="$screenshots_dir/shutter-$timestamp.png"

mkdir -p "$screenshots_dir" "$log_dir"

log() {
  printf '%s %s\n' "$(date --iso-8601=seconds)" "$*" >> "$log_file"
}

if has flock; then
  lock_file="$log_dir/shutter-wayland-capture.lock"
  exec 9>"$lock_file"
  lock_open=1
  if ! flock -n 9; then
    log "already running; exiting"
    exit 0
  fi
fi

log "start session=${XDG_SESSION_TYPE:-unknown} desktop=${XDG_CURRENT_DESKTOP:-unknown}"

copy_image() {
  local image="$1"
  if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] && has wl-copy; then
    wl-copy --type image/png < "$image" || true
  elif has xclip; then
    xclip -selection clipboard -target image/png -i "$image" || true
  fi
}

open_editor() {
  local image="$1"

  if [[ "$lock_open" -eq 1 ]]; then
    flock -u 9 || true
    exec 9>&-
    lock_open=0
  fi

  if [[ -x "$HOME/script/shutter-edit-file" ]]; then
    log "open: shutter-edit-file $image"
    SHUTTER_CAPTURE_LOG="$log_file" nohup "$HOME/script/shutter-edit-file" "$image" >> "$log_file" 2>&1 &
  elif has shutter; then
    log "open: shutter --disable_systray $image"
    nohup shutter --disable_systray "$image" >> "$log_file" 2>&1 &
  elif has xdg-open; then
    log "open: xdg-open $image"
    nohup xdg-open "$image" >> "$log_file" 2>&1 &
  fi
}

capture_wayland() {
  if [[ "${XDG_CURRENT_DESKTOP:-}" == *"COSMIC"* ]] && has cosmic-screenshot && has wl-paste; then
    log "capture: cosmic-screenshot+wl-paste"
    if cosmic-screenshot --interactive; then
      sleep 0.2
      if wl-paste --type image/png > "$file" && [[ -s "$file" ]]; then
        log "saved: $file"
        return 0
      fi
      log "capture failed: clipboard did not contain image/png"
    else
      log "capture cancelled: cosmic-screenshot"
    fi
  fi

  if has grim && has slurp; then
    local geometry
    log "capture: grim+slurp"
    if geometry="$(slurp)"; then
      grim -g "$geometry" "$file" && log "saved: $file" && return 0
      log "capture failed: grim"
    else
      log "capture cancelled: slurp"
    fi
  fi

  if has gnome-screenshot; then
    log "capture: gnome-screenshot"
    gnome-screenshot -a -f "$file" && log "saved: $file" && return 0
  fi

  return 1
}

if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
  if capture_wayland; then
    copy_image "$file"
    open_editor "$file"
    exit 0
  fi

  if has cosmic-screenshot; then
    log "fallback: cosmic-screenshot --interactive"
    exec cosmic-screenshot --interactive
  fi
fi

log "fallback: shutter -s"
exec shutter -s
