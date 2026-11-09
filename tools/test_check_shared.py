"""Tests for tools/check_shared.py, with the other repos faked (no network).

Shared by bensonlabs/games, bensonlabs/projects and bensonlabs/bootstraps (tools/test_check_shared.py):
the copies are identical, so change all three."""
import unittest

import check_shared as cs

PACK = '''import os

COMPONENT = "{component}"


def read_publishignore(folder):
    return []


@staticmethod
def publishable(folder, path, ignore):
    return {publishable}


def write_release(version):
    return version


def main():
    return "{component}"
'''


def pack(component, publishable="True"):
    return PACK.format(component=component, publishable=publishable)


class FakeRepos:
    """Every repo's files, as {repo: {path: text}}; refs other than main see the same files."""

    def __init__(self, files):
        self.files = files
        self.asked = []

    def fetch(self, repo, ref, path):
        self.asked.append((repo, ref, path))
        return self.files.get(repo, {}).get(path)


def same_everywhere(overrides=None):
    files = {}
    for repo in ("games", "projects", "bootstraps"):
        files[repo] = {path: f"shared {path}\n" for path, repos in cs.SHARED_FILES.items() if repo in repos}
        files[repo]["tools/pack.py"] = pack(repo)
    for (repo, path), text in (overrides or {}).items():
        files[repo][path] = text
    return files


class CompareTest(unittest.TestCase):
    def run_compare(self, repo, files, refs=None):
        fake = FakeRepos(files)
        problems, compared = cs.compare(repo, files[repo].get, fake.fetch, lambda other: (refs or {}).get(other, "main"))
        return problems, compared, fake

    def test_identical_copies_pass(self):
        problems, compared, _ = self.run_compare("games", same_everywhere())
        self.assertEqual(problems, [])
        # 4 files shared by three repos x 2 others + 2 files shared by two x 1 other + 3 functions x 2 others
        self.assertEqual(compared, 4 * 2 + 2 * 1 + 3 * 2)

    def test_a_changed_copy_fails_with_a_diff(self):
        files = same_everywhere({("projects", "tools/next_version.py"): "changed\n"})
        problems, _, _ = self.run_compare("games", files)
        self.assertEqual(len(problems), 1)
        self.assertIn("tools/next_version.py differs from bensonlabs/projects (main)", problems[0])
        self.assertIn("+changed", problems[0])

    def test_a_missing_copy_fails(self):
        files = same_everywhere()
        del files["bootstraps"]["tools/next_version.py"]
        problems, _, _ = self.run_compare("games", files)
        self.assertEqual(problems, ["tools/next_version.py is missing in bensonlabs/bootstraps (main)."])

    def test_files_a_repo_does_not_share_are_not_compared(self):
        _, _, fake = self.run_compare("bootstraps", same_everywhere())
        self.assertNotIn(".github/workflows/ci.yml", {path for _, _, path in fake.asked})

    def test_shared_functions_compare_alone(self):
        # The rest of pack.py differs per repo (COMPONENT, main), which is expected.
        problems, _, _ = self.run_compare("projects", same_everywhere())
        self.assertEqual(problems, [])
        files = same_everywhere({("games", "tools/pack.py"): pack("games", publishable="False")})
        problems, _, _ = self.run_compare("projects", files)
        self.assertEqual(len(problems), 1)
        self.assertIn("tools/pack.py: function publishable differs from bensonlabs/games (main)", problems[0])

    def test_a_missing_function_fails(self):
        files = same_everywhere({("bootstraps", "tools/pack.py"): pack("bootstraps").replace("def write_release", "def write_other")})
        problems, _, _ = self.run_compare("games", files)
        self.assertEqual(problems, ["tools/pack.py: function write_release is missing in bensonlabs/bootstraps (main)."])

    def test_the_other_repos_branch_is_used_when_it_exists(self):
        _, _, fake = self.run_compare("games", same_everywhere(), refs={"projects": "shared-change"})
        self.assertIn(("projects", "shared-change", "tools/next_version.py"), fake.asked)
        self.assertIn(("bootstraps", "main", "tools/next_version.py"), fake.asked)


class FunctionSourcesTest(unittest.TestCase):
    def test_includes_decorators_and_reports_missing(self):
        found = cs.function_sources(pack("games"), ("publishable", "nowhere"))
        self.assertTrue(found["publishable"].startswith("@staticmethod\ndef publishable"))
        self.assertIsNone(found["nowhere"])


class ThisRepoTest(unittest.TestCase):
    def test_every_file_listed_for_this_repo_exists(self):
        repo = cs.ROOT.name
        listed = [path for path, repos in cs.SHARED_FILES.items() if repo in repos]
        listed += [path for path, (_, repos) in cs.SHARED_FUNCTIONS.items() if repo in repos]
        if not listed:
            self.skipTest(f"this checkout's folder ({repo}) isn't one of the repos that share files")
        for path in listed:
            self.assertTrue((cs.ROOT / path).is_file(), f"{path} is listed as shared but missing here")
        for path, (names, repos) in cs.SHARED_FUNCTIONS.items():
            if repo in repos:
                found = cs.function_sources(cs.text_of((cs.ROOT / path).read_bytes()), names)
                self.assertEqual([n for n, src in found.items() if src is None], [], f"{path} lacks shared functions")


if __name__ == "__main__":
    unittest.main()
