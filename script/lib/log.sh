# Shared logging helpers for bootstrap phase scripts.
# Sourced by script/bootstrap.sh after phase-1 checkout.

if [[ -z "${BOOTSTRAP_LOG_LOADED:-}" ]]; then
  BOOTSTRAP_LOG_LOADED=1

  if [[ -t 1 ]]; then
    LOG_RED='\033[0;31m'
    LOG_GREEN='\033[0;32m'
    LOG_YELLOW='\033[1;33m'
    LOG_BLUE='\033[0;34m'
    LOG_DIM='\033[2m'
    LOG_NC='\033[0m'
  else
    LOG_RED='' LOG_GREEN='' LOG_YELLOW='' LOG_BLUE='' LOG_DIM='' LOG_NC=''
  fi

  log_info()  { printf '%b[\xe2\x9c\x93]%b %s\n' "$LOG_GREEN" "$LOG_NC" "$*"; }
  log_warn()  { printf '%b[!]%b %s\n' "$LOG_YELLOW" "$LOG_NC" "$*"; }
  log_error() { printf '%b[\xe2\x9c\x97]%b %s\n' "$LOG_RED" "$LOG_NC" "$*" >&2; }
  log_step()  { printf '\n%b==>%b %s\n' "$LOG_BLUE" "$LOG_NC" "$*"; }
  log_dim()   { printf '%b%s%b\n' "$LOG_DIM" "$*" "$LOG_NC"; }
fi
