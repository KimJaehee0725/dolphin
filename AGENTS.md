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

`config/runtime.env` is local-only. Never read, print, copy, or commit it.
