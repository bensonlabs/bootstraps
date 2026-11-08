"""Tests for tools/next_version.py: a changed pack is the next release, an unchanged one is none."""
import hashlib
import tempfile
import unittest
from pathlib import Path

import next_version


class NextVersion(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.packed = Path(self.tmp.name) / 'bootstraps-v0.0.0.tar.gz'
        self.packed.write_bytes(b'packed games')
        self.digest = hashlib.sha256(b'packed games').hexdigest()

    def tearDown(self):
        self.tmp.cleanup()

    def test_an_unchanged_pack_is_no_release(self):
        self.assertIsNone(next_version.plan(self.packed, 'v1.0.3', self.digest))
        self.assertFalse((self.packed.parent / 'bootstraps-v1.0.4.tar.gz').exists())

    def test_a_changed_pack_is_the_next_patch_release(self):
        self.assertEqual(next_version.plan(self.packed, 'v1.0.3', 'f' * 64), 'v1.0.4')
        release = self.packed.parent / 'bootstraps-v1.0.4.tar.gz'
        self.assertEqual(release.read_bytes(), b'packed games')
        self.assertEqual((self.packed.parent / 'bootstraps-v1.0.4.tar.gz.sha256').read_text(encoding='utf-8'),
                         f'{self.digest}  bootstraps-v1.0.4.tar.gz' + chr(10))

    def test_the_first_release_is_v1_0_0(self):
        self.assertEqual(next_version.plan(self.packed, None, None), 'v1.0.0')

    def test_a_release_that_is_not_a_version_stops_it(self):
        with self.assertRaises(SystemExit):
            next_version.plan(self.packed, 'latest', 'f' * 64)


if __name__ == '__main__':
    unittest.main()
