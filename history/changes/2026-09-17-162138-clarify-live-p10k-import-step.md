---
type: change
title: "Clarify live p10k import step"
date: "2026-09-17 16:21 +0900"
status: complete
tags: [history, change]
agent: codex
---
# Change - Clarify live p10k import step

Date: 2026-09-17 16:21 +0900
Agent: codex
Status: complete

## Why

An imported prompt can be loaded in the current attached shell without detaching and attaching again.

## How

Changed the import completion message to tell the user to source ~/.p10k.zsh.

## Files

- sync_p10k_config.sh

## Validation

- bash syntax and whitespace checks passed; the script imported p10k.zsh into a running validation container and printed the new instruction.

## Risks / Follow-Ups

The instruction assumes it is run inside the attached zsh shell.

## Git Status Snapshot

```text
M sync_p10k_config.sh
?? final/
```
