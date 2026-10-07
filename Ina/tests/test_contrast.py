"""Original MIT checks for the text pairs selected by project components."""
from pathlib import Path
import re
import unittest


def luminance(color):
    values = [int(color[index:index + 2], 16) / 255 for index in (1, 3, 5)]
    values = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in values]
    return sum(v * factor for v, factor in zip(values, (.2126, .7152, .0722)))


class ContrastTests(unittest.TestCase):
    def test_selected_text_pairs_meet_project_threshold(self):
        source = (Path(__file__).parents[1] / 'dotfiles/colors.sh').read_text()
        colors = dict(re.findall(r"INA_([A-Z_]+)='(#[0-9A-F]{6})'", source))
        pairs = [('ANCIENT_PARCHMENT', 'ABYSS'), ('ANCIENT_PARCHMENT', 'DEEP_VIOLET'), ('MUTED_TEXT', 'ABYSS'), ('MUTED_TEXT', 'DEEP_VIOLET'), ('ELDRITCH_TEAL', 'DEEP_VIOLET'), ('INK', 'WARNING_ACCENT'), ('INK', 'LAVENDER'), ('INK', 'SOFT_PEACH')]
        for foreground, background in pairs:
            with self.subTest(foreground=foreground, background=background):
                low, high = sorted((luminance(colors[foreground]), luminance(colors[background])))
                self.assertGreaterEqual((high + .05) / (low + .05), 4.5)
