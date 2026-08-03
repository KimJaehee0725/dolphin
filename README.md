# Dolphin

Docker-based development environment for research and coding agents.

## What It Includes

- CUDA 12.2 Ubuntu base image with Node.js, Python 3.12 via `uv`, GitHub CLI, Docker CLI, tmux, zsh, and common terminal tools.
- OpenAI Codex CLI and Claude Code.
- Repository-local Markdown research history with vendored BM25S recall and Obsidian project maps.

## Runtime Config

Use one local-only runtime file:

```bash
cp config/runtime.env.example config/runtime.env
vim config/runtime.env
chmod 600 config/runtime.env
```

`config/runtime.env` may contain tokens and is ignored by git. Build and start from the repo root:

```bash
bash build_image.sh
bash make_container.sh
```

See [config/README.md](config/README.md) for the full runtime configuration notes.

## Research History

The image installs `track-research-history` under
`~/.codex/skills/track-research-history`. Every mounted project keeps its own
Git-tracked `history/` folder; there is no central memory service, SQLite index,
password mode, SSH RPC, or extra runtime mount.

```bash
python3 ~/.codex/skills/track-research-history/scripts/history.py bootstrap
python3 ~/.codex/skills/track-research-history/scripts/history.py start --query "current task"
python3 ~/.codex/skills/track-research-history/scripts/history.py search "decision or experiment"
```

Open a project's `history/` folder directly in Obsidian and use
`PROJECT_MAP.md` for portable links, backlinks, and graph navigation.
