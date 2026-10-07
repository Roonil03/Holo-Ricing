"""Original MIT tests for preserving comments and unrelated settings."""
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).parents[1] / 'scripts/lib'))
from jsonc import merge
from engine import Error


class JsoncTests(unittest.TestCase):
    def test_nested_merge_preserves_comments_and_keys(self):
        source = '{// comment\n"a": {"keep": "// text", /*nested*/ "change": 1,}, "b": [1,2,],}'
        result = merge(source, {'a': {'change': 2, 'new': True}})
        self.assertIn('// comment', result)
        self.assertIn('/*nested*/', result)
        self.assertIn('"keep": "// text"', result)
        self.assertIn('"b": [1,2,]', result)
        self.assertEqual(result, merge(result, {'a': {'change': 2, 'new': True}}))

    def test_empty_commented_object(self):
        result = merge('{/*keep*/}', {'setting': {'color': '#151022'}})
        self.assertIn('/*keep*/', result)
        self.assertEqual(result, merge(result, {'setting': {'color': '#151022'}}))

    def test_bad_input_and_duplicates_refused(self):
        for source in ('{"x":1,"x":2}', '{bad}', '{"a":1 "b":2}', '[]', '{} {}'):
            with self.subTest(source=source), self.assertRaises(Error):
                merge(source, {'a': 3})
