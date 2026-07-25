---
type: change
title: "Dolphin 이미지에 전역 Research Memory 에이전트 지침 포함"
date: "2026-07-25 16:09 +0900"
status: completed
tags: [history, change]
agent: codex
---
# Change - Dolphin 이미지에 전역 Research Memory 에이전트 지침 포함

Date: 2026-07-25 16:09 +0900
Agent: codex
Status: completed

## Why

새 컨테이너에서도 작업 디렉터리와 무관하게 첫 substantive task의 Research Memory 확인 규칙이 자동으로 로드되어야 한다.

## How

Dockerfile이 repo AGENTS.md를 이미지의 ~/.codex/AGENTS.md로 복사하고, AGENTS는 설치된 research-memory skill을 사용하도록 지정한다.

## Files

- Dockerfile
- AGENTS.md
- README.md

## Validation

- bash -n make_container.sh build_image.sh scripts/research-memory scripts/research-memory-enable scripts/research-memory-init; skill quick_validate; git diff --check; Dockerfile COPY와 read-only mount 정적 확인

## Risks / Follow-Ups

현재 환경에서는 Docker daemon을 사용할 수 없어 새 이미지 build와 컨테이너의 live note list 검증은 대상 Docker host에서 수행해야 한다.

## Git Status Snapshot

```text
M AGENTS.md
 M Dockerfile
 M README.md
 M history/INDEX.md
 M history/daily/2026-07-25.md
 M skills/research-memory/SKILL.md
?? history/changes/2026-07-25-160832-research-memory.md
```
