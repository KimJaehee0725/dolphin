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

## Optional Central Research Memory

Set `RESEARCH_MEMORY_ENABLED=1` in the local `config/runtime.env` to give a
new or existing Dolphin container a selected project-scoped research-memory
profile. Dolphin mounts only the required client code, non-secret profile
config, one private key, and `known_hosts` as read-only files; the image does
not contain any SSH key.

The integration is opt-in and requires a container recreation when its mounts
are first added or changed. See [config/README.md](config/README.md#optional-research-memory-access)
for the exact path settings, verification behavior, and in-container commands.
