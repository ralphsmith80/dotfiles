#!/usr/bin/env bash
# Configure local credential access without provisioning or copying a token.
set -euo pipefail
umask 077

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
credential_dir="$HOME/.1password"
credential_file="$credential_dir/.env"
loader="$HOME/.local/bin/with-1password"

if [[ -L "$credential_dir" || -L "$credential_file" ]]; then
  echo 'Keep ~/.1password/.env in a real local directory, not a symlink.' >&2
  exit 1
fi
mkdir -p "$credential_dir" "$HOME/.local/bin"
chmod 700 "$credential_dir"
if [[ -e "$credential_file" ]]; then
  [[ -f "$credential_file" ]] || { echo 'Expected ~/.1password/.env to be a file.' >&2; exit 1; }
  chmod 600 "$credential_file"
else
  echo 'Provision OP_SERVICE_ACCOUNT_TOKEN in ~/.1password/.env with permission 600 before using 1Password.'
fi

# Replace only this setup's loader or the earlier QA skills loader.
if [[ -e "$loader" || -L "$loader" ]]; then
  existing="$(readlink "$loader" || true)"
  if [[ "$existing" != "$script_dir/with-1password" && "$existing" != "$HOME/Workspace/qa-skills/scripts/with-1password" ]]; then
    echo 'Existing ~/.local/bin/with-1password is not managed by this setup; leaving it unchanged.' >&2
    exit 1
  fi
fi
ln -sfn "$script_dir/with-1password" "$loader"

hermes_home="${HERMES_HOME:-$HOME/.hermes}"
shopt -s nullglob
for profile in "$hermes_home" "$hermes_home"/profiles/*; do
  [[ -d "$profile" ]] || continue
  bootstrap_file="$profile/.op.env"
  if [[ -e "$bootstrap_file" || -L "$bootstrap_file" ]]; then
    if [[ "$(readlink "$bootstrap_file" || true)" != "$credential_file" ]]; then
      echo "Existing $bootstrap_file is not the shared credential link; leaving it unchanged." >&2
      exit 1
    fi
  else
    ln -s "$credential_file" "$bootstrap_file"
  fi
done

echo '1Password loader and Hermes credential links configured.'
