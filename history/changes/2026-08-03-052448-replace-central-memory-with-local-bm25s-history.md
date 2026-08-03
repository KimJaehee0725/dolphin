---
type: change
title: "Replace central memory with local BM25S history"
date: "2026-08-03 05:24 +0000"
status: completed
tags: [history, change]
agent: codex
---
# Change - Replace central memory with local BM25S history

Date: 2026-08-03 05:24 +0000
Agent: codex
Status: completed

## Why

Dolphin의 중앙 SSH/password Research Memory는 프로젝트별 Markdown 기록 요구보다 무겁고 runtime secret/mount 결합을 만들었다.

## How

중앙 wrapper, skill, overlay, client clone과 make_container mount logic을 제거했다. image가 track-research-history main의 vendored BM25S skill을 설치하고 각 repo의 history/와 Obsidian PROJECT_MAP.md를 사용하도록 AGENTS와 문서를 바꿨다. Python venv/bin을 PATH 최우선으로 두어 NumPy import도 보장했다.

## Files

- Dockerfile
- AGENTS.md
- make_container.sh
- README.md
- config/README.md
- config/runtime.env.example
- history/CONTEXT.md

## Validation

- docker build --build-arg USERNAME=jaeheekim --build-arg UID=1000 --build-arg GID=1000 -t jaehee-base:0803 . (passed)
- image smoke: Python 3.12 venv, NumPy 2.5.1, BM25S ranked search, PROJECT_MAP wikilink, strict lint (passed)
- image smoke: tree-sitter 0.25.10 on glibc 2.35; sqlite3 and central research-memory paths absent
- bash -n build_image.sh make_container.sh; repo history lint --strict

## Risks / Follow-Ups

TRACK_RESEARCH_HISTORY_REF defaults to main; use the build arg to select a stable branch/tag when one is published.
