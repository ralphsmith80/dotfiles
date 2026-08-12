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
    nohup env SHUTTER_CAPTURE_LOG="$log_file" "$HOME/script/shutter-edit-file" "$image" >> "$log_file" 2>&1 &
  elif has shutter; then
    log "open: shutter --disable_systray $image"
    nohup shutter --disable_systray "$image" >> "$log_file" 2>&1 &
  elif has xdg-open; then
    log "open: xdg-open $image"
    nohup xdg-open "$image" >> "$log_file" 2>&1 &
  fi
}

capture_wayland() {
  if [[ "${XDG_CURRENT_DESKTOP:-}" == *"COSMIC"* ]] && has cosmic-screenshot; then
    local marker
    marker="$log_dir/shutter-wayland-capture.$timestamp.marker"
    : > "$marker"

    log "capture: cosmic-screenshot"
    has wl-copy && wl-copy --clear >/dev/null 2>&1 || true
    if cosmic-screenshot --interactive; then
      local attempt candidate entry latest
      if has wl-paste; then
        for ((attempt = 1; attempt <= 20; attempt++)); do
          if wl-paste --type image/png > "$file" && [[ -s "$file" ]]; then
            log "saved from clipboard: $file"
            rm -f "$marker"
            return 0
          fi
          sleep 0.1
        done
        log "capture: clipboard did not contain image/png"
      fi

      for ((attempt = 1; attempt <= 20; attempt++)); do
        latest=""
        while IFS= read -r -d '' entry; do
          candidate="${entry#* }"
          [[ "$candidate" != "$file" && -s "$candidate" ]] || continue
          if ! has file || [[ "$(file --mime-type -b "$candidate")" == "image/png" ]]; then
            latest="$candidate"
            break
          fi
        done < <(find "$screenshots_dir" -maxdepth 1 -type f -newer "$marker" -printf '%T@ %p\0' 2>/dev/null | sort -z -rn)

        if [[ -n "$latest" ]]; then
          cp "$latest" "$file"
          log "saved: $file"
          rm -f "$marker"
          return 0
        fi
        sleep 0.1
      done
      log "capture failed: no saved COSMIC screenshot found"
    else
      log "capture cancelled: cosmic-screenshot"
    fi
    [[ ! -s "$file" ]] && rm -f "$file"
    rm -f "$marker"
    return 1
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

  if [[ "${XDG_CURRENT_DESKTOP:-}" == *"COSMIC"* ]]; then
    log "capture failed: no COSMIC image available"
    exit 1
  fi

  if has cosmic-screenshot; then
    log "fallback: cosmic-screenshot --interactive"
    exec cosmic-screenshot --interactive
  fi
fi

log "fallback: shutter -s"
exec shutter -s
