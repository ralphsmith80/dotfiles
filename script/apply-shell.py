#!/usr/bin/env python3
"""Preview or apply shared shell/Git defaults, preserving account-local overrides."""

import argparse
from collections import defaultdict
from datetime import datetime, timezone
import fcntl
import os
from pathlib import Path
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]
FILES = (
    '.zshenv', '.zshrc', '.zsh-plugins', '.config/starship-zsh.toml', '.gitconfig',
    'script/50-shell.sh', 'script/lib/log.sh', 'script/lib/detect.sh', 'script/lib/pkg.sh',
)
LOCAL = {'.zshenv': '.zshenv.local', '.zshrc': '.zshrc.local'}
STATE = Path('.local/state/dotfiles-shell')


def git(*args, cwd=REPO):
    return subprocess.run(['git', *args], cwd=cwd, capture_output=True)


def read(path):
    if path.is_symlink():
        raise ValueError(f'Refusing to replace a symlink: {path}')
    return path.read_bytes() if path.exists() else None


def old_versions(name, home, *, history=True):
    """Use the last deployment, then the legacy checkout and repository history."""
    cached = read(home / STATE / 'shared' / name)
    if cached is not None:
        yield cached
    legacy = git(f'--git-dir={home / ".cfg"}', 'show', f'HEAD:{name}')
    if legacy.returncode == 0:
        yield legacy.stdout
    if not history:
        return
    revisions = git('log', '--format=%H', '--', name)
    for revision in revisions.stdout.decode().splitlines():
        result = git('show', f'{revision}:{name}')
        if result.returncode == 0:
            yield result.stdout


def config_values(data):
    """Parse Git's own syntax without resolving includes or showing values."""
    with tempfile.NamedTemporaryFile() as file:
        file.write(data)
        file.flush()
        result = git('config', '--file', file.name, '--no-includes', '--null', '--list')
    if result.returncode:
        raise ValueError('Cannot parse Git configuration')
    values = defaultdict(list)
    for record in result.stdout.split(b'\0'):
        if record:
            key, separator, value = record.partition(b'\n')
            values[key.decode()].append(value.decode() if separator else 'true')
    return dict(values)


def migrate_git(current, base, shared, local):
    actual, previous, defaults, overrides = map(config_values, (current, base, shared, local))
    # Includes can override earlier settings. Do not reorder or recursively copy them.
    for key, values in actual.items():
        if key.startswith('includeif.') or (key == 'include.path' and values != ['~/.gitconfig.local']):
            raise ValueError('Move Git includes from .gitconfig into .gitconfig.local before applying')
    if actual.get('include.path') == ['~/.gitconfig.local'] and actual != previous:
        raise ValueError('Shared .gitconfig was edited after migration; move account edits into .gitconfig.local')
    for key in previous.keys() - actual.keys():
        if key in defaults and key != 'include.path':
            raise ValueError(f'.gitconfig removes shared setting {key}; resolve this before applying')
    additions = {key: values for key, values in actual.items()
                 if (key.startswith('user.') or values != previous.get(key))
                 and not (key == 'include.path' and values == ['~/.gitconfig.local'])}
    with tempfile.NamedTemporaryFile() as file:
        for key, values in additions.items():
            if key in overrides:
                if overrides[key] != values:
                    raise ValueError(f'Conflicting local Git setting: {key}')
                continue
            for value in values:
                result = git('config', '--file', file.name, '--add', '--', key, value)
                if result.returncode:
                    raise ValueError(f'Cannot preserve Git setting: {key}')
        migrated = Path(file.name).read_bytes()
        return migrated + local


