#!/usr/bin/env python3
"""Resolve GDRIVE_ALIAS_* environment variables without displaying link URLs."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from urllib.parse import parse_qs, urlparse


PREFIX = "GDRIVE_ALIAS_"
ALIAS_PATTERN = re.compile(r"^[A-Z][A-Z0-9_]*$")
ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]+$")
HOSTS = {"drive.google.com", "docs.google.com"}
ID_PATHS = (
    (re.compile(r"^/drive/folders/([^/]+)"), "folder"),
    (re.compile(r"^/drive/u/[0-9]+/folders/([^/]+)"), "folder"),
    (re.compile(r"^/folders/([^/]+)"), "folder"),
    (re.compile(r"^/file/d/([^/]+)"), "file"),
    (re.compile(r"^/file/u/[0-9]+/d/([^/]+)"), "file"),
    (re.compile(r"^/document/d/([^/]+)"), "document"),
    (re.compile(r"^/document/u/[0-9]+/d/([^/]+)"), "document"),
    (re.compile(r"^/spreadsheets/d/([^/]+)"), "spreadsheet"),
    (re.compile(r"^/spreadsheets/u/[0-9]+/d/([^/]+)"), "spreadsheet"),
    (re.compile(r"^/presentation/d/([^/]+)"), "presentation"),
    (re.compile(r"^/presentation/u/[0-9]+/d/([^/]+)"), "presentation"),
    (re.compile(r"^/drawings/d/([^/]+)"), "drawing"),
    (re.compile(r"^/forms/d/([^/]+)"), "form"),
)


def _parse_target(alias: str, link: str) -> dict[str, str]:
    parsed = urlparse(link)
    try:
        hostname = parsed.hostname
    except ValueError:
        raise ValueError("link is malformed") from None
    if parsed.scheme != "https" or hostname not in HOSTS:
        raise ValueError("link must use https://drive.google.com or https://docs.google.com")

    item_id = ""
    kind = "file"
    for pattern, path_kind in ID_PATHS:
        match = pattern.match(parsed.path)
        if match:
            item_id = match.group(1)
            kind = path_kind
            break

    if not item_id:
        item_id = parse_qs(parsed.query).get("id", [""])[0]
        kind = "item"

    if not item_id or not ID_PATTERN.fullmatch(item_id):
        raise ValueError("link does not contain a supported Google Drive file or folder ID")
    return {"alias": alias, "id": item_id, "kind": kind}


def _aliases() -> list[dict[str, str]]:
    resolved = []
    errors = []
    for name, link in os.environ.items():
        if not name.startswith(PREFIX) or not link:
            continue
        alias = name[len(PREFIX) :]
        if not ALIAS_PATTERN.fullmatch(alias):
            errors.append(f"Invalid alias name: {name}")
            continue
        try:
            resolved.append(_parse_target(alias, link))
        except ValueError as error:
            errors.append(f"{alias}: {error}")
    if errors:
        raise ValueError("; ".join(errors))
    return sorted(resolved, key=lambda item: item["alias"])


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="dolphin-gdrive",
        description="List and resolve Google Drive aliases from GDRIVE_ALIAS_* environment variables.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("aliases", help="List alias names, Drive IDs, and item types")
    resolve_parser = subparsers.add_parser("resolve", help="Resolve one alias to its Drive ID")
    resolve_parser.add_argument("alias", help="Alias suffix, for example PROJECT_NOTES")
    args = parser.parse_args()

    try:
        aliases = _aliases()
        if args.command == "aliases":
            print(json.dumps(aliases, indent=2))
            return 0

        alias_name = args.alias.removeprefix(PREFIX)
        if not ALIAS_PATTERN.fullmatch(alias_name):
            raise ValueError("alias names must use uppercase letters, digits, and underscores")
        result = next((item for item in aliases if item["alias"] == alias_name), None)
        if result is None:
            raise ValueError(f"alias not found: {alias_name}")
        print(json.dumps(result, indent=2))
        return 0
    except ValueError as error:
        print(f"Google Drive alias error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
