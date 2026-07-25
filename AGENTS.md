# Dolphin agent instructions

## Shared research memory

At the first substantive task in each Dolphin container session, use the
installed `research-memory` skill and run `research-memory note list` before
relying on shared context. If it is unavailable, ask the user whether to enable
Research Memory. On consent, use the host-side setup path in that skill; never
attempt key or runtime configuration inside the container.

When the availability check succeeds, consult the default project's relevant
notes before project work. Before completing a non-trivial task, record any
important decision, experiment result, or project change through the mounted
client, using the conflict-safe write procedure in the skill. Do not create
notes for trivial chat or routine checks.

`config/runtime.env` is local-only. Never read, print, copy, or commit it.
Use the mounted client rather than administering SSH keys, services, or server
storage directly.
