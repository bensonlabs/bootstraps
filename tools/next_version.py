#!/usr/bin/env python3
"""Decide whether a fresh pack is a new release, and name it.

Shared by bensonlabs/games, bensonlabs/projects and bensonlabs/bootstraps (tools/next_version.py):
the copies are identical, so change all three.

    python3 tools/next_version.py --packed dist/<name>-v0.0.0.tar.gz --latest v1.0.3 --published-sha <sha>

Packs are reproducible, so the same content always gives the same sha256. If the fresh pack
matches the latest release's, nothing the site shows has changed: print nothing. Otherwise copy
the pack to dist/<name>-<next>.tar.gz (<name> is the pack's own: games or projects), write its
.sha256, and print <next>: the latest version with its last number raised (v1.0.3 -> v1.0.4), or
v1.0.0 when there is no release yet.
"""
from __future__ import annotations

import argparse
import hashlib
import shutil
import sys
from pathlib import Path


def bumped(latest: str | None) -> str:
    if not latest:
        return "v1.0.0"
    parts = latest.lstrip("v").split(".")
    if len(parts) != 3 or not all(part.isdigit() for part in parts):
        sys.exit(f"the latest release {latest!r} isn't a version like v1.2.3")
    major, minor, patch = (int(part) for part in parts)
    return f"v{major}.{minor}.{patch + 1}"


def plan(packed: Path, latest: str | None, published_sha: str | None) -> str | None:
    digest = hashlib.sha256(packed.read_bytes()).hexdigest()
    if published_sha and digest == published_sha.strip():
        return None
    version = bumped(latest)
    component = packed.name.removesuffix(".tar.gz").rsplit("-v", 1)[0]
    name = f"{component}-{version}.tar.gz"
    shutil.copyfile(packed, packed.parent / name)
    (packed.parent / f"{name}.sha256").write_text(f"{digest}  {name}\n", encoding="utf-8", newline="\n")
    return version


def main() -> None:
    parser = argparse.ArgumentParser(description="Decide whether a fresh pack is a new release.")
    parser.add_argument("--packed", required=True, type=Path)
    parser.add_argument("--latest", default="")
    parser.add_argument("--published-sha", default="")
    args = parser.parse_args()
    version = plan(args.packed, args.latest or None, args.published_sha or None)
    if version:
        print(version)


if __name__ == "__main__":
    main()
