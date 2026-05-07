# Dolphin

Docker-based development environment for research and coding agents.

## What It Includes

- CUDA 12.2 Ubuntu base image with Node.js, Python 3.12 via `uv`, GitHub CLI, Docker CLI, tmux, zsh, and common terminal tools.
- OpenAI Codex CLI and Claude Code.
- Shared agent skill directories:
  - `~/.codex/skills`
  - `~/.claude/skills`
- `track-research-history` installed from `https://github.com/KimJaehee0725/track-research-history.git` into both skill directories so Codex and Claude can discover the same repository-history workflow.

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
