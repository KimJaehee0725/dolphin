---
name: research-memory
description: Safely recall, select, read, write, search, delete, and restore durable project Markdown through Dolphin's optional personal password connection or legacy SSH research-memory root. Use when an agent needs shared cross-host research context, must select a project memory from a Dolphin container, must update project notes, or must resolve a note conflict. Do not use for server administration, credential provisioning, direct server-file deletion, or Compose/systemd changes.
---

# Research Memory

Use the installed research-memory client as the shared source of truth. It is
optional: absence of the runtime configuration is not a reason to invent notes
or alter the server.

## First-task availability and consent

At the first substantive task in a Dolphin container session, select the
workflow from `RESEARCH_MEMORY_MODE` without printing the environment.

For the default key mode, run:

```bash
research-memory note list
```

If it succeeds, use the root's default profile and omit the project argument.
One root fixes one project, SSH host, and access key.

For personal password mode, do not assume a project. Run:

```bash
research-memory project list
```

- If `RESEARCH_MEMORY_PROJECT` was supplied, run `research-memory note list`
  and use that project without an extra question.
- Otherwise, show the available project IDs and ask the user once: “어느
  Research Memory 프로젝트를 사용할까요?” Keep the selected ID in the current
  session and pass it explicitly, for example `research-memory note list
  fab-gym`.

Before beginning project-related work, retrieve the existing relevant notes:

```bash
research-memory note list PROJECT
research-memory note search PROJECT "project-specific terms"
```

At the end of a non-trivial task, record an important decision, experiment
result, or project change that a later agent needs to know. Skip routine
checks and trivial chat. Use the conflict-safe write procedure below; never
overwrite a note blindly.

If it reports that shared memory is disabled or unavailable, ask the user in
the current conversation: “공용 Research Memory를 이 컨테이너에 사용할까요?”

- If the user declines, continue with local context and do not ask again in the
  same container session.
- If the user agrees, do not read, print, or edit passwords, keys, or
  `runtime.env` from the container. Explain that setup is host-side: add
  `RESEARCH_MEMORY_HOST`, `RESEARCH_MEMORY_USER`, and
  `RESEARCH_MEMORY_PASSWORD` to the ignored host `config/runtime.env`.
  `RESEARCH_MEMORY_PROJECT` is optional. The legacy key mode instead uses
  `scripts/research-memory-enable`.
- Before rebuilding or recreating a container, state that it will replace the
  current container and obtain confirmation for that separate step.

The runtime variables and host mounts are prepared by Dolphin's
`make_container.sh`; see [the runtime reference](references/dolphin-runtime.md)
only when setup or diagnosis is needed. Change the default profile only on the
Docker host, then recreate the container. Never print the environment or the
connection JSON while diagnosing it.

## Read and search

Prefer targeted queries before opening many notes. In password mode prepend the
selected project ID unless `RESEARCH_MEMORY_PROJECT` is set:

```bash
research-memory note list
research-memory note search "retrieval query"
research-memory note read notes/decision.md
```

Treat search results as leads, then read the full note before relying on it.
The Markdown vault is shared state, so local repository files are not a
substitute for a successful read.

## Write without overwriting someone else's work

1. Read the current note first and retain its returned revision.
2. Draft the complete updated Markdown in a temporary file.
3. Write with that revision as a precondition:

```bash
research-memory note write PROJECT notes/decision.md --file /tmp/decision.md --if-revision REVISION
```

For a new note, use a clear, project-relative `.md` path and omit
`--if-revision`. Do not put Markdown contents on a command line.

If the server reports a revision conflict, read the note again, merge the
intentional changes, and retry with the latest revision. Do not force an
overwrite.

## Deletion and recovery

Only delete an exact note that is known to be obsolete:

```bash
research-memory note delete notes/obsolete.md --if-revision REVISION
research-memory note trash
research-memory note restore TRASH_ID
```

Never delete a project, a vault directory, or server files from this skill.
Use trash/restore rather than shell deletion so the change remains recoverable.

## Security boundary

- The selected project is not permission to administer the server.
- Never copy, print, commit, or modify passwords, SSH keys, `known_hosts`, or
  connection configuration.
- Password mode deliberately disables SSH host verification for this personal
  setup. Do not add broader shell, PTY, forwarding, or server-admin access.
- Do not run `server/admin.py`, change `authorized_keys`, use `sudo`, access
  `/srv/research-memory`, or alter Docker Compose/systemd services.
- Request an operator only for server-side actions such as key grants/revokes,
  project-level administration, or service repair.
