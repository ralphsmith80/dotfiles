# Dotfiles

Personal dotfiles + cross-distro Linux bootstrap, managed via bare git repo.

## Omarchy modifications

For the personal Omarchy changes, use the separate configuration command from
this checkout. It does not run the package installer below.

```bash
python3 script/omarchy.py --build
python3 script/omarchy.py          # Preview
python3 script/omarchy.py --apply
```

See [the small Omarchy setup](omarchy/README.md) for the three configuration files,
required tiling patch, backups, and optional monitor settings.

## Quick Start (new machine)

```bash
# One-liner — installs everything and checks out dotfiles
curl -fsSL https://raw.githubusercontent.com/ralphsmith80/dotfiles/main/script/bootstrap.sh | bash

# Zsh-only — checks out dotfiles, then installs Zsh, Starship, eza, and plugins
curl -fsSL https://raw.githubusercontent.com/ralphsmith80/dotfiles/main/script/bootstrap.sh | bash -s -- --zsh-only
```

`--zsh-only` limits the installer phases, but still checks out all tracked
dotfiles into your home directory. For an existing account or Omarchy setup,
use the focused update below. Bootstrap refuses an existing Git config that
has not been migrated to local overrides.

Or clone and run locally:

```bash
git clone https://github.com/ralphsmith80/dotfiles.git /tmp/dotfiles
bash /tmp/dotfiles/script/bootstrap.sh
```

## Update shell settings across accounts

Use a normal clone for shared changes and updates. Run these commands as each
account, with Python 3.9+ and Git installed:

```bash
# Once per account. Choose an unused directory for this clone.
git clone https://github.com/ralphsmith80/dotfiles.git ~/dotfiles-source
cd ~/dotfiles-source

# Each update:
git pull --ff-only
python3 script/apply-shell.py          # Preview without writing
python3 script/apply-shell.py --apply  # Back up, migrate, and update
bash ~/script/50-shell.sh             # Install missing shell tools and plugins
exec zsh
```

The apply command updates Zsh startup files, the plugin list, the Zsh Starship
prompt, Git defaults, and the shell installer with its three helper files.
It leaves other desktop and editor files alone. It does not switch branches
in an existing `~/.cfg` repository. Make future shared changes in the normal
clone and open a PR from there. Old `config status` output can still show the
focused deployment as changes; do not reset it or use `config pull` to deploy
shell updates.

### Each account owns its overrides

| File | Purpose |
|------|---------|
| `~/.zshenv.local` | Environment variables for all Zsh sessions |
| `~/.zshrc.local` | Interactive aliases, PATH additions, and tool setup |
| `~/.gitconfig.local` | Git identity and account-specific settings |

Zsh loads each local file after its shared counterpart. Git includes its local
file last. These files are optional and ignored by the dotfiles repository.
Keep future account edits there. Existing settings appended to a known shared
Zsh file move into its local file. Git identity and changes from the last known
Git config move into `.gitconfig.local`. With no known Git baseline, all existing
Git settings are retained locally. Existing local files are preserved; conflicting
Git values, edits inside shared Zsh code, and unknown changes to other managed
files stop the update before any config file is changed. Move such edits into a
local file or reconcile them in the source clone, then preview again.

A fresh account must set its own Git identity:

```bash
git config --file ~/.gitconfig.local user.name "Your name"
git config --file ~/.gitconfig.local user.email "you@example.com"
```

Backups are under `~/.local/state/dotfiles-shell/backups/`. The apply command
also keeps the last shared files there for the next migration. It serializes
concurrent applies and rolls back completed writes if a later write fails.
A second apply with the same source makes no changes. Keep the source clone's
Git history when moving it to another host so legacy shell versions can be
recognized.

### Desktop apps still opening Bash

Changing the login shell does not update applications already running in a
graphical session. T3 Code 0.0.40 chooses its Unix terminal shell from the
server's inherited `SHELL`, with Bash as the fallback. A stale desktop launcher
can keep passing Bash to T3 across application restarts. Log out and back in
after changing the login shell, then open a new T3 terminal. Running `exec zsh`
in an existing terminal changes only that terminal.

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
| 45 | `45-1password-env.sh` | Shared 1Password loader, local credential permissions, and Hermes links |
| 50 | `50-shell.sh` | Zsh, Starship, eza, Oh My Zsh, plugins from `.zsh-plugins`, default shell |
| 60 | `60-cursor-extensions.sh` | Cursor extensions from `.cursor-extensions-manifest` |
| 99 | `99-post.sh` | rclone Google Drive reconnect + mount, default browser, reboot prompt |

## Supported platforms

- **Arch Linux / Omarchy** (bootstrap prerequisites and Zsh/Starship/eza/plugins;
  the full application installer is not yet supported)
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

## Zsh defaults

Zsh uses Oh My Zsh for plugins and Starship for the prompt. The prompt shows
the machine name on local and SSH sessions, then the directory and Git status.
The input starts on a second line. `ls`, `lsa`, `lt`, and `lta` use eza for
icon listings and directory trees. Use a Nerd Font in your terminal for icons.

The prompt lives in `.config/starship-zsh.toml`. Zsh selects this file without
changing Omarchy's Bash prompt. If Starship is missing, Zsh keeps a simple
hostname prompt. Existing fzf, zoxide, and mise installations get Zsh integration.
Omarchy's browser and environment settings apply only when available.

The shell installer installs missing Starship and eza commands through pacman
on Arch, or Homebrew when available on other systems. Otherwise it tries the
system package manager. Older distributions may need Homebrew for these tools;
setup stops with an error if either command remains unavailable. The full
bootstrap installs Homebrew on its supported non-Arch platforms.

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

## Agent access to 1Password

Keep one local `OP_SERVICE_ACCOUNT_TOKEN=...` assignment in
`~/.1password/.env`. The directory must have permission `700` and the file
`600`. The root `.gitignore` excludes the credential directory. Provision the
token separately on each machine; bootstrap never copies or creates a token.

Run `bash ~/script/45-1password-env.sh` after provisioning or adding a Hermes
profile. It installs `~/.local/bin/with-1password` and links existing Hermes
profiles' `.op.env` files to the canonical file. It preserves existing credential
files and refuses to replace unrelated loaders or `.op.env` files. It does not
restart services. Hermes must support loading `.op.env`.

```bash
~/.local/bin/with-1password op user get --me >/dev/null
```

The loader passes the token to the requested command without exporting it to the
parent shell. An existing `OP_SERVICE_ACCOUNT_TOKEN` in the environment takes
precedence. Shared agent instructions belong in the QA skills repository's
`AGENTS.md`.

For a legacy Hermes installation, verify authentication through the shared file
before removing its duplicate `OP_SERVICE_ACCOUNT_TOKEN` assignments from
agent-specific `.env` files. Bootstrap leaves these files unchanged.

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
