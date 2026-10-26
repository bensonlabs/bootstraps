#!/usr/bin/env python3
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]

subprocess.run([sys.executable, str(ROOT / "scripts" / "verify_spec.py")], check=True)

with tempfile.TemporaryDirectory() as tmp:
    report = Path(tmp) / "state.json"
    proc = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "verify_workstation.py"), "--profile", "core", "--output", str(report)],
        check=False,
    )
    assert proc.returncode in (0, 2)
    data = json.loads(report.read_text(encoding="utf-8"))
    assert data["profile"] == "core"
    assert data["workstation_spec_version"] == "1.1"
    assert set(data["tools"]) == {"git", "gh", "node", "python", "ripgrep"}
    assert data["status"] in {"pass", "nonconformant"}

print("workstation verification contract OK")
