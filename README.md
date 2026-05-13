# Dolphin

Docker-based development environment for research and coding agents.

## What It Includes

- CUDA 12.2 Ubuntu base image with Node.js, Python 3.12 via `uv`, GitHub CLI, Docker CLI, tmux, zsh, and common terminal tools.
- OpenAI Codex CLI and Claude Code.

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
