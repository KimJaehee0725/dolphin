# Dolphin agent instructions

## Shared research memory

At the first substantive task in each Dolphin container session, use the
installed `research-memory` skill. In password mode, list projects and ask the
user which memory to use unless `RESEARCH_MEMORY_PROJECT` was supplied; in key
mode, run `research-memory note list` before relying on shared context. If it
is unavailable, ask the user whether to enable Research Memory. On consent,
give the Docker-host setup path in that skill; never print or edit passwords,
keys, or runtime configuration inside the container.

When the availability check succeeds, consult the default project's relevant
notes before project work. Before completing a non-trivial task, record any
important decision, experiment result, or project change through the mounted
client, using the conflict-safe write procedure in the skill. Do not create
notes for trivial chat or routine checks.

`config/runtime.env` is local-only. Never read, print, copy, or commit it.
Use the mounted client rather than administering SSH keys, services, or server
storage directly.
