---
type: change
title: "Google Drive OAuth MCP와 alias 연결 추가"
date: "2026-10-07 16:10 +0900"
status: completed
tags: [history, change]
agent: codex
record_id: chg-2026-10-07-161048-google-drive-oauth-mcp-alias
commits: 9a52fd981584
---
# Change - Google Drive OAuth MCP와 alias 연결 추가

Date: 2026-10-07 16:10 +0900
Agent: codex
Status: completed
Record Id: chg-2026-10-07-161048-google-drive-oauth-mcp-alias
Commits: 9a52fd981584

## Why

Codex와 Claude에서 env alias로 지정한 Drive 파일과 폴더를 인증된 상태로 다룰 수 있게 한다.

## How

Drive Docs Sheets Slides MCP를 `@piotr-agier/google-drive-mcp@2.12.0`으로 pin하고 Codex와 Claude에 등록했다. Desktop OAuth helper는 state 검증과 PKCE S256, localhost callback을 사용하며, `--no-browser --port` 옵션으로 SSH port forwarding 환경에서도 인증할 수 있다. OAuth client와 갱신 token은 저장소 밖의 `~/.config/dolphin-auth/google-drive.json`에 저장하고 directory 700, file 600 권한을 적용한다. Launcher는 이 파일을 컨테이너의 private auth directory에 mode 600으로 전달한다. MCP 실행기는 access token을 갱신하고 upstream server에 전달한다.

`runtime.env`의 `GDRIVE_ALIAS_<NAME>` 값으로 Drive file 또는 folder link를 전달한다. Resolver는 alias, Drive ID, item type만 출력하고 원본 link는 출력하지 않는다. Agent 안내는 alias를 먼저 해석하고 alias가 참조하는 항목으로 작업하도록 한다. OAuth `drive`, `documents`, `spreadsheets`, `presentations` scope는 해당 계정에서 접근 가능한 Drive 파일에 폭넓게 적용된다. Alias는 권한 제한이 아니며 Calendar scope는 요청하지 않는다. 사용자가 요청하지 않으면 다른 Drive 항목에 접근하거나 파일을 휴지통으로 보내거나 공유하지 않는다.

## Files

- .dockerignore
- AGENTS.md
- Dockerfile
- README.md
- make_container.sh
- runtime.env.example
- scripts/google_drive_auth.py
- scripts/dolphin_gdrive_aliases.py
- scripts/dolphin_google_drive_mcp.py
- history/CONTEXT.md

## Validation

- bash -n으로 launcher 구문 확인, Python ast.parse로 세 스크립트 구문 확인, Dockerfile에서 추출한 zshrc에 zsh -n 실행, git diff --check 통과. Docker image build, 실제 Google OAuth와 Drive API 호출은 수행하지 않음.

## Risks / Follow-Ups

Google Cloud OAuth Desktop client 설정과 계정 승인이 필요하다. `drive` scope는 계정에서 접근 가능한 Drive 파일 전체에 폭넓게 적용되므로 alias 자체가 보안 경계는 아니다. OAuth 동의 화면이 Testing 상태이면 refresh token이 7일 후 만료될 수 있다. Docker image build, 실제 Google OAuth, Drive API 요청은 아직 검증하지 않았다.

## Git Status Snapshot

```text
M .dockerignore
 M AGENTS.md
 M Dockerfile
 M README.md
 M history/CONTEXT.md
 M make_container.sh
 M runtime.env.example
?? final/
?? scripts/
```

## Commits

- `9a52fd981584` 2026-10-07 16:17 - Add Google Drive OAuth MCP aliases

