---
name: research-memory
description: Safely recall, read, write, search, delete, and restore durable project Markdown through Dolphin's optional SSH research-memory profile. Use when an agent needs shared cross-host research context, must update project notes from a Dolphin container, or must resolve a note conflict. Do not use for server administration, SSH-key provisioning, direct server-file deletion, or Compose/systemd changes.
---

# Research Memory

Use the mounted research-memory client as the shared, project-scoped source of
truth. It is optional: absence of the runtime configuration is not a reason to
invent notes or alter the server.

## Start safely

1. Check that the client is available. Run `research-memory note list`.
2. If it reports that research memory is disabled or not mounted, continue with
   the repository's local context and state that shared-memory access was
   unavailable.
3. With the selected profile, omit the project argument. The profile fixes the
   project, SSH host, and access key.

The runtime variables and host mounts are prepared by Dolphin's
`make_container.sh`; see [the runtime reference](references/dolphin-runtime.md)
only when setup or diagnosis is needed. Never print the environment or the
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
