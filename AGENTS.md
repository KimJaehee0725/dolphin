# Dolphin agent instructions

## Repository-local research history

At the first substantive task in each Dolphin container session, use the installed
`track-research-history` skill. Run its read-only `start --query "<task terms>"`
command before project work. If the repository has no `history/` directory, run
`bootstrap` first.

All durable memory belongs to the current repository's Git-tracked `history/*.md`
files. Ranked recall must use the skill's vendored BM25S backend only; do not add
SQLite, a central memory service, password mode, SSH RPC, or a separate data vault.

Before completing a non-trivial task, record important decisions, experiments, or
project changes with the narrowest matching command, then run `finish`. Do not
create records for trivial chat or routine read-only checks. Never store secrets,
credentials, raw private data, or hidden chain-of-thought in history.

For human browsing, open the repository's `history/` directory as an Obsidian vault
and start at `PROJECT_MAP.md`. Rebuild portable wikilinks with `obsidian-map` or
`index`; keep `.obsidian/` untracked.

`runtime.env` is local-only. Never read, print, copy, or commit it.

<!-- track-research-history:begin -->
## Research history

This repository keeps its research and code history in `history/`, managed by the track-research-history skill
(`scripts/history.py` inside the skill). Git is the source of truth.

- Before substantial work, run `history.py start --brief --query "<task terms>"` and read the hits that matter.
- Record meaningful changes, decisions, ideas, and experiments with the skill's record commands, written in the
  user's working language.
- Agents are authorized to commit recorded work automatically, without asking first, through
  `history.py commit --record <id> --path <file>`. Stage only the files the work touched. Do not push, force-push,
  or amend unless the user asks.
- Before the final response, run `history.py finish` and resolve what it reports.
- Project facts and decisions belong in `history/`, not in an agent's private memory. Subagents report back to the
  main agent; only the main agent writes records and commits.
<!-- track-research-history:end -->

## Google Drive aliases

`runtime.env` may define `GDRIVE_ALIAS_<NAME>` values that contain complete
Google Drive file or folder links. Resolve an alias with
`dolphin-gdrive resolve <NAME>` before calling the Google Drive MCP tools. The
command returns the Drive ID and item type without showing the original link.
Use folder IDs for listing and upload destinations. For a folder download,
recursively list its files and download the requested items. Use file IDs for
downloads and edits. Use the matching Docs, Sheets, or Slides tools for
Google-native documents. Do not use Calendar tools. Do not trash or share Drive
items unless the user asks. Aliases are references, not access restrictions.
Do not access other Drive items unless the user asks.
