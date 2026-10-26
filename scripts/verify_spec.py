#!/usr/bin/env python3
"""Validate workstation.yaml without third-party dependencies."""

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / "workstation.yaml"

required_literals = [
    "schema_version:",
    "workstation_spec_version:",
    "platforms:",
    "architectures:",
    "profiles:",
    "tools:",
    "operations:",
    "report:",
    "install:",
    "verify:",
    "upgrade:",
]

text = SPEC.read_text(encoding="utf-8")
errors = [f"missing required key/section: {item}" for item in required_literals if item not in text]

for tool in ("git", "gh", "node", "python", "ripgrep", "vscode", "fastfetch", "claude", "codex"):
    if not re.search(rf"^  {re.escape(tool)}:\s*$", text, re.MULTILINE):
        errors.append(f"missing canonical tool definition: {tool}")

expected_architecture_contracts = (
    ("windows", "x86_64", "supported"),
    ("windows", "arm64", "experimental"),
    ("fedora", "x86_64", "supported"),
    ("fedora", "arm64", "experimental"),
    ("ubuntu", "x86_64", "supported"),
    ("ubuntu", "arm64", "experimental"),
    ("macos", "arm64", "supported"),
    ("macos", "x86_64", "legacy"),
)
for platform, architecture, status in expected_architecture_contracts:
    platform_block = re.search(
        rf"^  {platform}:\s*$([\s\S]*?)(?=^  [a-z]+:\s*$|^profiles:)",
        text,
        re.MULTILINE,
    )
    if not platform_block or not re.search(
        rf"^      {architecture}:\s*{status}\s*$",
        platform_block.group(1),
        re.MULTILINE,
    ):
        errors.append(f"missing architecture contract: {platform}/{architecture}={status}")

if "Never" in text:
    errors.append("unexpected prose policy in machine specification")

if errors:
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    raise SystemExit(1)

print("workstation.yaml static contract OK")
