#!/usr/bin/env python3
"""Check that the files this repo shares with the other bensonlabs content repos still match.

Shared by bensonlabs/games, bensonlabs/projects and bensonlabs/bootstraps (tools/check_shared.py):
the copies are identical, so change all three.

Each shared file must be byte for byte the same as its copy in every other repo that shares it, and
each shared function in tools/pack.py must have the same source (read with Python's ast). The other
repo's copy comes from the branch with this branch's name when that branch exists there, else from
main. So to change a shared file: make the same change in every repo that shares it, on one branch
name, push all those branches, then open the pull requests. A difference fails the check.

    python3 tools/check_shared.py

In GitHub Actions it reads GITHUB_REPOSITORY, GITHUB_HEAD_REF (or GITHUB_REF_NAME) and GH_TOKEN;
by hand it asks git for the repo and branch, and reads the other repos without a token.
"""
from __future__ import annotations

import ast
import difflib
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Callable

OWNER = "bensonlabs"
ROOT = Path(__file__).resolve().parent.parent
# Whole files: path -> the repos that share it.
SHARED_FILES = {
    ".github/workflows/release.yml": ("games", "projects", "bootstraps"),
    "tools/next_version.py": ("games", "projects", "bootstraps"),
    "tools/check_shared.py": ("games", "projects", "bootstraps"),
    "tools/test_check_shared.py": ("games", "projects", "bootstraps"),
    ".github/workflows/ci.yml": ("games", "projects"),
    "tools/html_checks.py": ("games", "projects"),
}
# Functions inside a file whose other parts differ: path -> (function names, repos).
SHARED_FUNCTIONS = {
    "tools/pack.py": (("read_publishignore", "publishable", "write_release"), ("games", "projects", "bootstraps")),
}

Fetch = Callable[[str, str, str], "str | None"]  # (repo, ref, path) -> text, or None if missing


def text_of(raw: bytes) -> str:
    return raw.decode("utf-8").replace("\r\n", "\n")


def function_sources(text: str, names: tuple[str, ...]) -> dict[str, str | None]:
    """The source of each named top-level function (decorators included), or None if it's missing."""
    tree = ast.parse(text)
    found: dict[str, str | None] = dict.fromkeys(names)
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name in found:
            start = node.decorator_list[0].lineno if node.decorator_list else node.lineno
            found[node.name] = "\n".join(text.splitlines()[start - 1:node.end_lineno])
    return found


def short_diff(ours: str, theirs: str, here: str, there: str, limit: int = 30) -> str:
    lines = list(difflib.unified_diff(ours.splitlines(), theirs.splitlines(), here, there, lineterm="", n=1))
    if len(lines) > limit:
        lines = lines[:limit] + [f"... ({len(lines) - limit} more diff lines)"]
    return "\n".join(lines)


def compare(repo: str, read_local: Callable[[str], "str | None"], fetch: Fetch, ref_for: Callable[[str], str]) -> tuple[list[str], int]:
    """Every difference between this repo's shared files and the other repos' copies, and how many
    comparisons were made."""
    problems: list[str] = []
    compared = 0
    for path, repos in SHARED_FILES.items():
        if repo not in repos:
            continue
        ours = read_local(path)
        for other in repos:
            if other == repo:
                continue
            ref = ref_for(other)
            theirs = fetch(other, ref, path)
            compared += 1
            if ours is None or theirs is None:
                where = "here" if ours is None else f"in {OWNER}/{other} ({ref})"
                problems.append(f"{path} is missing {where}.")
            elif ours != theirs:
                problems.append(f"{path} differs from {OWNER}/{other} ({ref}):\n"
                                + short_diff(ours, theirs, f"{repo}/{path}", f"{other}@{ref}/{path}"))
    for path, (names, repos) in SHARED_FUNCTIONS.items():
        if repo not in repos:
            continue
        ours_text = read_local(path)
        ours = function_sources(ours_text, names) if ours_text is not None else dict.fromkeys(names)
        for other in repos:
            if other == repo:
                continue
            ref = ref_for(other)
            theirs_text = fetch(other, ref, path)
            theirs = function_sources(theirs_text, names) if theirs_text is not None else dict.fromkeys(names)
            for name in names:
                compared += 1
                if ours[name] is None or theirs[name] is None:
                    where = "here" if ours[name] is None else f"in {OWNER}/{other} ({ref})"
                    problems.append(f"{path}: function {name} is missing {where}.")
                elif ours[name] != theirs[name]:
                    problems.append(f"{path}: function {name} differs from {OWNER}/{other} ({ref}):\n"
                                    + short_diff(ours[name], theirs[name], f"{repo}/{path}", f"{other}@{ref}/{path}"))
    return problems, compared


def github_get(url: str, token: str | None, raw: bool) -> tuple[int, bytes]:
    headers = {"Accept": "application/vnd.github.raw" if raw else "application/vnd.github+json",
               "User-Agent": "bensonlabs-check-shared", "X-GitHub-Api-Version": "2022-11-28"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as err:
        if err.code == 404:
            return 404, b""
        raise SystemExit(f"Couldn't read {url}: HTTP {err.code}. Check the network or the token, then run this check again.")
    except urllib.error.URLError as err:
        raise SystemExit(f"Couldn't read {url}: {err.reason}. Check the network, then run this check again.")


def git_output(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()


def main() -> int:
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    slug = os.environ.get("GITHUB_REPOSITORY") or git_output("remote", "get-url", "origin")
    repo = slug.rstrip("/").removesuffix(".git").rsplit("/", 1)[-1]
    branch = os.environ.get("GITHUB_HEAD_REF") or os.environ.get("GITHUB_REF_NAME") or git_output("rev-parse", "--abbrev-ref", "HEAD")
    if repo not in {r for repos in SHARED_FILES.values() for r in repos}:
        print(f"{repo} shares no files listed here; nothing to check.")
        return 0

    refs: dict[str, str] = {}

    def ref_for(other: str) -> str:
        if other not in refs:
            refs[other] = "main"
            if branch and branch != "main":
                status, _ = github_get(f"https://api.github.com/repos/{OWNER}/{other}/branches/{urllib.parse.quote(branch, safe='')}", token, raw=False)
                if status == 200:
                    refs[other] = branch
        return refs[other]

    def fetch(other: str, ref: str, path: str) -> str | None:
        url = f"https://api.github.com/repos/{OWNER}/{other}/contents/{path}?ref={urllib.parse.quote(ref, safe='')}"
        status, body = github_get(url, token, raw=True)
        return None if status == 404 else text_of(body)

    def read_local(path: str) -> str | None:
        file = ROOT / path
        return text_of(file.read_bytes()) if file.is_file() else None

    problems, compared = compare(repo, read_local, fetch, ref_for)
    against = ", ".join(f"{OWNER}/{r} ({ref})" for r, ref in sorted(refs.items()))
    if problems:
        in_actions = os.environ.get("GITHUB_ACTIONS") == "true"
        for problem in problems:
            first = problem.splitlines()[0]
            if in_actions:
                print(f"::error title=Shared file differs::{first}")
            print(problem, end="\n\n")
        print(f"{len(problems)} difference(s) against {against}. Change every copy on one branch name "
              "in each repo, push those branches, then open the pull requests (tools/check_shared.py).")
        return 1
    print(f"All {compared} shared files and functions match {against}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
