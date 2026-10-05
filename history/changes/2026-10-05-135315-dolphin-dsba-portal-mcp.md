---
type: change
title: "Dolphin에 DSBA Portal MCP 연결 추가"
date: "2026-10-05 13:53 +0900"
status: completed
tags: [history, change]
agent: codex
record_id: chg-2026-10-05-135315-dolphin-dsba-portal-mcp
commits: df3cd1c4714e
---
# Change - Dolphin에 DSBA Portal MCP 연결 추가

Date: 2026-10-05 13:53 +0900
Agent: codex
Status: completed
Record Id: chg-2026-10-05-135315-dolphin-dsba-portal-mcp
Commits: df3cd1c4714e

## Why

컨테이너의 Codex와 Claude에서 서버와 GPU 현황을 조회하고 사용 예약과 반납 툴을 이용한다.

## How

Dockerfile에 Codex MCP와 Claude user scope MCP를 등록했다. dolphin-dsba-portal-mcp 실행기는 토큰 파일 또는 전달된 환경변수를 읽고 uvx로 upstream commit eadbab403ca2e79a77bb0d45768ce20490e2f081을 실행한다. runtime.env.example과 make_container.sh에 DSBA_PORTAL_TOKEN을 추가하고 권한 600 파일 전달, 갱신, 빈 값 삭제와 zsh reload를 연결했다. README에 토큰 발급, 초기 적용, 토큰 변경과 REST 호출을 기록했다.

## Files

- Dockerfile
- make_container.sh
- runtime.env.example
- README.md
- history/CONTEXT.md

## Validation

- upstream 테스트 8개 통과. 격리된 Claude 설정에서 user scope MCP 등록 확인. 실제 Codex CLI로 env_vars 설정 파싱 확인. 가짜 Docker와 runtime fixture로 토큰 생성, 교체, 삭제 및 파일 600, 디렉터리 700 확인. 실제 zsh 인증 함수 reload와 unset 확인. 실제 고정 git revision을 uvx로 실행해 stdio 초기화와 도구 10개 탐색 통과. 로컬 REST fixture를 통해 토큰 헤더 전달과 list_servers 결과 확인. bash, sh, zsh 구문과 git diff --check 통과. API docs URL의 공개 응답 확인.

## Risks / Follow-Ups

실제 포탈 토큰으로 인증과 예약 동작을 검증하지 않았다. 전체 CUDA 이미지는 빌드하지 않았다. 현재 Docker daemon은 ARM64이며 buildx check 기능이 없다. 최초 uvx 실행은 GitHub 접근을 요구하며 private repository에는 별도 GitHub 인증이 필요하다.

## Git Status Snapshot

```text
M Dockerfile
 M README.md
 M history/.gitignore
 M history/CONTEXT.md
 M make_container.sh
 M runtime.env.example
?? final/
?? history/.gitattributes
```

## Commits

- `df3cd1c4714e` 2026-10-05 13:53 - Add DSBA Portal MCP with runtime token loading

