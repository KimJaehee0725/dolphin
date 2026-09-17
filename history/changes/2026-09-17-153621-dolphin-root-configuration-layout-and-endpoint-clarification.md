---
type: change
title: "Dolphin root configuration layout and endpoint clarification"
date: "2026-09-17 15:36 +0900"
status: completed
tags: [history, change]
agent: codex
---
# Change - Dolphin root configuration layout and endpoint clarification

Date: 2026-09-17 15:36 +0900
Agent: codex
Status: completed

## Why

The config directory added indirection for the small runtime and p10k configuration set.

## How

Moved tracked templates and p10k source to repository root, migrated the local runtime file by rename without content inspection, updated scripts and ignore rules, and documented default OpenAI versus DSBA LiteLLM profile behavior.

## Files

- runtime.env.example
- p10k.zsh
- README.md
- build_image.sh
- make_container.sh
- sync_p10k_config.sh

## Validation

- bash -n build_image.sh make_container.sh sync_p10k_config.sh; git diff --check; inspected Dockerfile provider config.

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
?? history/changes/2026-09-17-153132-dolphin-attach-shell-and-shared-p10k-configuration.md
?? history/daily/2026-09-17.md
?? p10k.zsh
?? runtime.env.example
?? sync_p10k_config.sh
```
