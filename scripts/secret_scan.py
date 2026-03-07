#!/usr/bin/env python3
"""Fail fast if obvious secrets are committed in tracked files."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("service_account_private_key", re.compile(r'"private_key"\s*:\s*"-----BEGIN PRIVATE KEY-----')),
    ("oauth_client_secret", re.compile(r'"client_secret"\s*:\s*"GOCSPX-')),
    ("openai_api_key", re.compile(r"\bsk-[A-Za-z0-9]{20,}\b")),
]

ALLOW_PATH_PATTERNS = [
    re.compile(r"^docs/"),
    re.compile(r"^reports/"),
    re.compile(r"^audit-pack/reports/"),
]


def is_allowed(path: str) -> bool:
    return any(pattern.search(path) for pattern in ALLOW_PATH_PATTERNS)


def tracked_files() -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(ROOT), "ls-files"],
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def main() -> int:
    findings: list[str] = []
    for rel_path in tracked_files():
        if is_allowed(rel_path):
            continue
        abs_path = ROOT / rel_path
        if not abs_path.is_file():
            continue
        try:
            content = abs_path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for name, pattern in PATTERNS:
            if pattern.search(content):
                findings.append(f"{rel_path} ({name})")
                break

    if findings:
        print("Secret scan FAILED. Remove sensitive material from tracked files:")
        for finding in findings:
            print(f"- {finding}")
        return 1

    print("Secret scan PASS (no tracked secret patterns detected).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
