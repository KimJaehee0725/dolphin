---
type: change
title: "Dolphin 비밀번호 기반 전체 프로젝트 Research Memory 연결"
date: "2026-07-27 13:26 +0900"
status: completed
tags: [history, change]
agent: codex
---
# Change - Dolphin 비밀번호 기반 전체 프로젝트 Research Memory 연결

Date: 2026-07-27 13:26 +0900
Agent: codex
Status: completed

## Why

새 Dolphin 컨테이너가 ignored runtime.env의 서버 주소·계정·비밀번호만으로 Research Memory에 연결하고, project 값이 없으면 에이전트가 선택을 묻게 한다.

## How

Docker image에 sshpass와 public client clone을 추가하고, make_container가 password env를 전달하며, research-memory skill이 password mode의 project list/선택 절차를 따르게 했다. key-root mode는 legacy로 보존했다.

## Files

- Dockerfile
- make_container.sh
- scripts/research-memory
- skills/research-memory/SKILL.md
- config/runtime.env.example

## Validation

- bash -n make_container.sh build_image.sh scripts/research-memory scripts/research-memory-enable scripts/research-memory-init; skill quick_validate; password wrapper dry-run; git diff --check

## Risks / Follow-Ups

현재 환경에 Docker daemon이 없어 새 이미지 build와 실제 새 컨테이너 RPC smoke는 대상 Docker host에서 수행해야 한다. Password mode는 user request에 따라 host-key verification을 사용하지 않는다.

## Git Status Snapshot

```text
M AGENTS.md
 M Dockerfile
 M README.md
 M config/README.md
 M config/runtime.env.example
 M history/CONTEXT.md
 M make_container.sh
 M scripts/research-memory
 M skills/research-memory/SKILL.md
 M skills/research-memory/references/dolphin-runtime.md
```
