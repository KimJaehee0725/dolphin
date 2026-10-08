---
type: change
title: "Google Workspace 빌드 임시 파일 삭제 권한 수정"
date: "2026-10-08 15:26 +0000"
status: completed
tags: [history, change]
agent: codex
record_id: chg-2026-10-08-152604-google-workspace
commits: 478b26f8ac2b
---
# Change - Google Workspace 빌드 임시 파일 삭제 권한 수정

Date: 2026-10-08 15:26 +0000
Agent: codex
Status: completed
Record Id: chg-2026-10-08-152604-google-workspace
Commits: 478b26f8ac2b

## Why

workspace-mcp 설치와 --help는 성공했지만 root 소유로 COPY한 /tmp/dolphin-google-workspace-mcp.py를 일반 사용자가 삭제할 때 sticky /tmp의 소유권 제한으로 Operation not permitted가 발생하여 이미지 빌드가 중단됐다.

## How

Dockerfile의 wrapper COPY에 --chown=${UID}:${GID}를 지정한다. 계정 생성 전에도 numeric UID/GID로 소유권을 지정할 수 있으며 이후 일반 사용자 install 및 rm 단계가 정상 동작한다. 임시 파일 삭제를 숨기거나 패키지 버전을 변경하지 않는다.

## Files

- Dockerfile

## Validation

- python:3.12-slim 기반 최소 Docker 빌드에서 기존 COPY의 동일한 rm 오류와 exit 1을 재현했다. 수정 COPY는 UID/GID 1000:1000 및 사용자 지정 12345:23456 모두에서 install, rm, 실행 권한, 원본 임시 파일 제거 검증을 통과했다. git diff --check 통과. 실제 Dolphin 전체 이미지 재빌드는 수행하지 않았다.

## Risks / Follow-Ups

runtime.env는 읽거나 복사하지 않았다. 기존 runtime.env.example 삭제는 사용자 변경으로 보존한다. installed history.py가 --brief를 지원하지 않아 start --query --limit 5로 read-only recall을 수행했다.

## Commits

- `478b26f8ac2b` 2026-10-08 15:26 - Fix Google Workspace wrapper ownership during image build

