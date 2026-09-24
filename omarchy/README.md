# Personal Omarchy changes

This directory saves three configuration files. Equal tiling comes from the
[omarchy-equal-tiling](https://github.com/ralphsmith80/omarchy-equal-tiling)
Omarchy plugin. The existing cross-platform bootstrap stays unchanged. This
separate command requires Python 3.9 or newer and skips systems without
Lua-configured Omarchy.

| File | What it changes |
| --- | --- |
| `config/hypr/dotfiles.lua` | Keypad workspaces and Right Alt dictation. |
| `config/hypr/monitors.lua` | Samsung G95NC at 7680x2160, 240 Hz, scale 1.2. Only with `--with-hardware`. |
| `config/voxtype/config.toml` | Push-to-talk through Hyprland, using the `base.en` model. |

From a normal clone of this repository on an installed Omarchy system:

```bash
python3 script/omarchy.py          # Preview only
python3 script/omarchy.py --apply
```

Apply preserves the existing main Hyprland configuration and adds one module load
before saved layout settings. It replaces the earlier `hypr.equal-tiling` load if
present, because that module loads its own copy of hy3. Existing monitor settings
remain unless `--with-hardware` is supplied. The other two override files are
installed as complete files.

After the files, apply adds and enables the `ralphsmith80.equal-tiling` plugin, or
enables it if it is already added. Preview prints the plugin command without
running it. The plugin builds hy3 in the background and loads it. See its README
for build dependencies, shortcuts, updates, and removal. The plugin step runs
only for the current user's home, and only inside the Omarchy desktop session.
Apply checks this before it writes any file.

Identical files are skipped. Changed files are backed up under
`~/.dotfiles-backup/restore-*`, with original permissions. Later local edits stop
apply; use `--overwrite-local --apply` only to back up and replace them deliberately.
Each apply prints its exact rollback command. Rollback also previews by default
and refuses to overwrite later edits. Rollback restores files only and keeps the
plugin. If the restored files load hy3, run
`omarchy plugin remove ralphsmith80.equal-tiling --yes` before the rollback.
Backups are private and excluded from Git. Symlink and directory conflicts stop
the operation before configuration writes.

A machine that loaded hy3 through an older version of these overrides still has
that hy3 loaded after the first apply. Apply then prints `WAIT` instead of adding
the plugin. Run `hyprctl reload`, then run apply again. Files from the older build
in `~/.local/lib/hy3` are no longer used and can be deleted.

After login, run `hyprctl reload`, `hyprctl configerrors`, and `hyprctl plugin list`.
Confirm hy3 is loaded, then check Super+Shift+arrows, Super+Alt+P, and Super+L
with several windows.

Voxtype and its `base.en` model must already be installed and its user service
enabled through Omarchy's dictation setup. Terminal and tmux files are omitted
because they match this machine's installed Omarchy defaults. Themes, wallpaper,
bar plugins, and the custom lock screen are not part of this restore. The lock
screen remains a separate optional project; no lock installation is performed here.

Copied Omarchy configuration retains its notice in `LICENSE.omarchy`. No account
credentials or monitor serial number are included.

Run `python3 -m unittest discover -s script/tests -v` for the restore tests.
