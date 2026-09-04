---
type: change
title: "Dolphin 이미지에 DSBA LiteLLM Codex 프로필 추가"
date: "2026-09-04 08:49 +0000"
status: completed
tags: [history, change]
agent: codex
---
# Change - Dolphin 이미지에 DSBA LiteLLM Codex 프로필 추가

Date: 2026-09-04 08:49 +0000
Agent: codex
Status: completed

## Why

컨테이너에서 기존 OpenAI 기본 provider를 유지하면서 DSBA LiteLLM을 전용 Codex profile로 선택하고, 발급 키를 매 zsh 세션에서 사용할 수 있어야 한다.

## How

Dockerfile이 공통 dsba_litellm provider와 dsba profile을 생성하고 .zshrc가 private key file을 환경 변수로 export하도록 했다. make_container.sh는 local-only runtime.env의 DSBA_LITELLM_API_KEY를 mode 600 container-local file로 전달한다. runtime.env.example과 문서에도 빈 키 항목과 사용법을 추가했다.

## Files

- Dockerfile
- make_container.sh
- config/runtime.env.example
- config/README.md
- README.md

## Validation

- bash -n make_container.sh; bash -n build_image.sh; git diff --check

## Risks / Follow-Ups

실제 endpoint/API key 테스트와 full Docker image build는 요청에 따라 수행하지 않았다. 키는 image/Git에는 포함되지 않지만 실행 중인 container의 사용자 홈에 mode 600으로 지속된다.

## Git Status Snapshot

```text
M Dockerfile
 M README.md
 M config/README.md
 M config/runtime.env.example
 M history/CONTEXT.md
 M make_container.sh
?? config/.runtime.env.swp
?? docs/
?? scripts/
```
