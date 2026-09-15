"""Exercise shell bootstrap in disposable homes with no package or account changes."""

import os
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parents[1]


class ShellBootstrapTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="shell test ")
        self.addCleanup(temporary.cleanup)
        self.home = Path(temporary.name)
        self.scripts = self.home / "script"
        shutil.copytree(SCRIPTS, self.scripts)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.calls = self.home / "calls"
        self.release = self.home / "os-release"
        self.release.write_text("ID=arch\n")
        # Redirect the OS fixture in both independent detection paths.
        for relative in ["lib/detect.sh", "bootstrap.sh"]:
            path = self.scripts / relative
            path.write_text(path.read_text().replace("/etc/os-release", shlex.quote(str(self.release))))
        self.env = os.environ.copy()
        self.env.update(HOME=str(self.home), PATH=str(self.bin), SHELL="/bin/bash",
                        CALLS=str(self.calls), INSTALL_RESULT="0", OSTYPE="linux-gnu")
        for name in ["ZSH_CUSTOM", "WSL_DISTRO_NAME", "BOOTSTRAP_LOG_LOADED"]:
            self.env.pop(name, None)
        self.stub("sudo", 'exec "$@"')
        (self.bin / "date").symlink_to(shutil.which("date"))
        self.stub("pacman", '''printf 'pacman %s\n' "$*" >> "$CALLS"
if [[ "$INSTALL_RESULT" != 0 ]]; then exit "$INSTALL_RESULT"; fi
/bin/cp /bin/true "$HOME/bin/zsh"
''')
        self.stub("git", 'printf "git %s\n" "$*" >> "$CALLS"')
        self.stub("chsh", 'printf "chsh %s\n" "$*" >> "$CALLS"')
        self.stub("curl", 'printf "curl\n" >> "$CALLS"; exit 22')
        (self.home / ".oh-my-zsh").mkdir()
        (self.home / ".zsh-plugins").write_text("git\nexample https://example.invalid/plugin.git\n")

    def stub(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/bash\n" + body + "\n")
        path.chmod(0o755)

    def run_shell(self):
        return subprocess.run(["/bin/bash", str(self.scripts / "50-shell.sh")],
                              env=self.env, capture_output=True, text=True)

    def test_arch_and_derivative_detection_in_both_paths(self):
        for release in ["ID=arch\n", 'ID=endeavouros\nID_LIKE="arch"\n']:
            self.release.write_text(release)
            with self.subTest(release=release):
                shared = subprocess.run(
                    ["/bin/bash", "-c", 'source "$HOME/script/lib/detect.sh"; printf "%s %s" "$OS" "$PKG_MGR"'],
                    env=self.env, capture_output=True, text=True, check=True)
                self.assertEqual(shared.stdout, "arch pacman")
                # Stop before checkout: test the real phase-1 prereq path only.
                self.env["INSTALL_RESULT"] = "17"
                bootstrap = subprocess.run(
                    ["/bin/bash", str(self.scripts / "bootstrap.sh"), "--zsh-only"],
                    env=self.env, capture_output=True, text=True)
                self.assertEqual(bootstrap.returncode, 17, bootstrap.stdout + bootstrap.stderr)
                self.assertIn("Detected OS: arch", bootstrap.stdout)
                self.assertIn("pacman -S --needed --noconfirm git curl", self.calls.read_text())

    def test_missing_zsh_installs_before_plugins_and_shell_switch(self):
        result = self.run_shell()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = self.calls.read_text().splitlines()
        self.assertEqual(calls[0], "pacman -S --needed --noconfirm zsh")
        self.assertTrue(calls[1].startswith("git clone --depth 1"), calls)
        self.assertEqual(calls[2], f"chsh -s {self.bin}/zsh")
        self.calls.write_text("")
        self.assertEqual(self.run_shell().returncode, 0)
        self.assertNotIn("pacman", self.calls.read_text())

    def test_failed_install_stops_before_plugins_or_shell_switch(self):
        self.env["INSTALL_RESULT"] = "1"
        result = self.run_shell()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("zsh installation failed", result.stderr)
        self.assertEqual(self.calls.read_text().splitlines(), ["pacman -S --needed --noconfirm zsh"])

    def test_success_without_available_zsh_stops_setup(self):
        self.stub("pacman", "exit 0")
        result = self.run_shell()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("zsh is not available", result.stderr)
        self.assertFalse(self.calls.exists())

    def test_failed_oh_my_zsh_download_stops_setup(self):
        self.stub("zsh", "exit 0")
        (self.home / ".oh-my-zsh").rmdir()
        result = self.run_shell()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("oh-my-zsh download failed", result.stderr)
        self.assertEqual(self.calls.read_text(), "curl\n")


if __name__ == "__main__":
    unittest.main()
