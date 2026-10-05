# Dolphin

Docker-based development environment for research and coding agents.

## What It Includes

- CUDA 12.2 Ubuntu base image with Node.js, Python 3.12 via `uv`, GitHub CLI, Docker CLI, tmux, zsh, and common terminal tools.
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
name, mounts, ports, optional Docker socket access, and tokens. The scripts
automatically move an existing legacy `config/runtime.env` to this new location
without reading or printing its content.

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
