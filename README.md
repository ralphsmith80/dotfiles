# Dotfiles

Personal dotfiles managed via bare git repo.

## Quick Start (new machine)

```bash
# One-liner — installs everything and checks out dotfiles
curl -fsSL https://raw.githubusercontent.com/ralphsmith80/dotfiles/master/script/bootstrap.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/ralphsmith80/dotfiles.git /tmp/dotfiles
bash /tmp/dotfiles/script/bootstrap.sh
```

## What it installs

The bootstrap script auto-detects your OS (Fedora, PopOS, Ubuntu/WSL2, macOS) and installs:

| Component | Details |
|-----------|---------|
| **Homebrew** | Package manager (creates `/home/linuxbrew` on Linux) |
| **Oh My Zsh** | ZSH framework + amuse theme |
| **ZSH Plugins** | autosuggestions, syntax-highlighting, bat, autoswitch_virtualenv |
| **Brew packages** | bat, neovim, gh, worktrunk |
| **Volta** | Node version manager (installs Node 24 + pnpm) |
| **Neovim** | LazyVim config at `~/.config/nvim-lazyvim` |

## Adding plugins

1. Add the plugin name to the `plugins=()` array in `.zshrc`
2. Add the clone URL to `PLUGIN_REPOS` in `script/bootstrap.sh`
3. Run `bootstrap.sh` again (idempotent — skips what's already installed)

## Managing dotfiles

```bash
config status              # check what changed
config add .zshrc          # stage a file
config commit -m "update"  # commit
config push                # push to GitHub
```

## Supported platforms

- **Fedora** (desktop & server)
- **Pop!_OS**
- **Ubuntu** (native & WSL2)
- **macOS** (Intel & Apple Silicon)
