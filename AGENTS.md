# Dolphin agent instructions

## Shared research memory

When a task needs durable project context shared across machines or containers,
read `skills/research-memory/SKILL.md` before using the service.

`config/runtime.env` is local-only. Never read, print, copy, or commit it.
Use the mounted client rather than administering SSH keys, services, or server
storage directly.
