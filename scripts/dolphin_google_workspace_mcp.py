#!/usr/bin/env python3
"""Load private runtime OAuth values and start the five Google API tool groups."""

from __future__ import annotations

import datetime
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
SERVICES = ("slides", "calendar", "sheets", "gmail", "drive")


def _write_private(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(path.parent, 0o700)
    descriptor, temporary_path = tempfile.mkstemp(prefix=".google-workspace-", dir=path.parent)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as output:
            json.dump(payload, output, separators=(",", ":"))
            output.write("\n")
        os.replace(temporary_path, path)
    finally:
        if os.path.exists(temporary_path):
            os.unlink(temporary_path)


def _load_credentials(auth_dir: Path) -> dict:
    def read_secret(filename: str) -> str:
        path = auth_dir / filename
        if not path.is_file():
            return ""
        os.chmod(path, 0o600)
        return path.read_text(encoding="utf-8").strip()

    client_id = read_secret("google-client-id")
    client_secret = read_secret("google-client-secret")
    if not client_id or not client_secret:
        raise RuntimeError("Set GOOGLE_OAUTH_CLIENT_ID and GOOGLE_OAUTH_CLIENT_SECRET in runtime.env, then rerun make_container.sh.")

    credentials = {}
    path = auth_dir / "google-workspace.json"
    if path.is_file():
        os.chmod(path, 0o600)
        credentials = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(credentials, dict):
            raise ValueError("Invalid credential object.")
        if credentials.get("client_id") != client_id or credentials.get("client_secret") != client_secret:
            credentials = {}

    refresh_token = read_secret("google-refresh-token")
    if refresh_token and refresh_token != credentials.get("refresh_token"):
        credentials = {"refresh_token": refresh_token}
    credentials.update(client_id=client_id, client_secret=client_secret)
    if not credentials.get("refresh_token"):
        raise RuntimeError("First-time Google consent is required. Run bash make_container.sh --google-auth on the host, or set GOOGLE_OAUTH_REFRESH_TOKEN.")
    return credentials


def _refresh(credentials: dict) -> None:
    if credentials.get("access_token") and int(credentials.get("expires_at", 0)) > time.time() + 180:
        return
    body = urllib.parse.urlencode({
        "client_id": credentials["client_id"],
        "client_secret": credentials["client_secret"],
        "refresh_token": credentials["refresh_token"],
        "grant_type": "refresh_token",
    }).encode("utf-8")
    request = urllib.request.Request(TOKEN_URL, data=body, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            updated = json.load(response)
    except (urllib.error.URLError, TimeoutError, ValueError):
        raise RuntimeError("Google token refresh failed. Repeat Google consent with make_container.sh --google-auth.") from None
    if not updated.get("access_token"):
        raise RuntimeError("Google did not return an access token. Repeat Google consent.")
    credentials["access_token"] = updated["access_token"]
    credentials["expires_at"] = int(time.time() + int(updated.get("expires_in", 0)))
    credentials["scope"] = updated.get("scope", credentials.get("scope", ""))
    if updated.get("refresh_token"):
        credentials["refresh_token"] = updated["refresh_token"]


def _identify_account(credentials: dict) -> str:
    if isinstance(credentials.get("email"), str) and "@" in credentials["email"]:
        return credentials["email"]
    request = urllib.request.Request(
        "https://www.googleapis.com/oauth2/v2/userinfo",
        headers={"Authorization": f"Bearer {credentials['access_token']}"},
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            email = json.load(response).get("email", "")
    except (urllib.error.URLError, TimeoutError, ValueError):
        raise RuntimeError("Could not identify the Google account. Repeat Google consent with the updated helper.") from None
    if not isinstance(email, str) or "@" not in email:
        raise RuntimeError("Google did not return an account email. Repeat Google consent.")
    credentials["email"] = email
    return email


def main() -> int:
    auth_dir = Path.home() / ".config/dolphin-auth"
    try:
        credentials = _load_credentials(auth_dir)
        _refresh(credentials)
        email = _identify_account(credentials)
        scopes = credentials.get("scope", "").split()
        if not scopes:
            raise RuntimeError("Google scope metadata is missing. Repeat Google consent with the updated helper.")
        _write_private(auth_dir / "google-workspace.json", credentials)
        store_dir = auth_dir / "google-workspace-credentials"
        # This is the credential schema used by workspace-mcp 2.0.1.
        _write_private(store_dir / f"{urllib.parse.quote(email, safe='@._-')}.json", {
            "token": credentials["access_token"],
            "refresh_token": credentials["refresh_token"],
            "token_uri": TOKEN_URL,
            "client_id": credentials["client_id"],
            "client_secret": credentials["client_secret"],
            "scopes": scopes,
            "expiry": datetime.datetime.fromtimestamp(credentials["expires_at"], datetime.timezone.utc).replace(tzinfo=None).isoformat(),
        })
    except RuntimeError as error:
        print(f"Google Workspace MCP: {error}", file=sys.stderr)
        return 1
    except (OSError, ValueError, TypeError, KeyError):
        print("Google Workspace MCP: invalid or unreadable OAuth credentials. Repeat Google consent.", file=sys.stderr)
        return 1

    server_env = os.environ.copy()
    server_env.update(
        GOOGLE_OAUTH_CLIENT_ID=credentials["client_id"],
        GOOGLE_OAUTH_CLIENT_SECRET=credentials["client_secret"],
        USER_GOOGLE_EMAIL=email,
        WORKSPACE_MCP_CREDENTIALS_DIR=str(store_dir),
        MCP_ENABLE_OAUTH21="false",
    )
    os.umask(0o077)
    try:
        os.execvpe("workspace-mcp", ["workspace-mcp", "--single-user", "--tool-tier", "complete", "--tools", *SERVICES], server_env)
    except OSError:
        print("Google Workspace MCP executable is unavailable. Rebuild the Dolphin image.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
