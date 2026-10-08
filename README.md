# Dolphin

Docker-based development environment for research and coding agents.

## What It Includes

- CUDA 12.2 Ubuntu base image with Node.js, Python 3.12 via `uv`, GitHub CLI, Docker CLI, tmux, zsh, and common terminal tools.
- Korea Standard Time (`Asia/Seoul`, UTC+09:00) as the container timezone.
- OpenAI Codex CLI and Claude Code.
- DSBA Portal MCP configuration for Codex CLI and Claude Code, with runtime token loading.
- The pinned repository-local `track-research-history` skill with vendored BM25S recall and Obsidian project maps.
- The pinned `im-not-ai` Korean writing skill for Claude Code and Codex CLI.
- The pinned `research-slides` skill for Claude Code and Codex CLI, with PowerPoint templates, Python dependencies, LibreOffice, and NanumSquare fonts.

## Runtime Config

Use one local-only runtime file:

```bash
cp runtime.env.example runtime.env
vim runtime.env
chmod 600 runtime.env
```

`runtime.env` may contain tokens and is ignored by Git and the Docker build
context. The launcher stores non-empty tool credentials in mode `600`
container-local files. The attached zsh loads them before each command, so a
new or updated credential is available without restarting the container. Build
and start from the repo root:

```bash
bash build_image.sh
bash make_container.sh
```

Only machine-specific values belong in `runtime.env`: image name, container
name, mounts, ports, optional Docker socket access, runtime tokens, and Google
OAuth client credentials. The scripts automatically move an existing legacy
`config/runtime.env` to this new location without reading or printing its
content.

## Google Workspace MCP

The image registers `workspace-mcp==2.0.1` for Codex CLI and Claude Code.
Only Slides, Calendar, Sheets, Gmail, and Drive tools are enabled. Agents can
find items by name or use file links and IDs directly.

Create a Google Cloud project and enable the Google Slides, Google Calendar,
Google Sheets, Gmail, and Google Drive APIs. Configure the OAuth consent screen
and add your account as a test user if the app is in Testing status. Create an
OAuth client with the Desktop app type, then put its two values in the local
`runtime.env`:

```bash
GOOGLE_OAUTH_CLIENT_ID="YOUR_CLIENT_ID.apps.googleusercontent.com"
GOOGLE_OAUTH_CLIENT_SECRET="YOUR_CLIENT_SECRET"
GOOGLE_OAUTH_REFRESH_TOKEN=
```

The client secret is the app credential, not your Google account password.
You do not need to obtain a refresh token manually. Run the launcher with its
Google authorization option to sign in once and grant access:

```bash
bash make_container.sh --google-auth --no-attach
```

The helper uses a localhost callback, OAuth state, and PKCE. It saves the
account and tokens outside the repository at
`~/.config/dolphin-auth/google-workspace.json`, with directory mode `700` and
file mode `600`. The launcher transfers the client values and token file to
private container files through stdin. They are not embedded in the image or
Docker environment configuration. The MCP launcher reads these files even
from non-interactive agent sessions and automatically refreshes access tokens.

If you already have a refresh token for this OAuth client and all five APIs,
you may set `GOOGLE_OAUTH_REFRESH_TOKEN` in `runtime.env`. This optional value
takes precedence over the helper's saved token. It must also have the account
identity scopes used by the helper. Keep it empty to use automatic token storage.
After changing the client or adding API permissions, repeat browser consent.
Remove an old manual refresh token before reauthorizing with the helper.

For a remote host, forward the callback port from your local machine:

```bash
ssh -L 8765:127.0.0.1:8765 user@server
```

In another terminal on that host, load the env and run the helper at that port:

```bash
set -a
source runtime.env
set +a
python3 scripts/google_workspace_auth.py --no-browser --port 8765
bash make_container.sh --no-attach
```

Open the printed consent URL in your local browser. Desktop clients support
loopback callbacks; a Web application client must have the exact callback URI
registered, such as `http://127.0.0.1:8765/oauth2callback`.

The requested scopes allow reading and editing Drive files, Slides, Sheets,
Calendar events, and Gmail messages and settings. The helper also requests
Google account identity scopes to select the authorized account. Agents send
mail, create invitations, share files, or delete items only when the user asks.

Rebuild the image and recreate the container once to install the new MCP server:

```bash
bash build_image.sh
bash make_container.sh --recreate --no-attach
```

Later credential updates only require rerunning `make_container.sh` and
restarting the agent's MCP session. Empty client values disable the connection
and remove its container credentials. If the consent screen stays in Testing
status, refresh tokens may expire after seven days; repeat browser consent.

## LLM endpoint

The ordinary `codex` command keeps the default OpenAI provider. It has no custom
endpoint in this repository.

