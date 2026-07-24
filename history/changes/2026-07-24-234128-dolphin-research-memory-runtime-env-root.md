---
type: change
title: "Dolphin research-memory runtime.env를 단일 root로 단순화"
date: "2026-07-24 23:41 +0900"
status: completed
tags: [history, change]
agent: codex
---
# Change - Dolphin research-memory runtime.env를 단일 root로 단순화

Date: 2026-07-24 23:41 +0900
Agent: codex
Status: completed

## Why

여러 RESEARCH_MEMORY 경로를 매번 유지하는 부담을 없애고, 프로젝트별 키와 기본 profile 경계를 더 명확하게 한다.

## How

RESEARCH_MEMORY_ROOT 하나로 고정 파일명 link bundle을 찾고, host에서 실제 source를 해석해 개별 읽기 전용 mount한다. 초기화 helper가 key를 복사하지 않고 link만 만들며, v2 marker가 구형 컨테이너 재생성을 요구한다.

## Files

- make_container.sh, scripts/research-memory-init, scripts/research-memory, config/runtime.env.example, config/README.md, README.md, skills/research-memory/, history/CONTEXT.md

## Validation

- bash -n build_image.sh make_container.sh scripts/research-memory scripts/research-memory-init; skill quick_validate; fake-profile initializer test; fake-Docker root symlink resolution and v2 existing-container mount validation; git diff --check

## Risks / Follow-Ups

현재 환경에서 Docker daemon이 실행되지 않아 실제 image build 및 engine mount는 검증하지 못했다. target host에서 rebuild와 AUTO_RECREATE=1이 필요하며 Docker socket이 있는 컨테이너는 신뢰할 수 있는 agent와 프로젝트 전용 key에만 사용한다.
