"""Original MIT tests for the disabled, test-only rotation model."""
from pathlib import Path
import ast
import json
import subprocess
import tempfile
import unittest

REPO = Path(__file__).parents[2]


class LockTests(unittest.TestCase):
    def test_three_image_order_unlock_and_state_recovery(self):
        with tempfile.TemporaryDirectory(prefix='ina-rotation-') as directory:
            root = Path(directory)
            images = []
            for index in range(4):
                file = root / f'image {index}.png'
                file.write_bytes(b'\x89PNG\r\n\x1a\n' + bytes([index]))
                images.append(file)
            args = ['bash', str(REPO / 'Ina/scripts/lockscreen.sh'), '--test-root', directory, '--apply', '--approved', '--image', str(images[0]), '--images', *(str(x) for x in images[1:])]
            result = subprocess.run(args + ['--simulate-events', 'locked', 'tick', 'tick', 'tick', 'unlocked'], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            output = result.stdout
            positions = [output.index(x.as_uri()) for x in images[1:]]
            self.assertEqual(positions, sorted(positions))
            values = json.loads((root / 'settings.json').read_text())
            self.assertEqual(ast.literal_eval(values['org.cinnamon.desktop.background/picture-uri']), images[0].as_uri())
            self.assertEqual(json.loads((root / 'state/lock-rotation.json').read_text())['next_index'], 1)
            result = subprocess.run(['bash', str(REPO / 'Ina/scripts/restore.sh'), '--test-root', directory, '--component', 'lockscreen', '--apply'], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse((root / 'state/lock-rotation.json').exists())

    def test_duplicate_images_refused(self):
        with tempfile.TemporaryDirectory(prefix='ina-rotation-') as directory:
            image = Path(directory) / 'image.png'
            image.write_bytes(b'\x89PNG\r\n\x1a\n')
            result = subprocess.run(['bash', str(REPO / 'Ina/scripts/lockscreen.sh'), '--test-root', directory, '--apply', '--approved', '--image', str(image), '--images', *(str(image) for _ in range(3))], text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((Path(directory) / 'settings.json').exists())
