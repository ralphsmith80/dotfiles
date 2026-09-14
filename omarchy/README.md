# Personal Omarchy changes

This directory saves four configuration files and the custom tiling patch.
The existing cross-platform bootstrap stays unchanged. This separate command
requires Python 3.9 or newer and skips systems without Lua-configured Omarchy.

| File | What it changes |
| --- | --- |
| `config/hypr/dotfiles.lua` | Equal tiling, directional movement, keypad workspaces, and Right Alt dictation. |
| `config/hypr/monitors.lua` | Samsung G95NC at 7680x2160, 240 Hz, scale 1.2. Only with `--with-hardware`. |
| `config/voxtype/config.toml` | Push-to-talk through Hyprland, using the `base.en` model. |
| `config/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf` | Connect Bluetooth A2DP audio profiles automatically. |

From a normal clone of this repository on an installed Omarchy system:

```bash
python3 script/omarchy.py --build
python3 script/omarchy.py          # Preview only
python3 script/omarchy.py --apply
```

The build downloads upstream hy3 commit
`42b7ed8fd9aefd3f36e5f617afd5071245c67853`, verifies its SHA-256 checksum, applies
`hy3.patch`, and compiles against the local Hyprland headers. It needs curl, tar,
patch, CMake, Ninja, a C++23 compiler, pkg-config, and the Hyprland development
dependencies. Missing dependencies stop the build. No packages are installed.
The first build needs internet access; unchanged builds skip download and compile.
Build output stays in the ignored `.build` directory. Rebuild after Hyprland updates.

Apply preserves the existing main Hyprland configuration and adds one module load
before saved layout settings. It replaces the earlier `hypr.equal-tiling` load if
present. Existing monitor settings remain unless `--with-hardware` is supplied.
The other three override files are installed as complete files.

Identical files are skipped. Changed files are backed up under
`~/.dotfiles-backup/restore-*`, with original permissions. Later local edits stop
apply; use `--overwrite-local --apply` only to back up and replace them deliberately.
Each apply prints its exact rollback command. Rollback also previews by default
and refuses to overwrite later edits. Backups are private and excluded from Git.
Symlink and directory conflicts stop the operation before configuration writes.

After login, run `hyprctl reload`, `hyprctl configerrors`, and `hyprctl plugin list`.
Confirm hy3 is loaded, then check Super+Shift+arrows, Super+T, and Super+L with
several windows. The Lua guard uses stock tiling if the running Hyprland version
does not match the plugin. Logging in again may be needed after replacing a loaded
plugin. The installer does not reload or restart the desktop itself, but Hyprland
can automatically reload when its configuration files change.

Voxtype and its `base.en` model must already be installed and its user service
enabled through Omarchy's dictation setup. Terminal and tmux files are omitted
because they match this machine's installed Omarchy defaults. Themes, wallpaper,
bar plugins, and the custom lock screen are not part of this restore. The lock
screen remains a separate optional project; no lock installation is performed here.

The patch is licensed under GPL-3.0 as provided in `LICENSE.hy3`. Copied Omarchy
configuration retains its notice in `LICENSE.omarchy`. No account credentials or
monitor serial number are included.

Run `python3 -m unittest discover -s script/tests -v` for the restore tests.
Development checks also built the pinned source, compared the result to the working
installed plugin, applied twice and rolled back in a temporary home, and verified
the resulting Lua configuration. The real desktop was not modified.
