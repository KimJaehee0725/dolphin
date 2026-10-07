---
type: change
title: "Google Workspace env 인증과 다섯 API 연결로 변경"
date: "2026-10-07 16:33 +0900"
status: completed
tags: [history, change]
agent: codex
record_id: chg-2026-10-07-163329-google-workspace-env-api
---
# Change - Google Workspace env 인증과 다섯 API 연결로 변경

Date: 2026-10-07 16:33 +0900
Agent: codex
Status: completed
Record Id: chg-2026-10-07-163329-google-workspace-env-api

## Why

사용자 요청에 따라 resource alias를 제거하고 env의 OAuth client ID와 client secret으로 Slides, Calendar, Sheets, Gmail, Drive를 사용한다.

## How

workspace-mcp==2.0.1을 설치하고 Codex와 Claude에 single-user stdio MCP를 등록한다. 서비스 목록을 slides calendar sheets gmail drive로 고정한다. Google client 값은 env에서 container-local mode 600 파일로 stdin 전달하며 최초 브라우저 동의 helper가 저장소 밖에 refresh token과 account를 자동 저장한다. 수동 refresh token은 선택 사항이다. PKCE와 state 검증을 유지하고 wrapper가 토큰 갱신, account 자동 선택, upstream private credential store 생성을 수행한다. alias resolver, zsh alias hook, alias env 예시와 기존 Drive 전용 wrapper를 제거한다. 문서와 CONTEXT를 새 설정으로 갱신한다.

## Files

- .dockerignore
- AGENTS.md
- Dockerfile
- README.md
- make_container.sh
- runtime.env.example
- scripts/google_workspace_auth.py
- scripts/dolphin_google_workspace_mcp.py
- scripts/google_drive_auth.py
- scripts/dolphin_google_drive_mcp.py
- scripts/dolphin_gdrive_aliases.py
- history/CONTEXT.md

## Validation

- 격리된 Python 3.12 환경에서 실제 workspace-mcp 2.0.1의 stdio initialize와 list_tools 성공, 61개 도구 및 다섯 서비스 대표 도구 등록 확인. 다른 서비스 대표 도구 미등록과 account 자동 선택 확인. Upstream credential schema 로딩과 다섯 서비스 scope 충족 확인. 가짜 OAuth 값으로 최초 동의 필요, 수동 token 우선순위, mocked refresh, mode 600 파일 확인. 가짜 Docker로 launcher의 최초 인증 호출, stdin 인증값 전달, 불완전 client pair의 사전 거절, 빈 인증값과 이전 alias 파일 제거 확인. bash -n, Python ast.parse, Dockerfile의 zsh -n, git diff --check 통과. 실제 Google 계정 로그인과 API 요청 및 전체 Docker image build는 수행하지 않음.

## Risks / Follow-Ups

새 Calendar와 Gmail scope를 승인하려면 최초 브라우저 동의를 다시 수행해야 한다. Google OAuth Testing 상태에서는 refresh token이 7일 후 만료될 수 있다. Google client 값 두 개만으로 사용자 동의 없이 개인 데이터에 접근할 수는 없다.

## Commits

-
