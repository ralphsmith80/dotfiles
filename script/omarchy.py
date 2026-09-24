#!/usr/bin/env python3
"""Restore personal Omarchy overrides. Preview by default; never install system packages."""

import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shlex
import stat
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parents[1]
PROFILE = REPO / "omarchy"
OMARCHY = Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy"))
PLUGIN_ID = "ralphsmith80.equal-tiling"
PLUGIN_URL = "https://github.com/ralphsmith80/omarchy-equal-tiling"


def safe_path(root, relative):
    """Refuse symlinks and non-directory parents before reading or writing."""
    relative = Path(relative)
    if relative.is_absolute() or not relative.parts or ".." in relative.parts:
        raise ValueError(f"Unsafe relative path: {relative}")
    current = root
    for part in relative.parts:
        current = current / part
        if current.is_symlink():
            raise ValueError(f"Refusing symlink: {current}")
        if current.exists() and current != root / relative and not current.is_dir():
            raise ValueError(f"Parent is not a directory: {current}")
    if current.exists() and not current.is_file():
        raise ValueError(f"Not a regular file: {current}")
    return current


def fingerprint(data, mode):
    return {"sha256": hashlib.sha256(data).hexdigest(), "mode": mode}


def state(path):
    if not path.exists():
        return None
    return fingerprint(path.read_bytes(), stat.S_IMODE(path.stat().st_mode))


def atomic_write(path, data, mode):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".dotfiles-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def find_loader(text, module):
    # Ignore long Lua comments/strings while keeping offsets into the original.
    masked = re.sub(r"(?s)(?:--)?\[(=*)\[.*?\]\1\]",
                    lambda match: re.sub(r"[^\n]", " ", match[0]), text)
    return re.search(r'(?m)^[ \t]*require[ \t]*\([ \t]*["\x27]' + re.escape(module)
                     + r'["\x27][ \t]*\)[ \t]*;?[ \t]*(?:--[^\n]*)?$', masked)


def collect_files(args):
    files = {}
    for source in sorted((PROFILE / "config").rglob("*")):
        if source.is_file():
            relative = str(source.relative_to(PROFILE / "config"))
            if relative != "hypr/monitors.lua" or args.with_hardware:
                files[".config/" + relative] = (source.read_bytes(), 0o644)
    # Keep the machine's main configuration; load our overrides before saved layouts.
    target = ".config/hypr/hyprland.lua"
    main = safe_path(args.home, target)
    text = main.read_text()
    loader = 'require("hypr.dotfiles")'
    if not find_loader(text, "hypr.dotfiles"):
        legacy = find_loader(text, "hypr.equal-tiling")
        toggles = find_loader(text, "default.hypr.toggles")
        if legacy:
            text = text[:legacy.start()] + loader + text[legacy.end():]
        elif toggles:
            text = text[:toggles.start()] + loader + "\n" + text[toggles.start():]
        else:
            text = text.rstrip() + "\n" + loader + "\n"
    files[target] = (text.encode(), stat.S_IMODE(main.stat().st_mode))
    return files


