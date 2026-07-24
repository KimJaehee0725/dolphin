---
type: change
title: "Dolphin에 안전한 research-memory skill 및 런타임 연결 추가"
date: "2026-07-24 23:22 +0900"
status: completed
tags: [history, change]
agent: codex
---
# Change - Dolphin에 안전한 research-memory skill 및 런타임 연결 추가

Date: 2026-07-24 23:22 +0900
Agent: codex
Status: completed

## Why

Dolphin 컨테이너의 에이전트가 프로젝트별 중앙 Markdown 메모리를 안전하게 읽고 갱신할 수 있게 한다.

## How

컨테이너에 skill과 wrapper를 설치하고, local-only runtime.env의 프로필·클라이언트·키·known_hosts 경로를 읽기 전용으로 mount하도록 했다.

## Files

- AGENTS.md, skills/research-memory/, scripts/research-memory, Dockerfile, make_container.sh, config/runtime.env.example, config/README.md, README.md

## Validation

- skill quick_validate, bash -n build_image.sh make_container.sh scripts/research-memory, wrapper disabled-path test, git diff --check

## Risks / Follow-Ups

현재 환경에서는 Docker daemon이 없어 실제 image build와 mount 실행은 검증하지 못했다. Docker host에서 image rebuild 후 AUTO_RECREATE=1로 mount를 적용해야 하며, 비밀값은 저장소에 포함하지 않는다.
