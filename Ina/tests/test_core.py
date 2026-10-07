"""Original MIT tests. All mutations stay beneath /tmp."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

LIB = Path(__file__).parents[1] / 'scripts/lib'
spec = importlib.util.spec_from_file_location('engine', LIB / 'engine.py')
engine = importlib.util.module_from_spec(spec)
spec.loader.exec_module(engine)


class CoreTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='ina-test-')
        self.root = Path(self.tmp.name)
        self.args = engine.parser().parse_args(['icons', '--test-root', str(self.root), '--apply'])
        self.ctx = engine.Context(self.args)

    def tearDown(self):
        self.tmp.cleanup()

    def test_existing_file_permissions_repeat_and_restore(self):
        target = self.ctx.home / 'settings with spaces'
        target.parent.mkdir(parents=True)
        target.write_text('before')
        target.chmod(0o640)
        self.ctx.file(target, 'after')
        backup = self.ctx.manifest_path.read_bytes()
        self.ctx.file(target, 'after')
        self.assertEqual(backup, self.ctx.manifest_path.read_bytes())
        engine.restore(self.ctx, 'icons')
        engine.restore(self.ctx, 'icons')
        self.assertEqual(target.read_text(), 'before')
        self.assertEqual(target.stat().st_mode & 0o777, 0o640)

    def test_new_file_removed_on_rollback(self):
        target = self.ctx.home / 'new'
        self.ctx.file(target, 'new')
        engine.restore(self.ctx, 'icons')
        engine.restore(self.ctx, 'icons')
        self.assertFalse(target.exists())

    def test_preview_does_not_create_state(self):
        self.ctx.dry = True
        self.ctx.acquire()
        self.ctx.file(self.ctx.home / 'file', 'preview')
        self.assertEqual(list(self.root.iterdir()), [])

    def test_symbolic_link_rejected(self):
        self.ctx.home.mkdir(parents=True)
        link = self.ctx.home / 'link'
        link.symlink_to('/etc/passwd')
        with self.assertRaises(engine.Error):
            self.ctx.file(link, 'no')

    def test_test_root_cannot_escape(self):
        with self.assertRaises(engine.Error):
            self.ctx.file('/etc/lightdm/slick-greeter.conf', 'no')

    def test_restore_refuses_later_user_edit(self):
        target = self.ctx.home / 'file'
        self.ctx.file(target, 'ina')
        target.write_text('later user edit')
        with self.assertRaises(engine.Error):
            engine.restore(self.ctx, 'icons')
        self.assertEqual(target.read_text(), 'later user edit')

    def test_settings_repeat_restore(self):
        identity = 'org.cinnamon.desktop.interface/cursor-size'
        (self.root / 'settings.json').write_text(json.dumps({identity: '24'}))
        self.ctx.setting('org.cinnamon.desktop.interface', 'cursor-size', 32)
        first = self.ctx.manifest_path.read_bytes()
        self.ctx.setting('org.cinnamon.desktop.interface', 'cursor-size', 32)
        self.assertEqual(first, self.ctx.manifest_path.read_bytes())
        engine.restore(self.ctx, 'icons')
        engine.restore(self.ctx, 'icons')
        self.assertEqual(self.ctx.get('org.cinnamon.desktop.interface', 'cursor-size'), '24')


if __name__ == '__main__':
    unittest.main()