@contextmanager
def write_lock(home):
    marker = safe_path(home, ".dotfiles-backup/.write-lock")
    marker.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    try:
        fd = os.open(marker, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError:
        raise ValueError(f"Another restore may be running. Inspect {marker} before removing a stale lock.") from None
    try:
        os.close(fd)
        yield
    finally:
        marker.unlink()


def rollback(home, backup, apply, only=None):
    backup = backup.resolve()
    journal = json.loads(safe_path(backup, "journal.json").read_text())
    if journal["home"] != str(home):
        raise ValueError("Backup belongs to another home directory.")
    if only is not None:
        journal["files"] = [entry for entry in journal["files"] if entry["target"] in only]
    operations = []
    for entry in reversed(journal["files"]):
        target = safe_path(home, entry["target"])
        current = state(target)
        if current == entry["before"]:
            continue
        if current != entry["after"]:
            raise ValueError(f"Changed since restore; refusing to overwrite: {target}")
        data = None
        if entry["before"] is not None:
            saved = safe_path(backup, "files/" + entry["target"])
            if state(saved) != entry["before"]:
                raise ValueError(f"Backup has changed: {saved}")
            data = saved.read_bytes()
        operations.append((target, data, entry))
    managed = read_managed(home)
    for target, data, entry in operations:
        print(f"UNDO {target}")
        if apply:
            if state(safe_path(home, entry["target"])) != entry["after"]:
                raise ValueError(f"File changed while undo was running: {target}")
            if data is None:
                target.unlink()
            else:
                atomic_write(target, data, entry["before"]["mode"])
    if apply:
        original_managed = dict(managed)
        for entry in journal["files"]:
            # Repair an interrupted undo only while this restore still owns the
            # fingerprint. An old undo must not erase newer ownership records.
            if ("managed_before" in entry and managed.get(entry["target"]) == entry["after"]
                    and state(safe_path(home, entry["target"])) == entry["before"]):
                if entry["managed_before"] is None:
                    managed.pop(entry["target"], None)
                else:
                    managed[entry["target"]] = entry["managed_before"]
        if managed != original_managed:
            save_managed(home, managed)
    print(f"{'Restored' if apply else 'Would restore'} {len(operations)} files.")


def read_managed(home):
    path = safe_path(home, ".dotfiles-backup/managed.json")
    return json.loads(path.read_text()) if path.exists() else {}


def save_managed(home, managed):
    atomic_write(safe_path(home, ".dotfiles-backup/managed.json"), json.dumps(managed, sort_keys=True).encode(), 0o600)


def restore_files(args, files):
    managed = read_managed(args.home)
    updated_managed = dict(managed)
    changes = []
    for relative, (data, mode) in files.items():
        target = safe_path(args.home, relative)
        before, after = state(target), fingerprint(data, mode)
        if before != after:
            if relative in managed and before != managed[relative] and not args.overwrite_local:
                raise ValueError(f"Edited since last apply: {target}. Save the edit to the repository or use --overwrite-local to back up and replace it.")
            print(f"{'REPLACE' if before else 'CREATE '} {relative}")
            changes.append(({"target": relative, "before": before, "after": after, "managed_before": managed.get(relative)}, data))
        updated_managed[relative] = after
    print(f"{len(changes)} changes. {'Applying.' if args.apply else 'Preview only; use --apply to write.'}")
    if not args.apply or (not changes and managed == updated_managed):
        return
    with write_lock(args.home):
        if read_managed(args.home) != managed:
            raise ValueError("Another restore changed the managed files. Preview again.")
        if not changes:
            save_managed(args.home, updated_managed)
            return
        backup = Path(tempfile.mkdtemp(prefix="restore-", dir=args.home / ".dotfiles-backup"))
        for entry, _ in changes:
            target = safe_path(args.home, entry["target"])
            if state(target) != entry["before"]:
                raise ValueError(f"File changed during preview: {target}")
            if entry["before"] is not None:
                atomic_write(backup / "files" / entry["target"], target.read_bytes(), entry["before"]["mode"])
        journal = {"home": str(args.home), "files": [entry for entry, _ in changes]}
        atomic_write(backup / "journal.json", (json.dumps(journal, indent=2) + "\n").encode(), 0o600)
        print(f"Backup: {backup}", flush=True)
        written = set()
        try:
            for entry, data in changes:
                target = safe_path(args.home, entry["target"])
                if state(target) != entry["before"]:
                    raise ValueError(f"File changed during restore: {target}")
                atomic_write(target, data, entry["after"]["mode"])
                written.add(entry["target"])
            save_managed(args.home, updated_managed)
        except (OSError, ValueError, KeyboardInterrupt):
            print("Apply failed. Attempting rollback.", file=sys.stderr)
            # An untouched later file may have been edited concurrently. It must
            # not block undoing the files this apply actually replaced.
            rollback(args.home, backup, True, only=written)
            raise
    command = ["python3", str(REPO / "script/omarchy.py"), "--home", str(args.home), "--rollback", str(backup), "--apply"]
    print("Undo: " + shlex.join(command))
    print("After login, check: hyprctl reload && hyprctl configerrors && hyprctl plugin list")


def read_json(command):
    """Run a read-only query that needs the running Omarchy desktop session."""
    try:
        return json.loads(subprocess.run(command, check=True, capture_output=True, text=True).stdout)
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        detail = (getattr(error, "stderr", None) or str(error)).strip()
        raise ValueError(f"{shlex.join(command)} failed. Run this inside the Omarchy desktop session. {detail}") from None


def plugin_command(args):
    """Return the Omarchy command that adds or enables equal tiling, or None.
    The plugin builds and loads its own hy3, so no other setup may hold hy3."""
    if args.home != Path.home().resolve():
        print(f"SKIP plugin {PLUGIN_ID}: Omarchy installs plugins for the current user only.")
        return None
    plugins = read_json(["omarchy", "plugin", "list", "--json"])
    plugin = next((entry for entry in plugins if entry["id"] == PLUGIN_ID), None)
    if plugin and plugin["enabled"]:
        return None
    if any(loaded.get("name") == "hy3" for loaded in read_json(["hyprctl", "plugin", "list", "-j"])):
        print(f"WAIT plugin {PLUGIN_ID}: another setup has hy3 loaded. "
              "Run hyprctl reload, then run this command again.")
        return None
    if plugin:
        return ["omarchy", "plugin", "enable", PLUGIN_ID]
    return ["omarchy", "plugin", "add", PLUGIN_URL, "--enable", "--yes"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Back up and apply the overrides, then add the tiling plugin")
    parser.add_argument("--with-hardware", action="store_true", help="Include the saved Samsung monitor setup")
    parser.add_argument("--overwrite-local", action="store_true", help="Back up and replace later local edits")
    parser.add_argument("--rollback", type=Path, help="Preview an undo; add --apply to perform it")
    parser.add_argument("--home", type=Path, default=Path.home(), help="Target home; must have Omarchy's config already")
    args = parser.parse_args()
    args.home = args.home.expanduser().resolve()
    try:
        if not args.home.is_dir():
            raise ValueError("Target home must exist.")
        if args.rollback:
            if args.apply:
                with write_lock(args.home):
                    rollback(args.home, args.rollback, True)
            else:
                rollback(args.home, args.rollback, False)
        elif platform.system() != "Linux" or not (OMARCHY / "default/hypr/bootstrap.lua").is_file():
            print("Omarchy with Lua configuration is not installed; nothing to do.")
        else:
            if os.environ.get("XDG_CONFIG_HOME") and Path(os.environ["XDG_CONFIG_HOME"]).resolve() != args.home / ".config":
                raise ValueError("These overrides require Omarchy's standard ~/.config location.")
            # Check the plugin first so a run outside the desktop stops before any write.
            try:
                command = plugin_command(args)
            except ValueError as error:
                if args.apply:
                    raise
                print(f"PLUGIN unknown: {error}")
                command = None
            restore_files(args, collect_files(args))
            if command:
                print(f"PLUGIN {shlex.join(command)}")
                if args.apply:
                    subprocess.run(command, check=True)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
