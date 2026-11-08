#!/usr/bin/env python3
"""Pack the bootstraps page for bensonlabs.org/bootstraps/.

    python3 tools/pack.py                    # pack and check: dist/bootstraps/
    python3 tools/pack.py --version v1.2.3   # also write dist/bootstraps-v1.2.3.tar.gz and its .sha256

(`py` instead of `python3` on Windows.) The release holds what a browser needs from site/: the
page, index.md, which the blog's Jekyll renders with its post layout and the site header, and
any file it links to. Hidden files, other Markdown and what a .publishignore lists stay out.

The checks refuse a pack without the page, a page without a layout, title or description, a page
that sets its own address (permalink or redirect_from), and a file over 750 KB.

The blog (bensonlabs/blog) downloads the release, checks its sha256, unpacks it into /bootstraps/
and builds it with the rest of the site, after its own checks (its Update components workflow).
"""
from __future__ import annotations

import argparse
import fnmatch
import gzip
import hashlib
import io
import re
import shutil
import sys
import tarfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SITE = REPO_ROOT / "site"
DIST = REPO_ROOT / "dist"
OUT = DIST / "bootstraps"
COMPONENT = "bootstraps"  # the pack is <COMPONENT>-<version>.tar.gz
MAX_FILE_BYTES = 750 * 1024
NEVER_PUBLISHED_SUFFIXES = {".md", ".rs", ".toml", ".ts", ".tsx", ".sh", ".lock"}
NEVER_PUBLISHED_NAMES = {"package.json", "package-lock.json", "tsconfig.json"}
NEVER_PUBLISHED_DIRS = {"node_modules", "dist"}
PUBLISHED_MARKDOWN = {"index.md"}  # the page, which Jekyll renders
FRONT_MATTER_RE = re.compile(r"\A---\r?\n(.*?)\r?\n---\r?\n", re.DOTALL)
FRONT_MATTER_KEY_RE = re.compile(r"^([A-Za-z_][\w-]*):(.*)$")
REQUIRED_KEYS = ("layout", "title", "description")
CLAIMING_KEYS = ("permalink", "redirect_from")


# Shared by bensonlabs/games, bensonlabs/projects and bensonlabs/bootstraps: keep this function
# identical in all three tools/pack.py.
def read_publishignore(folder: Path) -> list[str]:
    path = folder / ".publishignore"
    if not path.is_file():
        return []
    lines = (line.strip() for line in path.read_text(encoding="utf-8").splitlines())
    return [line for line in lines if line and not line.startswith("#")]


# Shared by bensonlabs/games, bensonlabs/projects and bensonlabs/bootstraps: keep this function
# identical in all three tools/pack.py.
def publishable(folder: Path, path: Path, ignore: list[str]) -> bool:
    rel = path.relative_to(folder)
    if any(part.startswith(".") for part in rel.parts):
        return False
    if any(part in NEVER_PUBLISHED_DIRS for part in rel.parts[:-1]):
        return False
    if path.name in PUBLISHED_MARKDOWN:
        return True
    if path.suffix.lower() in NEVER_PUBLISHED_SUFFIXES or path.name in NEVER_PUBLISHED_NAMES:
        return False
    return not any(fnmatch.fnmatch(rel.as_posix(), pattern) for pattern in ignore)


# Shared by bensonlabs/games, bensonlabs/projects and bensonlabs/bootstraps: keep this function
# identical in all three tools/pack.py.
def write_release(version: str) -> Path:
    """Pack OUT reproducibly (sorted entries, fixed times and modes): the same files
    always give the same sha256."""
    name = f"{COMPONENT}-{version}.tar.gz"
    files = sorted((p for p in OUT.rglob("*") if p.is_file()), key=lambda p: p.relative_to(OUT).as_posix())
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w", format=tarfile.PAX_FORMAT) as tar:
        for path in files:
            info = tarfile.TarInfo(path.relative_to(OUT).as_posix())
            info.size = path.stat().st_size
            info.mode = 0o644
            info.mtime = 0
            with path.open("rb") as handle:
                tar.addfile(info, handle)
    archive = DIST / name
    with archive.open("wb") as raw, gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as gz:
        gz.write(buffer.getvalue())
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (DIST / f"{name}.sha256").write_text(f"{digest}  {name}\n", encoding="utf-8", newline="\n")
    return archive



def pack() -> list[str]:
    """Copy what a browser needs from site/ into OUT; returns the files, relative to OUT."""
    if OUT.exists():
        shutil.rmtree(OUT)
    ignore = read_publishignore(SITE)
    files = []
    for path in sorted(p for p in SITE.rglob("*") if p.is_file()):
        if publishable(SITE, path, ignore):
            rel = path.relative_to(SITE)
            target = OUT / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
            files.append(rel.as_posix())
    return files


def front_matter(text: str) -> dict[str, str] | None:
    """The page's top-level front matter keys and their one-line values; None without front matter."""
    match = FRONT_MATTER_RE.match(text.removeprefix("\ufeff"))
    if not match:
        return None
    found = {}
    for line in match.group(1).splitlines():
        key = FRONT_MATTER_KEY_RE.match(line)
        if key:
            found[key.group(1)] = key.group(2).strip().strip("\"'")
    return found


def check() -> list[str]:
    """The page is there, says what it is and stays at /bootstraps/; no file is too big."""
    errors = []
    page = OUT / "index.md"
    if not page.is_file():
        errors.append("index.md: missing; it's bensonlabs.org/bootstraps/, which the site menu opens")
    else:
        keys = front_matter(page.read_text(encoding="utf-8"))
        if keys is None:
            errors.append("index.md: needs front matter (layout, title, description) for the blog to render it")
        else:
            errors += [f"index.md: its front matter needs {key}:" for key in REQUIRED_KEYS if not keys.get(key)]
            errors += [f"index.md: {key}: would move the page away from /bootstraps/ (the blog refuses it)"
                       for key in CLAIMING_KEYS if key in keys]
    for path in sorted(p for p in OUT.rglob("*") if p.is_file()):
        size = path.stat().st_size
        if size > MAX_FILE_BYTES:
            errors.append(f"{path.relative_to(OUT).as_posix()}: {size // 1024} KB, over the "
                          f"{MAX_FILE_BYTES // 1024} KB a published file may have")
    return errors


def main() -> None:
    parser = argparse.ArgumentParser(description="Pack the bootstraps page for bensonlabs.org/bootstraps/.")
    parser.add_argument("--version", help="also write the release file, for example v1.2.3")
    args = parser.parse_args()
    files = pack()
    errors = check()
    if errors:
        sys.exit("\n".join(errors))
    print(f"Packed {len(files)} file{'s' if len(files) != 1 else ''} in dist/bootstraps/")
    if args.version:
        archive = write_release(args.version)
        print((DIST / f"{archive.name}.sha256").read_text(encoding="utf-8").strip())


if __name__ == "__main__":
    main()
