"""Exercise account migration against real Git parsing and disposable homes."""

import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('apply_shell', Path(__file__).resolve().parents[1] / 'apply-shell.py')
shell = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(shell)


class ApplyShellTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='account shell ')
        self.addCleanup(temporary.cleanup)
        self.home = Path(temporary.name)

    def write(self, name, data):
        path = self.home / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def test_appended_account_config_migrates_and_rerun_is_empty(self):
        base = shell.git('show', 'HEAD:.zshrc').stdout
        suffix = b'\nexport ACCOUNT_TOOL="iris"\n'
        self.write('.zshrc', base + suffix)
        self.write('.zshrc.local', b'alias own="true"\n')
        shell.apply(self.home, shell.prepare(self.home))
        self.assertEqual((self.home / '.zshrc.local').read_bytes(), b'alias own="true"\n' + suffix)
        self.assertEqual((self.home / '.zshrc').read_bytes(), (shell.REPO / '.zshrc').read_bytes())
        self.assertEqual(shell.prepare(self.home), {})
        backups = list((self.home / shell.STATE / 'backups').glob('*/.zshrc'))
        self.assertEqual(backups[0].read_bytes(), base + suffix)
        self.assertEqual((self.home / '.gitconfig').stat().st_mode & 0o777, 0o644)

    def test_unknown_in_place_edit_stops_before_any_config_writes(self):
        self.write('.zshrc', b'export UNIQUE_SETTING=1\n')
        with self.assertRaisesRegex(ValueError, 'edits inside shared config'):
            shell.prepare(self.home)
        self.assertFalse((self.home / '.zshenv').exists())
        self.assertFalse((self.home / shell.STATE).exists())

    def test_git_identity_and_changed_settings_survive_real_include(self):
        old = b'[user]\nname=Original\nemail=old@example.invalid\n[pull]\nrebase=true\n'
        current = old.replace(b'Original', b'Athena').replace(b'old@', b'athena@').replace(b'rebase=true', b'rebase=false')
        self.write(str(shell.STATE / 'shared' / '.gitconfig'), old)
        self.write('.gitconfig', current)
        self.write('.gitconfig.local', b'[alias]\naccount=status\n')
        shell.apply(self.home, shell.prepare(self.home))
        for key, value in [('user.name', 'Athena'), ('user.email', 'athena@example.invalid'), ('pull.rebase', 'false'), ('alias.account', 'status')]:
            result = subprocess.run(['git', 'config', '--global', '--includes', '--get', key],
                                    env={**os.environ, 'HOME': str(self.home), 'GIT_CONFIG_GLOBAL': str(self.home / '.gitconfig')},
                                    capture_output=True, text=True, check=True)
            self.assertEqual(result.stdout.strip(), value)
        self.assertEqual(shell.prepare(self.home), {})

    def test_no_known_git_baseline_preserves_all_existing_values(self):
        self.write('.gitconfig', b'[init]\ndefaultBranch=master\n[user]\nname=Ares\n')
        shell.apply(self.home, shell.prepare(self.home))
        values = shell.config_values((self.home / '.gitconfig.local').read_bytes())
        self.assertEqual(values['init.defaultbranch'], ['master'])
        self.assertEqual(values['user.name'], ['Ares'])

    def test_conflicting_git_override_and_shared_deletion_are_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Conflicting local Git setting'):
            shell.migrate_git(b'[user]\nname=One\n', b'', b'', b'[user]\nname=Two\n')
        with self.assertRaisesRegex(ValueError, 'removes shared setting'):
            shell.migrate_git(b'', b'[pull]\nrebase=true\n', b'[pull]\nrebase=true\n', b'')

    def test_extra_git_include_stops_before_creating_recursive_local_include(self):
        shell.apply(self.home, shell.prepare(self.home))
        self.write('.workgit', b'[user]\nname=Work\n')
        path = self.home / '.gitconfig'
        path.write_bytes(path.read_bytes() + b'\n[include]\npath=~/.workgit\n')
        before = path.read_bytes()
        with self.assertRaisesRegex(ValueError, 'Move Git includes'):
            shell.prepare(self.home)
        self.assertEqual(path.read_bytes(), before)
        result = subprocess.run(['git', 'config', '--global', '--includes', '--get', 'user.name'],
                                env={**os.environ, 'HOME': str(self.home), 'GIT_CONFIG_GLOBAL': str(path)},
                                capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout.strip(), 'Work')

    def test_legacy_home_gets_ignore_rules_without_replacing_existing_rules(self):
        subprocess.run(['git', 'init', '--bare', str(self.home / '.cfg')], capture_output=True, check=True)
        self.write('.cfg/info/exclude', b'/my-private-file\n')
        shell.apply(self.home, shell.prepare(self.home))
        self.assertTrue((self.home / '.cfg/info/exclude').read_bytes().startswith(b'/my-private-file\n'))
        for name in ['.zshrc.local', '.zshenv.local', '.gitconfig.local']:
            result = subprocess.run(['git', f'--git-dir={self.home / ".cfg"}', f'--work-tree={self.home}', 'check-ignore', name],
                                    cwd=self.home, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(shell.prepare(self.home), {})

    def test_edit_during_preparation_is_not_adopted_as_safe_to_overwrite(self):
        original = shell.read
        old = shell.git('show', 'HEAD:.zshrc').stdout + b'\nexport ACCOUNT_TOOL=iris\n'
        self.write('.zshrc', old)
        def concurrent_edit(path):
            data = original(path)
            if path == self.home / '.zshrc':
                path.write_bytes(b'concurrent user edit')
            return data
        with patch.object(shell, 'read', side_effect=concurrent_edit):
            changes = shell.prepare(self.home)
        with self.assertRaisesRegex(ValueError, 'changed during preparation'):
            shell.apply(self.home, changes)
        self.assertEqual((self.home / '.zshrc').read_bytes(), b'concurrent user edit')
        self.assertFalse((self.home / '.zshenv').exists())

    def test_failed_write_rolls_back_applied_prefix(self):
        self.write('.zshenv', b'before')
        changes = {'.zshenv': (b'before', b'after', 0o600), '.zshrc': (None, b'new', 0o644)}
        original = shell.replace
        def fail(path, data, mode):
            if path == self.home / '.zshrc':
                raise OSError('simulated failed write')
            original(path, data, mode)
        with patch.object(shell, 'replace', side_effect=fail):
            with self.assertRaisesRegex(OSError, 'simulated'):
                shell.apply(self.home, changes)
        self.assertEqual((self.home / '.zshenv').read_bytes(), b'before')
        self.assertFalse((self.home / '.zshrc').exists())

    def test_preview_cli_does_not_write_and_bootstrap_preserves_unmigrated_git(self):
        self.write('.gitconfig', b'[user]\nname=Existing\n')
        before = (self.home / '.gitconfig').read_bytes()
        result = subprocess.run(['python3', str(shell.REPO / 'script/apply-shell.py'), '--home', str(self.home)], capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.home / shell.STATE).exists())
        result = subprocess.run(['bash', str(shell.REPO / 'script/bootstrap.sh'), '--zsh-only'],
                                env={**os.environ, 'HOME': str(self.home)}, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b'needs migration', result.stderr)
        self.assertEqual((self.home / '.gitconfig').read_bytes(), before)

    def test_symlink_to_another_home_is_rejected(self):
        (self.home / '.zshenv').symlink_to(shell.REPO / '.zshenv')
        with self.assertRaisesRegex(ValueError, 'symlink'):
            shell.prepare(self.home)


if __name__ == '__main__':
    unittest.main()