def prepare(home):
    planned = {}
    observed = {}
    def observe(name):
        if name not in observed:
            observed[name] = read(home / name)
        return observed[name]

    if (home / '.cfg').is_dir():
        name = '.cfg/info/exclude'
        existing = observe(name) or b''
        missing = [f'/{name}'.encode() for name in (*LOCAL.values(), '.gitconfig.local')
                   if f'/{name}'.encode() not in existing.splitlines()]
        if missing:
            planned[name] = existing + (b'\n' if existing and not existing.endswith(b'\n') else b'') + b'\n'.join(missing) + b'\n'

    for name in FILES:
        source = (REPO / name).read_bytes()
        current = observe(name)
        if current is not None and current != source:
            versions = list(old_versions(name, home, history=name != '.gitconfig'))
            if name == '.gitconfig':
                local_name = '.gitconfig.local'
                local = observe(local_name) or b''
                # Without a known baseline, retain all existing Git settings locally.
                base = versions[0] if versions else b''
                planned[local_name] = migrate_git(current, base, source, local)
            elif name in LOCAL:
                matches = [version for version in versions if current.startswith(version)]
                if not matches:
                    raise ValueError(f'{name} has edits inside shared config; move them to {LOCAL[name]} first')
                suffix = current[len(max(matches, key=len)):]
                if suffix.strip():
                    local_name = LOCAL[name]
                    local = observe(local_name) or b''
                    planned[local_name] = local + (b'\n' if local and not local.endswith(b'\n') else b'') + suffix
            elif current not in versions:
                raise ValueError(f'{name} has unrecognized edits; leaving it unchanged')
        planned[name] = source
        planned[str(STATE / 'shared' / name)] = source
    changes = {}
    for name, after in planned.items():
        path = home / name
        if not path.parent.resolve().is_relative_to(home):
            raise ValueError(f'Path leaves the account home: {name}')
        before = observe(name)
        if before != after:
            mode = path.stat().st_mode & 0o777 if before is not None else 0o600 if name.endswith('.local') else 0o644
            changes[name] = (before, after, mode)
    return changes


def replace(path, data, mode):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as file:
        temporary = Path(file.name)
        file.write(data)
    try:
        temporary.chmod(mode)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def apply(home, changes):
    backup = home / STATE / 'backups' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup.mkdir(parents=True, mode=0o700)
    for name, (before, _, mode) in changes.items():
        if read(home / name) != before:
            raise ValueError(f'{name} changed during preparation; retry')
        if before is not None:
            replace(backup / name, before, mode)
    completed = []
    try:
        for name, (before, after, mode) in changes.items():
            if read(home / name) != before:
                raise ValueError(f'{name} changed during apply')
            replace(home / name, after, mode)
            completed.append(name)
    except Exception:
        for name in reversed(completed):
            before, after, mode = changes[name]
            # Preserve a concurrent edit rather than overwriting it during rollback.
            if read(home / name) == after:
                if before is None:
                    (home / name).unlink()
                else:
                    replace(home / name, before, mode)
        raise
    print(f'Applied. Backups: {backup}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Apply after checking all managed files')
    parser.add_argument('--home', type=Path, default=Path.home(), help='Account home to update')
    args = parser.parse_args()
    home = args.home.expanduser().resolve()
    if not home.is_dir():
        parser.error('Account home does not exist')
    try:
        if args.apply:
            state = home / STATE
            if not state.resolve().is_relative_to(home):
                raise ValueError('Shell state directory leaves the account home')
            state.mkdir(parents=True, exist_ok=True)
            lock_path = state / 'apply.lock'
            if lock_path.is_symlink():
                raise ValueError('Refusing a symlinked apply lock')
            with lock_path.open('a') as lock:
                fcntl.flock(lock, fcntl.LOCK_EX)
                changes = prepare(home)
                if changes:
                    apply(home, changes)
                else:
                    print('Already up to date.')
        else:
            changes = prepare(home)
            for name in changes:
                if not name.startswith(str(STATE)):
                    print(f'Would update {name}')
            print('Preview only. Run with --apply to write these changes.')
    except (ValueError, OSError) as error:
        parser.exit(1, f'{error}\n')


if __name__ == '__main__':
    main()
