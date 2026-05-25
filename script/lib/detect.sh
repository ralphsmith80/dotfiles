# OS + variant detection. Sets globals consumed by other phases:
#   OS         — macos | fedora | popos | ubuntu | wsl2 | unknown
#   VARIANT    — workstation | silverblue | kinoite | cosmic-spin | n/a
#   IS_ATOMIC  — 0 | 1
#   PKG_MGR    — dnf | rpm-ostree | apt | brew | none

detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "$ID" in
      fedora) echo "fedora" ;;
      pop)    echo "popos" ;;
      ubuntu)
        [[ -n "${WSL_DISTRO_NAME:-}" ]] && echo "wsl2" || echo "ubuntu"
        ;;
      *)
        case "${ID_LIKE:-}" in
          *debian*) echo "ubuntu" ;;
          *fedora*) echo "fedora" ;;
          *) echo "unknown" ;;
        esac
        ;;
    esac
  else
    echo "unknown"
  fi
}

detect_variant() {
  case "${OS:-$(detect_os)}" in
    fedora)
      # rpm-ostree present + /usr read-only => atomic variant
      if command -v rpm-ostree >/dev/null 2>&1 && rpm-ostree status >/dev/null 2>&1; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "${VARIANT_ID:-}" in
          silverblue) echo "silverblue" ;;
          kinoite)    echo "kinoite" ;;
          *)          echo "silverblue" ;;
        esac
      else
        # shellcheck disable=SC1091
        . /etc/os-release
        case "${VARIANT_ID:-}" in
          cosmic*) echo "cosmic-spin" ;;
          *)       echo "workstation" ;;
        esac
      fi
      ;;
    *) echo "n/a" ;;
  esac
}

OS=$(detect_os)
VARIANT=$(detect_variant)

case "$VARIANT" in
  silverblue|kinoite) IS_ATOMIC=1 ;;
  *) IS_ATOMIC=0 ;;
esac

case "$OS" in
  macos) PKG_MGR="brew" ;;
  fedora)
    if [[ "$IS_ATOMIC" -eq 1 ]]; then PKG_MGR="rpm-ostree"; else PKG_MGR="dnf"; fi
    ;;
  popos|ubuntu|wsl2) PKG_MGR="apt" ;;
  *) PKG_MGR="none" ;;
esac

export OS VARIANT IS_ATOMIC PKG_MGR
