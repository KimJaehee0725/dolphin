# Dolphin agent instructions

## Shared research memory

At the first substantive task in each Dolphin container session, read
`skills/research-memory/SKILL.md` and run `research-memory note list` before
relying on shared context. If it is unavailable, ask the user whether to enable
Research Memory. On consent, use the host-side setup path in that skill; never
attempt key or runtime configuration inside the container.

`config/runtime.env` is local-only. Never read, print, copy, or commit it.
Use the mounted client rather than administering SSH keys, services, or server
storage directly.
