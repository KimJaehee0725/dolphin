# Project History

This folder stores durable project memory for research coding, experiments, ideas, decisions, and collaboration.

## Read First

1. `CONTEXT.md`
2. `INDEX.md`
3. Latest file in `daily/`
4. Relevant records from `changes/`, `decisions/`, `ideas/`, `experiments/`, `handoffs/`, `capsules/`, and `sessions/`

## Trusted Context

For collaboration projects, default agent context comes from `canonical/`, `tasks/`, `decisions/`, and scoped handoffs/capsules with explicit `Task:` and `Workstream:` metadata.

## Pending

`inbox/` contains submitted summaries awaiting maintainer review. It is excluded from collaboration recall unless `--include-inbox` is passed.

## Archive

`archive/` is tracked for provenance and long-term review, but excluded from collaboration recall unless `--include-archive` is passed. Archive cleanup moves files; it does not delete them.

## Language

Write summaries, rationale, validation notes, risks, and handoff context in the user's working language by default. Keep metadata keys, commands, paths, code identifiers, and quoted evidence unchanged.

## Maintenance

- Keep entries concrete: paths, commands, parameters, rationale, validation, and risks.
- Append corrections instead of rewriting past history.
- Do not store secrets or credentials.
