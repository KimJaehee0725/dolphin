# Project Context

Last updated: 2026-08-14

## Research Goal

- CUDA 기반 연구·코딩 agent 컨테이너를 재현 가능하게 빌드하고, 각 mounted project가 자신의 Markdown history를 가볍게 유지하도록 한다.

## Current Architecture Or Structure

- Ubuntu 22.04/CUDA 12.2 image에 Python 3.12, NumPy, Codex, Claude, terminal 도구를 설치한다.
- Tree-sitter CLI는 glibc 2.35 호환 버전 `0.25.10`으로 pin한다.
- image build 시 검증된 `track-research-history` commit을 `~/.codex/skills/track-research-history`에 설치하고 `REVISION`에 기록한다.
- 각 프로젝트의 Git-tracked `history/*.md`가 유일한 durable memory이며, vendored BM25S가 현재 Markdown을 in-memory 검색한다.
- `history/PROJECT_MAP.md`의 상대 wikilink를 Obsidian viewer/backlink/graph 진입점으로 사용한다.
- `jaehee-dev`는 `sleep infinity`로 유지하고, login shell과 선택적 인증 env는 `docker exec` 세션에만 전달한다.

## Current Decisions

- SQLite, 중앙 memory server, password mode, SSH RPC, key mount, 별도 data vault를 사용하지 않는다.
- `make_container.sh`는 일반 volume/auth/runtime 설정만 전달하고 research history용 runtime 설정을 요구하지 않는다.
- Dockerfile/build context와 recreate/no-cache 동작은 env 항목이 아니라 helper script와 명시적 CLI flag로 관리한다.
- agent는 작업 시작 시 `start --query`, 비사소한 변경 후 record와 `finish`를 사용한다.

## Active Ideas

- `track-research-history`가 새 release/tag를 발행하면 검증 후 `TRACK_RESEARCH_HISTORY_REF`를 함께 갱신한다.

## Open Questions And Risks

- image build는 GitHub와 여러 upstream installer에 접근해야 한다.
- BM25S recall은 NumPy를 필요로 하며 의도적인 SQLite fallback은 없다.
- Docker socket mount는 host daemon 권한을 제공하므로 기본값은 off이며 신뢰된 작업에서만 명시적으로 켠다.

## Next Steps

- 원격 skill revision을 바꿀 때 full image build와 `start`, `finish`, BM25S smoke test를 반복한다.
