---
type: change
title: "단순화된 research history에 맞춰 Dolphin Docker 구성 정리"
date: "2026-08-14 05:22 +0000"
status: completed
tags: [history, change]
agent: codex
---
# Change - 단순화된 research history에 맞춰 Dolphin Docker 구성 정리

Date: 2026-08-14 05:22 +0000
Agent: codex
Status: completed

## Why

원격 스킬은 repository-local Markdown/BM25S만 필요하지만 Docker helper에는 중복 build/runtime 옵션과 인증 파일 영속화가 남아 있었고 host에는 구형 research-memory UI 및 이전 Dolphin 리소스가 남아 있었다.

## How

스킬을 검증된 c90f27c commit으로 pin하고 REVISION을 기록했다. build/run 옵션을 명시적 CLI flag로 줄였고 컨테이너를 sleep infinity와 docker exec session 구조로 바꿔 optional token을 container config나 파일에 저장하지 않게 했다. env example은 machine-specific 값만 남겼으며 구형 UI와 이전 Dolphin Docker 리소스를 제거했다.

## Files

- Dockerfile, build_image.sh, make_container.sh, config/runtime.env.example, config/README.md, README.md, history/CONTEXT.md

## Validation

- bash -n; git diff --check; docker buildx --check; full jaehee-base:0803 build; jaehee-dev recreate; skill REVISION/start smoke; Python 3.12.13 + NumPy 2.5.2; tree-sitter 0.25.10; secret env keys absent from container config; obsolete Docker resources absent

## Risks / Follow-Ups

로컬 runtime.env에서 Docker socket을 명시적으로 켜면 실제 container에는 계속 mount된다. example 기본값은 off이며 runtime.env 자체는 열거나 기록하지 않았다.

## Git Status Snapshot

```text
M Dockerfile
 M README.md
 M build_image.sh
 M config/README.md
 M config/runtime.env.example
 M history/CONTEXT.md
 M history/INDEX.md
 M make_container.sh
?? history/daily/2026-08-14.md
```
