---
type: change
title: "Mac에 DSBA Portal MCP 연결과 runtime 예시 설명 추가"
date: "2026-10-05 13:58 +0900"
status: completed
tags: [history, change]
agent: codex
record_id: chg-2026-10-05-135853-mac-dsba-portal-mcp-runtime
---
# Change - Mac에 DSBA Portal MCP 연결과 runtime 예시 설명 추가

Date: 2026-10-05 13:58 +0900
Agent: codex
Status: completed
Record Id: chg-2026-10-05-135853-mac-dsba-portal-mcp-runtime

## Why

현재 Mac에서도 MCP를 사용하고 runtime.env의 각 설정과 키 형식을 쉽게 이해한다.

## How

Mac의 Codex config.toml과 Claude user scope에 동일한 MCP 실행기를 등록했다. 토큰은 사용자 홈의 권한 600 인증 파일에만 저장했고 설정에는 실행기 경로만 포함했다. runtime.env.example의 모든 항목에 한국어 주석을 추가하고 가짜 GitHub PAT, Hugging Face, W&B, LiteLLM, DSBA Portal 키 형식 예시를 주석으로 제공했다.

## Files

- runtime.env.example

## Validation

- 로컬 MCP 초기화와 도구 10개 탐색 통과. 실제 포탈 whoami 인증 통과 및 read scope 확인. 인증된 list_servers로 서버 6대 확인. Codex 실제 MCP 설정 파싱과 Claude 설정 등록 확인. 토큰 파일 권한 600 확인. bash 구문과 git diff --check 통과.

## Risks / Follow-Ups

현재 토큰은 read 권한이며 예약과 반납은 write 토큰이 필요하다. 실제 토큰 값은 저장소와 history에 기록하지 않았다.

## Git Status Snapshot

```text
M runtime.env.example
?? final/
```

## Commits

-
