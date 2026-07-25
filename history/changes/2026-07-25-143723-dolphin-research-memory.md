---
type: change
title: "Dolphin 에이전트의 Research Memory 동의 기반 설정 추가"
date: "2026-07-25 14:37 +0900"
status: completed
tags: [history, change]
agent: codex
---
# Change - Dolphin 에이전트의 Research Memory 동의 기반 설정 추가

Date: 2026-07-25 14:37 +0900
Agent: codex
Status: completed

## Why

새 컨테이너의 에이전트가 공용 메모리 사용 가능 여부를 먼저 확인하고, 미설정이면 사용자의 선택에 따라 안전하게 설정을 도울 수 있게 한다.

## How

AGENTS와 skill이 첫 substantive task에서 availability probe와 한국어 동의 질문을 요구한다. 동의 뒤 host-only enable helper가 key를 복사하지 않고 root link bundle 및 ignored overlay를 만들며, 재생성은 별도 확인 단계로 남긴다.

## Files

- AGENTS.md, skills/research-memory/, scripts/research-memory,
  scripts/research-memory-enable, scripts/research-memory-init,
  make_container.sh, config/research-memory.env.example, config/README.md,
  README.md, history/CONTEXT.md

## Validation

- bash -n make_container.sh and all research-memory scripts; skill quick_validate; fake-profile host enable helper initial/idempotent tests; fake-Docker overlay mount test; git diff --check

## Risks / Follow-Ups

Docker host와 컨테이너의 경계 때문에 컨테이너 안의 에이전트는 key 또는 overlay를 직접 설정하지 않는다. image build와 container recreate는 영향을 주므로 별도 사용자 확인이 필요하고, 현재 환경에서 live Docker daemon 검증은 수행하지 못했다.
