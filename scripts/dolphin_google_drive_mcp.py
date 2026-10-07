#!/usr/bin/env python3
"""Refresh the local Google OAuth token and start the Google Drive MCP server."""

from __future__ import annotations

import json
import os
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


TOKEN_URL = "https://oauth2.googleapis.com/token"


def _write_credentials(path: Path, credentials: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(path.parent, 0o700)
    descriptor, temporary_path = tempfile.mkstemp(prefix=".google-drive-", dir=path.parent)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as output:
            json.dump(credentials, output, separators=(",", ":"))
            output.write("\n")
        os.replace(temporary_path, path)
        os.chmod(path, 0o600)
    except BaseException:
        try:
            os.unlink(temporary_path)
        except FileNotFoundError:
            pass
        raise


def _refresh_if_needed(path: Path, credentials: dict[str, object]) -> None:
    expires_at = int(credentials.get("expires_at", 0))
    if credentials.get("access_token") and expires_at > int(time.time()) + 180:
        return

    body = urllib.parse.urlencode(
        {
            "client_id": credentials["client_id"],
            "client_secret": credentials["client_secret"],
            "refresh_token": credentials["refresh_token"],
            "grant_type": "refresh_token",
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        TOKEN_URL,
        data=body,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            updated = json.load(response)
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
        raise RuntimeError("Google token refresh failed. Run the OAuth helper to authorize again.") from None

    if not updated.get("access_token"):
        raise RuntimeError("Google did not return an access token. Reauthorize Google Drive.")
    credentials["access_token"] = updated["access_token"]
    credentials["expires_at"] = int(time.time() + int(updated.get("expires_in", 0)))
    credentials["scope"] = updated.get("scope", credentials.get("scope", ""))
    credentials["token_type"] = updated.get("token_type", "Bearer")
    if updated.get("refresh_token"):
        credentials["refresh_token"] = updated["refresh_token"]
    _write_credentials(path, credentials)


def main() -> int:
    home = Path(os.environ.get("HOME", str(Path.home())))
    credential_path = home / ".config/dolphin-auth/google-drive.json"
    if not credential_path.is_file():
        print(
            "Google Drive is not authorized. Run scripts/google_drive_auth.py with a Google OAuth Desktop client JSON file, then rerun make_container.sh.",
            file=sys.stderr,
        )
        return 1

    try:
        os.chmod(credential_path, 0o600)
        credentials = json.loads(credential_path.read_text(encoding="utf-8"))
        if not isinstance(credentials, dict):
            raise ValueError("The local Google Drive OAuth file must contain a JSON object.")
        required = ("client_id", "client_secret", "refresh_token")
        if any(not isinstance(credentials.get(key), str) or not credentials[key] for key in required):
            raise ValueError("The local Google Drive OAuth file is incomplete.")
        _refresh_if_needed(credential_path, credentials)
    except (OSError, ValueError, json.JSONDecodeError, RuntimeError) as error:
        print(f"Google Drive MCP could not load authorization: {error}", file=sys.stderr)
        return 1

    server_env = os.environ.copy()
    server_env["GOOGLE_DRIVE_MCP_ACCESS_TOKEN"] = str(credentials["access_token"])
    server_env["GOOGLE_DRIVE_MCP_REFRESH_TOKEN"] = str(credentials["refresh_token"])
    server_env["GOOGLE_DRIVE_MCP_CLIENT_ID"] = str(credentials["client_id"])
    server_env["GOOGLE_DRIVE_MCP_CLIENT_SECRET"] = str(credentials["client_secret"])
    server_env["GOOGLE_DRIVE_MCP_SCOPES"] = "drive,documents,spreadsheets,presentations"
    for name in tuple(server_env):
        if name.startswith("GDRIVE_ALIAS_"):
            server_env.pop(name)

    try:
        os.execvpe(
            "google-drive-mcp",
            ["google-drive-mcp", *sys.argv[1:]],
            server_env,
        )
    except OSError:
        print("Google Drive MCP executable is unavailable in the container.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
