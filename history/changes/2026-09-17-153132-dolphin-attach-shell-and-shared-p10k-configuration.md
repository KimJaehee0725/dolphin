---
type: change
title: "Dolphin attach shell and shared p10k configuration"
date: "2026-09-17 15:31 +0900"
status: completed
tags: [history, change]
agent: codex
---
# Change - Dolphin attach shell and shared p10k configuration

Date: 2026-09-17 15:31 +0900
Agent: codex
Status: completed

## Why

sleep infinity received docker attach without an interactive shell, and p10k settings needed a repository-owned cross-server source of truth.

## How

Changed the container PID 1 command to zsh -il, added old-container detection, added config/p10k.zsh plus sync_p10k_config.sh, and documented configure export import workflow.

## Files

- make_container.sh
- Dockerfile
- config/p10k.zsh
- sync_p10k_config.sh

## Validation

- bash -n make_container.sh build_image.sh sync_p10k_config.sh; git diff --check; Docker build static check unavailable because this Docker installation has no buildx component.

## Risks / Follow-Ups

-

## Git Status Snapshot

```text
M Dockerfile
 M README.md
 M config/README.md
 M make_container.sh
?? config/p10k.zsh
?? config/research-memory.env
?? sync_p10k_config.sh
```