The image also includes a separate `dsba` profile. It uses the fixed LiteLLM
endpoint `https://dsba-server.duckdns.org:8022/llm/v1`, the runtime-only
`DSBA_LITELLM_API_KEY`, and model `gpt-5.6-sol`:

```bash
codex --profile dsba
```

Use `bash build_image.sh --no-cache` for a clean rebuild and
`bash make_container.sh --recreate --no-attach` after changing image or mount
settings. The runtime file only carries machine-specific names, mounts, ports,
an optional Docker-socket switch, and optional runtime credentials.

The container's PID 1 is an interactive login zsh shell. Both the launcher and
`docker attach <container name>` open that shell. Use `Ctrl-p Ctrl-q` to detach
without stopping it. The shared prompt configuration lives in
`p10k.zsh`. Run `p10k configure` in the container, then run
`bash sync_p10k_config.sh export` and commit `p10k.zsh` to use the same prompt
on every server. Run `bash sync_p10k_config.sh import` to apply it to an already
running container.

## Research History

The image installs `track-research-history` under
`~/.codex/skills/track-research-history`. Every mounted project keeps its own
Git-tracked `history/` folder; there is no central memory service, SQLite index,
password mode, SSH RPC, or extra runtime mount.

```bash
python3 ~/.codex/skills/track-research-history/scripts/history.py bootstrap
python3 ~/.codex/skills/track-research-history/scripts/history.py start --query "current task"
python3 ~/.codex/skills/track-research-history/scripts/history.py search "decision or experiment"
python3 ~/.codex/skills/track-research-history/scripts/history.py finish
```

Open a project's `history/` folder directly in Obsidian and use
`PROJECT_MAP.md` for portable links, backlinks, and graph navigation.

## Korean Writing Skill

The image installs `im-not-ai` from a pinned commit under
`~/.local/share/im-not-ai`. It links the Claude Code skills under
`~/.claude/skills/` and the Codex skill under
`~/.codex/skills/humanize-korean`. Start a new agent session to load the skill.
Use `$humanize-korean` in Codex or `/humanize-korean` in Claude Code.
The `IM_NOT_AI_REF` Docker build argument selects a different revision when
an update is needed.

## Research Slides Skill

The image installs `KimJaehee0725/research-slides` from a pinned commit under
`~/.local/share/research-slides` and links it into both
`~/.codex/skills/research-slides` and `~/.claude/skills/research-slides`.
Start a new agent session and use `$research-slides` in Codex or
`/research-slides` in Claude Code.

The image includes the upstream Python requirements, LibreOffice Impress,
poppler, pandoc, and NanumSquare fonts. Fontconfig maps the template's
`NanumSquareOTF` font names to the Linux fonts for rendering.

```bash
python ~/.codex/skills/research-slides/scripts/build_deck.py \
  ~/.codex/skills/research-slides/examples/pysr_example.json /tmp/research-slides.pptx
python ~/.codex/skills/research-slides/scripts/render_check.py \
  /tmp/research-slides.pptx --out /tmp/research-slides-render
```

The `RESEARCH_SLIDES_REF` Docker build argument selects another revision.
Rebuild the image and recreate the container to apply this addition.

## DSBA Portal MCP

The image registers `dsba_portal` in Codex and `dsba-portal` in Claude Code.
Both launch `dolphin-dsba-portal-mcp`, which reads the runtime token and runs
`server-portal-mcp` through `uvx` at pinned commit
`eadbab403ca2e79a77bb0d45768ce20490e2f081`.
The first launch downloads the package and its dependencies. It needs access
to the GitHub repository; private repository access also needs GitHub authentication.

Issue a token in the server portal's API token tab and set it in your local
`runtime.env`:

```bash
DSBA_PORTAL_TOKEN=dsba_pat_...
```

Use a `read` token for queries or a `write` token for reservations, updates,
and returns. Build the image and recreate the container for the initial setup:

```bash
bash build_image.sh
bash make_container.sh --recreate --no-attach
```

For later token updates, rerun `bash make_container.sh --no-attach`, then start
a new agent session. The launcher stores the token in
`~/.config/dolphin-auth/dsba-portal.token` with mode `600` and removes the file
when the runtime value is empty. The token is supplied at runtime; MCP
configuration files contain no token value.

The tools include `list_servers`, `check_gpu_availability`, `register_usage`,
and `return_usage`. Example request:

> 다음 주 월요일부터 3일간 3번 서버 빈 GPU 2개 예약해 줘.

Check the connection in a new container agent session with `/mcp`.
You can also query the REST API from the attached container shell:

```bash
curl --fail --silent --show-error \
  -H "Authorization: Bearer ${DSBA_PORTAL_TOKEN}" \
  https://dsba-server.duckdns.org:8022/api/v1/servers
```

The full REST API specification is at
<https://dsba-server.duckdns.org:8022/api/v1/docs>.
