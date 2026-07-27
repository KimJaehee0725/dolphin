# Project Context

Last updated: 2026-07-24

## Research Goal

- Dolphin 컨테이너에서 프로젝트별 중앙 Markdown 메모리를 안전하게 사용한다.

## Current Architecture Or Structure

- 개인 password mode는 ignored `config/runtime.env`의 `RESEARCH_MEMORY_HOST`,
  `RESEARCH_MEMORY_USER`, `RESEARCH_MEMORY_PASSWORD`, 선택적
  `RESEARCH_MEMORY_PROJECT`만 사용한다.
- `make_container.sh`는 password mode에서 이미지 내 client와 `sshpass`를 쓰며,
  key-root bind mount 방식은 legacy 호환 모드로 유지한다.

## Current Decisions

- password mode는 개인 서버의 모든 project를 보며, project 값이 비어 있으면
  에이전트가 첫 substantive task에서 목록을 읽고 선택을 묻는다.
- password mode는 사용자의 요청에 따라 host-key 검증을 사용하지 않는다. key-root
  mode에서는 기존 개별 read-only mount와 host-key 검증을 유지한다.
- 에이전트는 각 컨테이너 세션의 첫 substantive task에서 접근을 확인하고,
  미설정이면 사용자 동의 후 Docker host의 ignored runtime config 설정을 안내한다.

## Active Ideas

-

## Open Questions And Risks

- 실제 Docker daemon이 이 개발 환경에서는 실행 중이 아니므로, image build와
  Docker engine의 실제 mount 실행은 대상 host에서 재확인해야 한다.

## Next Steps

- host에서 `scripts/research-memory-enable`로 overlay와 root를 만든 뒤 image
  rebuild 및 container recreate를 한다.
