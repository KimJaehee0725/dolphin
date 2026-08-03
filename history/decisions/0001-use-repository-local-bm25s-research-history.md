---
type: decision
title: "Use repository-local BM25S research history"
date: "2026-08-03 05:14 +0000"
status: accepted
tags: [history, decision]
---
# Decision 0001 - Use repository-local BM25S research history

Date: 2026-08-03 05:14 +0000
Status: accepted

## Context

Dolphin의 중앙 SSH/password memory client와 runtime mount가 단순 프로젝트 기록에 비해 운영 부담과 image 결합도를 높였다.

## Decision

각 mounted repo의 history/ Markdown을 원본으로 사용하고 vendored BM25S만 ranked recall에 사용한다. Obsidian은 각 history/를 직접 열고 PROJECT_MAP.md를 탐색한다.

## Rationale

서비스, credential, persistent database 없이 clone과 Git만으로 기록·검색·검토가 동작한다.

## Consequences

중앙 Research Memory wrapper, skill, runtime variables, key/password mounts를 제거한다. 기존 기록은 provenance로 보존하되 현재 context가 이를 supersede한다.
