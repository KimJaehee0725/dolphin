---
type: change
title: "Docker secret context and attached-shell credential repair"
date: "2026-09-17 15:49 +0900"
status: completed
tags: [history, change]
agent: codex
---
# Change - Docker secret context and attached-shell credential repair

Date: 2026-09-17 15:49 +0900
Agent: codex
Status: completed

## Why

runtime.env was entering the Docker build context, attached zsh started before runtime credentials were written, optional tool tokens were not used, apt failures could be masked, and a legacy research-memory config remained.

## How

Added a restrictive .dockerignore, synchronized four tool credentials into private container-local files, reloaded or unset them through zsh hooks before prompts and commands, scoped the apt purge exception, and removed the obsolete auth-era research-memory config and config directory.

## Files

- .dockerignore
- .gitignore
- Dockerfile
- make_container.sh
- runtime.env.example
- README.md

## Validation

- bash syntax checks; extracted zshrc syntax check; shell command syntax checks; git diff check; remote track-research-history main equals pinned revision c90f27c; no live research-memory auth config remains.

## Risks / Follow-Ups

-

## Git Status Snapshot

```text
M .gitignore
 M AGENTS.md
 M Dockerfile
 M README.md
 M build_image.sh
 D config/.gitignore
 D config/README.md
 D config/runtime.env.example
 M history/INDEX.md
 M history/PROJECT_MAP.md
 M make_container.sh
?? .dockerignore
?? history/changes/2026-09-17-153132-dolphin-attach-shell-and-shared-p10k-configuration.md
?? history/changes/2026-09-17-153621-dolphin-root-configuration-layout-and-endpoint-clarification.md
?? history/daily/2026-09-17.md
?? p10k.zsh
?? runtime.env.example
?? sync_p10k_config.sh
```
