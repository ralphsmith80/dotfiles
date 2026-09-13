"""Exercise credential setup in disposable homes, without real credentials."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parents[1]


class SharedCredentialsTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="credential test ")
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.env = os.environ.copy()
        self.env.pop("OP_SERVICE_ACCOUNT_TOKEN", None)
        self.env.pop("HERMES_HOME", None)
        self.env["HOME"] = str(self.home)
        self.canonical = self.home / ".1password/.env"
        self.loader = self.home / ".local/bin/with-1password"

    def run_command(self, *args):
        return subprocess.run(args, env=self.env, capture_output=True, text=True)

    def provision(self):
        self.canonical.parent.mkdir()
        self.canonical.write_text("OP_SERVICE_ACCOUNT_TOKEN=test-local-value\n")
        self.canonical.chmod(0o644)

    def setup_credentials(self):
        return self.run_command("bash", str(SCRIPTS / "45-1password-env.sh"))

    def test_setup_preserves_token_and_links_profiles_on_repeated_runs(self):
        self.provision()
        profile = self.home / ".hermes/profiles/worker"
        profile.mkdir(parents=True)
        legacy = profile / ".env"
        legacy.write_text("UNRELATED_SETTING=keep-me\n")
        for _ in range(2):
            self.assertEqual(self.setup_credentials().returncode, 0)
        self.assertEqual(self.canonical.parent.stat().st_mode & 0o777, 0o700)
        self.assertEqual(self.canonical.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.canonical.read_text(), "OP_SERVICE_ACCOUNT_TOKEN=test-local-value\n")
        self.assertEqual((profile / ".op.env").resolve(), self.canonical)
        self.assertEqual((self.home / ".hermes/.op.env").resolve(), self.canonical)
        self.assertEqual(legacy.read_text(), "UNRELATED_SETTING=keep-me\n")
        result = self.run_command(str(self.loader), "sh", "-c",
                                  'test "$OP_SERVICE_ACCOUNT_TOKEN" = test-local-value && test "$1" = "two words" || exit 1; exit 23',
                                  "probe", "two words")
        self.assertEqual(result.returncode, 23)
        self.assertEqual(result.stdout + result.stderr, "")

    def test_missing_token_fails_without_running_command(self):
        self.assertEqual(self.setup_credentials().returncode, 0)
        self.assertFalse(self.canonical.exists())
        result = self.run_command(str(self.loader), "touch", str(self.home / "ran"))
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / "ran").exists())
        self.env["OP_SERVICE_ACCOUNT_TOKEN"] = "test-inherited-value"
        result = self.run_command(str(self.loader), "sh", "-c",
                                  'test "$OP_SERVICE_ACCOUNT_TOKEN" = test-inherited-value')
        self.assertEqual(result.returncode, 0)

    def test_existing_loader_is_preserved(self):
        self.loader.parent.mkdir(parents=True)
        self.loader.write_text("custom loader\n")
        self.assertNotEqual(self.setup_credentials().returncode, 0)
        self.assertEqual(self.loader.read_text(), "custom loader\n")

    def test_earlier_qa_loader_is_migrated(self):
        self.loader.parent.mkdir(parents=True)
        self.loader.symlink_to(self.home / "Workspace/qa-skills/scripts/with-1password")
        self.assertEqual(self.setup_credentials().returncode, 0)
        self.assertEqual(self.loader.resolve(), SCRIPTS / "with-1password")

    def test_existing_hermes_credentials_are_preserved(self):
        bootstrap = self.home / ".hermes/.op.env"
        bootstrap.parent.mkdir()
        bootstrap.write_text("OP_SERVICE_ACCOUNT_TOKEN=test-separate-account\n")
        self.assertNotEqual(self.setup_credentials().returncode, 0)
        self.assertEqual(bootstrap.read_text(), "OP_SERVICE_ACCOUNT_TOKEN=test-separate-account\n")

    def test_linked_credential_file_is_rejected(self):
        self.canonical.parent.mkdir()
        target = self.home / "other.env"
        target.write_text("OP_SERVICE_ACCOUNT_TOKEN=test-other\n")
        self.canonical.symlink_to(target)
        self.assertNotEqual(self.setup_credentials().returncode, 0)
        self.assertEqual(target.read_text(), "OP_SERVICE_ACCOUNT_TOKEN=test-other\n")


if __name__ == "__main__":
    unittest.main()
