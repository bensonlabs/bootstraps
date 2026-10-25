#!/usr/bin/env python3
"""Read-only workstation verification with JSON reporting.

Uses workstation.yaml as the canonical inventory while intentionally avoiding a
YAML dependency. The parser extracts the stable subset used by this repository.
"""

from __future__ import annotations
import argparse
import datetime as dt
import json
import platform
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / "workstation.yaml"

PROFILE_ORDER = {
    "core": ["git", "gh", "node", "python", "ripgrep"],
    "developer": ["git", "gh", "node", "python", "ripgrep", "vscode", "fastfetch"],
    "ai-dev": ["git", "gh", "node", "python", "ripgrep", "vscode", "fastfetch", "claude", "codex"],
    "desktop": [],
    "full": ["git", "gh", "node", "python", "ripgrep", "vscode", "fastfetch", "claude", "codex"],
}

COMMAND_ALIASES = {"python": ["python", "python3"], "vscode": ["code"]}


def spec_version(text: str) -> str:
    match = re.search(r'^workstation_spec_version:\s*["\']?([^"\'\s]+)', text, re.MULTILINE)
    return match.group(1) if match else "unknown"


def command_for(tool: str, text: str) -> str:
    block = re.search(rf"^  {re.escape(tool)}:\s*$([\s\S]*?)(?=^  [a-zA-Z0-9_-]+:\s*$|^operations:)", text, re.MULTILINE)
    if not block:
        return tool
    match = re.search(r"^    command:\s*([^\s#]+)", block.group(1), re.MULTILINE)
    return match.group(1) if match else tool


def inspect_tool(tool: str, text: str) -> dict:
    declared = command_for(tool, text)
    candidates = COMMAND_ALIASES.get(tool, [declared])
    found = next((candidate for candidate in candidates if shutil.which(candidate)), None)
    result = {"status": "missing", "command": declared, "version": None}
    if not found:
        return result
    result["command"] = found
    try:
        proc = subprocess.run([found, "--version"], capture_output=True, text=True, timeout=10, check=False)
        output = (proc.stdout or proc.stderr).strip().splitlines()
        result["status"] = "pass" if proc.returncode == 0 else "warning"
        result["version"] = output[0] if output else None
    except (OSError, subprocess.TimeoutExpired) as exc:
        result["status"] = "warning"
        result["version"] = str(exc)
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", choices=PROFILE_ORDER, default="ai-dev")
    parser.add_argument("--output", default="machine-state.json")
    parser.add_argument("--no-write", action="store_true", help="Print report only; do not create JSON file.")
    args = parser.parse_args()

    text = SPEC.read_text(encoding="utf-8")
    tools = {name: inspect_tool(name, text) for name in PROFILE_ORDER[args.profile]}
    overall = "pass" if all(item["status"] == "pass" for item in tools.values()) else "nonconformant"
    report = {
        "timestamp": dt.datetime.now(dt.timezone.utc).isoformat(),
        "platform": platform.platform(),
        "architecture": platform.machine(),
        "profile": args.profile,
        "workstation_spec_version": spec_version(text),
        "status": overall,
        "tools": tools,
    }

    for name, item in tools.items():
        mark = "OK" if item["status"] == "pass" else "MISSING" if item["status"] == "missing" else "WARN"
        detail = f" ({item['version']})" if item["version"] else ""
        print(f"{mark:7} {name}{detail}")
    print(f"Overall: {overall}")

    payload = json.dumps(report, indent=2) + "\n"
    if args.no_write:
        print(payload, end="")
    else:
        Path(args.output).write_text(payload, encoding="utf-8")
        print(f"Report: {args.output}")
    return 0 if overall == "pass" else 2


if __name__ == "__main__":
    sys.exit(main())
