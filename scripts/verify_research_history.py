#!/usr/bin/env python3
"""Check the pinned history skill installed for both agent discovery paths."""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path
import sys


REQUIRED_FEATURES = {"readonly-recall", "brief", "file-provenance", "record-relations", "scoped-finish"}


def run(script: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(script), *args], capture_output=True, text=True, check=True)


def verify(codex: Path, claude: Path, revision: str) -> dict:
    manifests = []
    for target in (codex, claude):
        if (target / "REVISION").read_text(encoding="utf-8").strip() != revision:
            raise ValueError(f"Revision mismatch at {target}")
        manifest = json.loads((target / "INSTALLATION.json").read_text(encoding="utf-8"))
        if manifest.get("source_revision") != revision:
            raise ValueError(f"Manifest revision mismatch at {target}")
        for relative, expected in manifest["sha256"].items():
            relative_path = Path(relative)
            if relative_path.is_absolute() or ".." in relative_path.parts or "runtime.env" in relative_path.parts:
                raise ValueError(f"Invalid payload path in installation manifest: {relative!r}")
            path = target / relative_path
            if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
                raise ValueError(f"Payload hash mismatch at {path}")
        for relative in ("SKILL.md", "README.md", "scripts/history.py", "scripts/history_git.py", "scripts/history_relations.py", "scripts/vendor/bm25s/__init__.py"):
            if relative not in manifest["sha256"]:
                raise ValueError(f"Required payload absent from manifest: {relative}")
        script = target / "scripts/history.py"
        capabilities = json.loads(run(script, "--capabilities").stdout)
        if capabilities.get("backend") != "vendored-bm25s" or not REQUIRED_FEATURES.issubset(capabilities.get("features", [])):
            raise ValueError(f"Unsupported history capability set at {target}")
        if capabilities != manifest["capabilities"]:
            raise ValueError(f"Installed capabilities differ from manifest at {target}")
        version = run(script, "--version").stdout.strip()
        help_text = run(script, "commits", "--help").stdout
        if not all(flag in help_text for flag in ("--file", "--ref", "--json")):
            raise ValueError(f"File provenance CLI is missing at {target}")
        with tempfile.TemporaryDirectory(prefix="dolphin-history-smoke-") as temporary:
            fixture = Path(temporary)
            run(script, "--root", str(fixture), "start", "--brief", "--query", "unrecorded_smoke_identifier")
            if list(fixture.iterdir()):
                raise ValueError("Read-only startup unexpectedly created history")
            note = fixture / "history/decisions/0001-smoke.md"
            note.parent.mkdir(parents=True)
            note.write_text("---\ntype: decision\nstatus: accepted\n---\n# Smoke decision\n\n## Decision\n\nsmoke_identifier preserves the pinned history behavior.\n", encoding="utf-8")
            before = {path.relative_to(fixture).as_posix(): path.read_bytes() for path in fixture.rglob("*") if path.is_file()}
            payload = json.loads(run(script, "--root", str(fixture), "search", "smoke_identifier", "--json").stdout)
            if not payload["results"] or payload["results"][0]["path"] != "history/decisions/0001-smoke.md":
                raise ValueError("Vendored BM25S did not retrieve the fixture decision")
            after = {path.relative_to(fixture).as_posix(): path.read_bytes() for path in fixture.rglob("*") if path.is_file()}
            if before != after:
                raise ValueError("Read-only BM25 search changed fixture files")
        manifests.append(manifest)
    if manifests[0] != manifests[1]:
        raise ValueError("Codex and Claude history manifests differ")
    return {"revision": revision, "version": version, "targets": [str(codex), str(claude)], "checks": ["matching-manifests", "payload-hashes", "capabilities", "readonly-start", "bm25-retrieval", "file-provenance-cli"]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--codex", type=Path, required=True)
    parser.add_argument("--claude", type=Path, required=True)
    parser.add_argument("--revision", required=True)
    args = parser.parse_args()
    try:
        result = verify(args.codex, args.claude, args.revision)
    except (OSError, ValueError, subprocess.CalledProcessError, KeyError) as exc:
        parser.exit(1, f"History installation verification failed: {exc}\n")
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
