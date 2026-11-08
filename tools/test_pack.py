"""Tests for tools/pack.py: what is published, the checks, and reproducible releases."""
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import pack

PAGE = "---\nlayout: post\ntitle: \"Bootstraps\"\ndescription: \"Rebuild a machine.\"\n---\n\n## Windows\n"


class Site(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.site, self.dist = root / "site", root / "dist"
        self.site.mkdir()
        self.patches = [patch.object(pack, "SITE", self.site), patch.object(pack, "DIST", self.dist),
                        patch.object(pack, "OUT", self.dist / "bootstraps")]
        for p in self.patches:
            p.start()

    def tearDown(self):
        for p in self.patches:
            p.stop()
        self.tmp.cleanup()

    def write(self, rel, text):
        path = self.site / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8", newline="\n")

    def test_publishes_the_page_and_what_it_links_to_only(self):
        self.write("index.md", PAGE)
        self.write("img/shot.png", "png")
        self.write("notes.md", "not published")
        self.write(".hidden", "not published")
        self.write("draft/x.txt", "ignored")
        self.write(".publishignore", "draft/*\n")
        self.assertEqual(pack.pack(), ["img/shot.png", "index.md"])
        self.assertEqual(pack.check(), [])

    def test_the_page_must_be_there_and_say_what_it_is(self):
        pack.pack()
        self.assertIn("index.md: missing", "\n".join(pack.check()))
        self.write("index.md", "## No front matter\n")
        pack.pack()
        self.assertIn("needs front matter", "\n".join(pack.check()))
        self.write("index.md", "---\nlayout: post\ntitle: Bootstraps\n---\n")
        pack.pack()
        self.assertEqual(pack.check(), ["index.md: its front matter needs description:"])

    def test_the_page_stays_at_its_address(self):
        self.write("index.md", PAGE.replace("---\n\n", "permalink: /about/\n---\n\n"))
        pack.pack()
        self.assertEqual(pack.check(), ["index.md: permalink: would move the page away from /bootstraps/ "
                                        "(the blog refuses it)"])

    def test_a_file_over_the_limit_is_refused(self):
        self.write("index.md", PAGE)
        self.write("big.bin", "x" * (pack.MAX_FILE_BYTES + 1))
        pack.pack()
        self.assertIn("big.bin", "\n".join(pack.check()))

    def test_the_release_is_reproducible(self):
        self.write("index.md", PAGE)
        pack.pack()
        first = pack.write_release("v1.2.3").read_bytes()
        second = pack.write_release("v1.2.3").read_bytes()
        self.assertEqual(first, second)
        with tarfile.open(self.dist / "bootstraps-v1.2.3.tar.gz") as tar:
            self.assertEqual(tar.getnames(), ["index.md"])


if __name__ == "__main__":
    unittest.main()
