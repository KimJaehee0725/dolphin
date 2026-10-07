#!/usr/bin/env python3
"""Create a local OAuth token for the Dolphin Google Drive MCP server."""

from __future__ import annotations

import argparse
import base64
import hashlib
import http.server
import json
import os
import secrets
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from pathlib import Path


SCOPES = (
    "https://www.googleapis.com/auth/drive",
    "https://www.googleapis.com/auth/documents",
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/presentations",
)
AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_URL = "https://oauth2.googleapis.com/token"
DEFAULT_TOKEN_FILE = Path.home() / ".config/dolphin-auth/google-drive.json"


class OAuthCallbackHandler(http.server.BaseHTTPRequestHandler):
    server: "OAuthCallbackServer"

    def do_GET(self) -> None:
        request_url = urllib.parse.urlsplit(self.path)
        if request_url.path != "/oauth2callback":
            self.send_error(404)
            return

        params = urllib.parse.parse_qs(request_url.query)
        returned_state = params.get("state", [""])[0]
        if returned_state != self.server.expected_state:
            self.server.result = {"error": "OAuth state did not match."}
            self._respond(400, "Authorization failed. Return to the terminal.")
        elif params.get("error"):
            self.server.result = {"error": "Google authorization was declined."}
            self._respond(400, "Authorization was declined. Return to the terminal.")
        elif not params.get("code"):
            self.server.result = {"error": "Google did not return an authorization code."}
            self._respond(400, "Authorization failed. Return to the terminal.")
        else:
            self.server.result = {"code": params["code"][0]}
            self._respond(200, "Authorization complete. Return to the terminal.")
        self.server.callback_received.set()

    def log_message(self, _format: str, *_args: object) -> None:
        # The default server log includes the callback URL and authorization code.
        return

    def _respond(self, status: int, message: str) -> None:
        body = (
            "<!doctype html><html><meta charset='utf-8'><title>Google Drive</title>"
            f"<body><p>{message}</p></body></html>"
        ).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


class OAuthCallbackServer(http.server.HTTPServer):
    def __init__(self, address: tuple[str, int], expected_state: str):
        super().__init__(address, OAuthCallbackHandler)
        self.expected_state = expected_state
        self.callback_received = threading.Event()
        self.result: dict[str, str] | None = None
        self.timeout = 1


def _read_client(client_file: Path) -> tuple[str, str]:
    try:
        data = json.loads(client_file.read_text(encoding="utf-8"))
        client = data.get("installed") or {}
        client_id = client.get("client_id")
        client_secret = client.get("client_secret")
    except (OSError, json.JSONDecodeError, AttributeError):
        raise ValueError("Could not read a Google OAuth client credentials JSON file.") from None

    if not isinstance(client_id, str) or not isinstance(client_secret, str):
        raise ValueError("The OAuth client file must contain client_id and client_secret.")
    return client_id, client_secret


def _b64url(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def _build_auth_url(
    client_id: str,
    redirect_uri: str,
    state: str,
    code_challenge: str,
) -> str:
    params = {
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": " ".join(SCOPES),
        "access_type": "offline",
        "prompt": "consent",
        "state": state,
        "code_challenge": code_challenge,
        "code_challenge_method": "S256",
    }
    return f"{AUTH_URL}?{urllib.parse.urlencode(params)}"


def _exchange_code(
    client_id: str,
    client_secret: str,
    code: str,
    redirect_uri: str,
    code_verifier: str,
) -> dict[str, object]:
    body = urllib.parse.urlencode(
        {
            "code": code,
            "client_id": client_id,
            "client_secret": client_secret,
            "redirect_uri": redirect_uri,
            "grant_type": "authorization_code",
            "code_verifier": code_verifier,
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
            tokens = json.load(response)
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
        raise RuntimeError("Google token exchange failed. Check the OAuth setup and try again.") from None

    if not tokens.get("refresh_token") or not tokens.get("access_token"):
        raise RuntimeError(
            "Google did not return a refresh token. Revoke this app's access and run the helper again."
        )
    tokens["expires_at"] = int(time.time() + int(tokens.get("expires_in", 0)))
    return tokens


def _write_token_file(
    token_file: Path,
    client_id: str,
    client_secret: str,
    tokens: dict[str, object],
) -> None:
    token_file.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(token_file.parent, 0o700)
    payload = {
        "client_id": client_id,
        "client_secret": client_secret,
        "access_token": tokens["access_token"],
        "refresh_token": tokens["refresh_token"],
        "expires_at": tokens["expires_at"],
        "scope": tokens.get("scope", ""),
        "token_type": tokens.get("token_type", "Bearer"),
    }
    encoded = json.dumps(payload, separators=(",", ":"))
    descriptor, temporary_path = tempfile.mkstemp(prefix=".google-drive-", dir=token_file.parent)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as output:
            output.write(encoded)
            output.write("\n")
        os.replace(temporary_path, token_file)
        os.chmod(token_file, 0o600)
    except BaseException:
        try:
            os.unlink(temporary_path)
        except FileNotFoundError:
            pass
        raise


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Authorize Google Drive access and save a local token for Dolphin."
    )
    parser.add_argument("oauth_client_json", type=Path, help="Google OAuth Desktop client JSON file")
    parser.add_argument(
        "--port",
        type=int,
        default=0,
        help="Fixed callback port for an SSH tunnel, or 0 to select an available local port",
    )
    parser.add_argument(
        "--no-browser",
        action="store_true",
        help="Print the authorization URL instead of opening a browser",
    )
    args = parser.parse_args()

    if args.port < 0 or args.port > 65535:
        parser.error("--port must be between 0 and 65535")

    try:
        client_id, client_secret = _read_client(args.oauth_client_json)
        state = secrets.token_urlsafe(32)
        verifier = _b64url(secrets.token_bytes(32))
        challenge = _b64url(hashlib.sha256(verifier.encode("ascii")).digest())
        server = OAuthCallbackServer(("127.0.0.1", args.port), state)
        port = server.server_address[1]
        redirect_uri = f"http://127.0.0.1:{port}/oauth2callback"
        auth_url = _build_auth_url(client_id, redirect_uri, state, challenge)

        print("Start Google sign-in in the browser.")
        browser_opened = False
        if not args.no_browser:
            try:
                browser_opened = webbrowser.open(auth_url)
            except webbrowser.Error:
                browser_opened = False
        if not browser_opened:
            print(f"Open this URL in a browser:\n{auth_url}")
        if args.port:
            print(f"OAuth callback port: {port}")

        deadline = time.monotonic() + 300
        while not server.callback_received.is_set() and time.monotonic() < deadline:
            server.handle_request()
        server.server_close()

        if not server.callback_received.is_set():
            raise RuntimeError("Authorization timed out after five minutes.")
        if not server.result or "code" not in server.result:
            raise RuntimeError((server.result or {}).get("error", "Authorization failed."))

        tokens = _exchange_code(
            client_id,
            client_secret,
            server.result["code"],
            redirect_uri,
            verifier,
        )
        _write_token_file(DEFAULT_TOKEN_FILE, client_id, client_secret, tokens)
    except (OSError, RuntimeError, ValueError) as error:
        print(f"Google Drive authorization failed: {error}", file=sys.stderr)
        return 1

    print(f"Google Drive authorization saved to {DEFAULT_TOKEN_FILE}")
    print("Run bash make_container.sh to sync the credentials to the container.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
