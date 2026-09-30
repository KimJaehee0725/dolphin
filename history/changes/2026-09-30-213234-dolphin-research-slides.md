---
type: change
title: "Dolphin 이미지에 research-slides 스킬 추가"
date: "2026-09-30 21:32 +0900"
status: completed
tags: [history, change]
agent: codex
record_id: chg-2026-09-30-213234-dolphin-research-slides
---
# Change - Dolphin 이미지에 research-slides 스킬 추가

Date: 2026-09-30 21:32 +0900
Agent: codex
Status: completed
Record Id: chg-2026-09-30-213234-dolphin-research-slides

## Why

Codex와 Claude에서 연구 발표 스킬과 PowerPoint 템플릿을 바로 사용한다.

## How

upstream commit 55dce44c56913e4a775237a63dc9e8466d5a377d을 고정했다. 전체 원본 트리를 .local/share/research-slides에 설치하고 두 CLI에 심링크했다. requirements.txt, LibreOffice Impress, fontconfig, NanumSquare 폰트를 추가했다. 템플릿의 macOS 폰트 이름을 Linux 폰트로 매핑하고 빌드 중 CLI와 폰트 검사를 수행한다.

## Files

- Dockerfile
- README.md
- history/CONTEXT.md

## Validation

- Dockerfile 설치 구문을 임시 홈 경로에 적용해 SHA fetch, Python 의존성, 두 CLI 심링크, 템플릿과 CLI import를 확인했다. 예제 11장 PPT 생성과 OMML 수식을 확인했고 로컬 LibreOffice로 11장을 렌더링했다. render_check 경고 0개와 contact.png 생성을 확인했다. Ubuntu jammy fonts-nanum-extra 파일 목록에서 NanumSquare 파일을 확인했다. fontconfig shell 구문과 XML, git diff --check 통과.

## Risks / Follow-Ups

로컬 Docker 데몬에 연결할 수 없어 전체 CUDA 이미지 빌드와 Linux 컨테이너 내 렌더링은 미실행이다. 로컬 렌더링은 macOS 환경 검증이다.

## Git Status Snapshot

```text
M Dockerfile
 M README.md
 M history/CONTEXT.md
?? final/
```

## Commits

-
