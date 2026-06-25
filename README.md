# Dotfiles

Personal dotfiles + cross-distro Linux bootstrap, managed via bare git repo.

## Quick Start (new machine)

```bash
# One-liner — installs everything and checks out dotfiles
curl -fsSL https://raw.githubusercontent.com/ralphsmith80/dotfiles/master/script/bootstrap.sh | bash

# Zsh-only — checks out dotfiles, then installs zsh/Oh My Zsh/plugins only
curl -fsSL https://raw.githubusercontent.com/ralphsmith80/dotfiles/master/script/bootstrap.sh | bash -s -- --zsh-only
```

Or clone and run locally:

```bash
git clone https://github.com/ralphsmith80/dotfiles.git /tmp/dotfiles
bash /tmp/dotfiles/script/bootstrap.sh
```

## Architecture

Bootstrap runs in two phases:

| Phase | File(s) | Job |
|-------|---------|-----|
| **1** | `script/bootstrap.sh` (this file, self-contained) | Detect OS, install `git`/`curl`, clone the bare repo, check out into `$HOME` |
| **2** | `script/[0-9][0-9]-*.sh` (numbered phase scripts) | Run in order, each sourcing helpers from `script/lib/` |

Phase 2 scripts:

| # | Script | What it does |
|---|--------|--------------|
| 00 | `00-prereqs.sh` | RPMFusion, Flathub, Homebrew |
| 10 | `10-system.sh` | System packages (`sys:` entries in `.apps-manifest`) — dnf or rpm-ostree |
| 15 | `15-volta.sh` | Volta + default Node + pnpm |
| 20 | `20-brew.sh` | Homebrew formulae (`brew:` entries) |
| 30 | `30-flatpak.sh` | Flatpak apps (`flatpak:` entries) |
| 40 | `40-direct.sh` | Bespoke installers — 1Password, Cursor, etc. (`direct:` entries) |
| 50 | `50-shell.sh` | Oh My Zsh, custom plugins from `.zsh-plugins`, default shell |
| 60 | `60-cursor-extensions.sh` | Cursor extensions from `.cursor-extensions-manifest` |
| 99 | `99-post.sh` | rclone Google Drive reconnect + mount, default browser, reboot prompt |

## Supported platforms

- **Fedora Workstation** (default — `dnf` for system pkgs)
- **Fedora Silverblue / Kinoite** (atomic — `rpm-ostree` layered installs, reboot at end)
- **Fedora Cosmic spin** (same as Workstation under the hood)
- **Pop!_OS / Ubuntu / WSL2** (partial — system pkgs are Fedora-targeted; brew/flatpak still work)
- **macOS** (brew only)

## Adding apps

Edit `.apps-manifest`. One line per app:

```
sys:ghostty                       # dnf or rpm-ostree
brew:lazygit                      # homebrew formula
flatpak:com.discordapp.Discord    # flathub
direct:cursor                     # custom installer in script/40-direct.sh
```

Re-run `bootstrap.sh` — idempotent, skips anything already installed.

To add a brand-new direct installer, write an `install_<name>` function in `script/40-direct.sh` and reference `direct:<name>` from the manifest.

## Adding zsh plugins

Edit `.zsh-plugins`:

```text
zsh-bat  https://github.com/fdellwing/zsh-bat  bat
```

Re-run `bootstrap.sh`.

## Adding Cursor extensions

Edit `.cursor-extensions-manifest` (one extension ID per line) and re-run.

## Managing dotfiles

```bash
config status              # check what changed
config add .zshrc          # stage a file
config commit -m "update"  # commit
config push                # push to GitHub
```

## Environment variables

| Var | Default | Effect |
|-----|---------|--------|
| `BOOTSTRAP_ZSH_ONLY` | `0` | Set to `1` to run only the zsh shell phase after checkout |
| `BOOTSTRAP_SKIP_RCLONE` | `0` | Set to `1` to skip rclone Google Drive setup in `99-post.sh` (useful in VMs) |

## Layout

```
~/                                    # dotfiles working tree (.cfg = bare repo)
├── .apps-manifest                    # source-of-truth: what to install
├── .cursor-extensions-manifest       # Cursor extensions
├── .zsh-plugins                      # zsh plugin list
├── .zshrc / .zshenv / .gitconfig
├── .claude/                          # Claude Code config
├── .config/
│   ├── nvim-lazyvim/                 # neovim config
│   ├── rclone/rclone.conf.template   # rclone skeleton (no secrets)
│   └── systemd/user/
│       └── rclone-gdrive.service     # Google Drive mount unit
└── script/
    ├── bootstrap.sh                  # entrypoint
    ├── lib/                          # log.sh, detect.sh, pkg.sh
    └── [0-9][0-9]-*.sh               # numbered installer phases
```
