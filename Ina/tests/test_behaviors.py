"""Original MIT integration tests. No settings on the live desktop change."""
import json
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import unittest

REPO = Path(__file__).parents[2]


class BehaviorTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='ina-behavior-')
        self.root = Path(self.tmp.name)
        self.home = self.root / 'home'
        self.home.mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def command(self, component, *args):
        return ['bash', str(REPO / 'Ina/scripts' / (component + '.sh')), '--test-root', str(self.root), *args]

    def invoke(self, component, *args):
        return subprocess.run(self.command(component, *args), capture_output=True, text=True)

    def gaming_restored(self):
        manifest = json.loads((self.root / 'state/backups/gaming-mode/manifest.json').read_text())
        values = json.loads((self.root / 'settings.json').read_text())
        self.assertIsNone(manifest['gaming_current'])
        for name, entry in manifest['settings'].items():
            self.assertEqual(values[name], entry['original'])

    def test_gaming_failure_restores_and_preserves_exit_code(self):
        result = self.invoke('gaming-mode', '--apply', '--', 'bash', '-c', 'exit 37')
        self.assertEqual(result.returncode, 37, result.stderr)
        self.gaming_restored()

    def test_gaming_signal_restores(self):
        ready = self.root / 'ready'
        child = subprocess.Popen(self.command('gaming-mode', '--apply', '--', 'python3', '-c', 'import pathlib,time; pathlib.Path('+repr(str(ready))+').touch(); time.sleep(30)'), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 10
            while not ready.exists() and time.monotonic() < deadline:
                time.sleep(0.05)
            self.assertTrue(ready.exists())
            child.send_signal(signal.SIGTERM)
            out, err = child.communicate(timeout=10)
            self.assertEqual(child.returncode, 143, out + err)
            self.gaming_restored()
        finally:
            if child.poll() is None:
                child.kill()
                child.communicate()

    def test_firefox_startup_preferences_restore_without_losing_other_keys(self):
        profile = self.home / 'profile'
        profile.mkdir()
        prefs = profile / 'prefs.js'
        prefs.write_text('user_pref("browser.display.background_color", "#ffffff");\nuser_pref("other.setting", 42);\n')
        result = self.invoke('firefox', '--profile', str(profile), '--user-chrome', '--apply')
        self.assertEqual(result.returncode, 0, result.stderr)
        prefs.write_text('user_pref("browser.display.background_color", "#151022");\nuser_pref("other.setting", 43);\nuser_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);\n')
        result = self.invoke('restore', '--component', 'firefox', '--apply')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('"#ffffff"', prefs.read_text())
        self.assertIn('other.setting", 43', prefs.read_text())
        self.assertNotIn('toolkit.legacy', prefs.read_text())

    def test_firefox_locked_profile_refused(self):
        profile = self.home / 'profile'
        profile.mkdir()
        (profile / '.parentlock').touch()
        result = self.invoke('firefox', '--profile', str(profile), '--apply')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((profile / 'user.js').exists())

    def test_taskbar_preserves_custom_and_other_panel_instances(self):
        values = {'org.cinnamon/panels-enabled': "['1:0:top', '2:1:bottom']", 'org.cinnamon/panels-height': "['1:32', '2:44']", 'org.cinnamon/enabled-applets': "['panel1:left:0:custom@example:91', 'panel1:right:0:calendar@cinnamon.org:13', 'panel2:left:0:menu@cinnamon.org:90']"}
        (self.root / 'settings.json').write_text(json.dumps(values))
        result = self.invoke('taskbar', '--apply')
        self.assertEqual(result.returncode, 0, result.stderr)
        after = json.loads((self.root / 'settings.json').read_text())
        self.assertIn('panel1:left:0:custom@example:91', after['org.cinnamon/enabled-applets'])
        self.assertIn('panel1:center:0:calendar@cinnamon.org:13', after['org.cinnamon/enabled-applets'])
        self.assertIn('panel2:left:0:menu@cinnamon.org:90', after['org.cinnamon/enabled-applets'])
        self.assertIn('2:44', after['org.cinnamon/panels-height'])

    def test_real_desktop_requires_second_opt_in(self):
        result = subprocess.run(['bash', str(REPO / 'Ina/scripts/nemo.sh'), '--apply'], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('--apply-desktop', result.stderr)
