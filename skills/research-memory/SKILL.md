---
name: research-memory
description: Safely recall, read, write, search, delete, and restore durable project Markdown through Dolphin's optional SSH research-memory root and its default project profile. Use when an agent needs shared cross-host research context, must update project notes from a Dolphin container, or must resolve a note conflict. Do not use for server administration, SSH-key provisioning, direct server-file deletion, or Compose/systemd changes.
---

# Research Memory

Use the mounted research-memory client as the shared, project-scoped source of
truth. It is optional: absence of the runtime configuration is not a reason to
invent notes or alter the server.

## First-task availability and consent

At the first substantive task in a Dolphin container session, run:

```bash
research-memory note list
```

If it succeeds, use the root's default profile and omit the project argument.
One root fixes one project, SSH host, and access key.

If it reports that shared memory is disabled or not mounted, ask the user in
the current conversation: “공용 Research Memory를 이 컨테이너에 사용할까요?”

- If the user declines, continue with local context and do not ask again in the
  same container session.
- If the user agrees, do not read, print, or edit keys or `runtime.env` from
  the container. Explain that setup is host-side. When operating on the Docker
  host, run `scripts/research-memory-enable`; otherwise give the user that
  command to run from the Dolphin checkout.
- The enable script creates only a local ignored overlay and symlinks. Before
  rebuilding or recreating a container, state that it will replace the current
  container and obtain confirmation for that separate step.

The runtime variables and host mounts are prepared by Dolphin's
`make_container.sh`; see [the runtime reference](references/dolphin-runtime.md)
only when setup or diagnosis is needed. Change the default profile only on the
Docker host, then recreate the container. Never print the environment or the
connection JSON while diagnosing it.

## Read and search

Prefer targeted queries before opening many notes:

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
research-memory note write notes/decision.md --file /tmp/decision.md --if-revision REVISION
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

- The selected profile is not permission to administer the server.
- Never copy, print, commit, or modify the mounted SSH key, `known_hosts`, or
  connection configuration.
- Keep host verification enabled; never add `StrictHostKeyChecking=no` or
  similar SSH options.
- Do not run `server/admin.py`, change `authorized_keys`, use `sudo`, access
  `/srv/research-memory`, or alter Docker Compose/systemd services.
- Request an operator only for server-side actions such as key grants/revokes,
  project-level administration, or service repair.
