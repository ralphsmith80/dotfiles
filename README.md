# dotfiles

These are my personal dotfiles managed using the “bare repo” method (per Atlassian’s
dotfiles tutorial).

The Git repo lives at:

- `~/.cfg` (bare repository)
- Working tree: `$HOME`

## Setup (new machine)

### Option A (recommended): bootstrap script

This is the quickest way to get set up. It will:

- clone the bare repo to `~/.cfg` (if needed)
- set `status.showUntrackedFiles=no`
- attempt `config checkout`
- if there are conflicts, back them up and retry checkout

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ralphsmith80/dotfiles/master/script/bootstrap.sh)"
```

After it finishes, add the alias to your shell config (e.g. `~/.zshrc`):

```bash
alias config='git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
```

Reload your shell:

```bash
source ~/.zshrc
```

Notes:
- This bootstrap uses the SSH URL (`git@github.com:...`), so your machine must have
  GitHub SSH keys configured.

---

### Option B: manual setup

#### 1) Clone the bare repo

```bash
git clone --bare git@github.com:ralphsmith80/dotfiles.git "$HOME/.cfg"
```

#### 2) Create the `config` alias

Add this to your shell config (e.g. `~/.bashrc`, `~/.zshrc`):

```bash
alias config='git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
```

Reload your shell, or run:

```bash
source ~/.zshrc  # or source ~/.bashrc
```

#### 3) Hide untracked files in `$HOME` (recommended)

```bash
config config --local status.showUntrackedFiles no
```

#### 4) Checkout the dotfiles into `$HOME`

```bash
config checkout
```

If checkout fails due to existing files, back them up and retry:

```bash
mkdir -p "$HOME/.dotfiles-backup"
config checkout 2>&1 | grep -E '^\s+' | awk '{print $1}' | while read -r f; do
  mkdir -p "$HOME/.dotfiles-backup/$(dirname "$f")"
  mv "$HOME/$f" "$HOME/.dotfiles-backup/$f"
done

config checkout
```

## Daily usage

```bash
config status
config add ~/.gitconfig
config commit -m "Update gitconfig"
config push
```

## Updating on this machine

```bash
config pull --rebase
config checkout
```

## Notes

- This repository is intended to be used with the `config` alias above.
- Do not commit secrets (API keys, tokens, SSH private keys). Use local-only files
  like `~/.gitconfig.local` or environment variables for sensitive values.

## References

- https://www.atlassian.com/git/tutorials/dotfiles
