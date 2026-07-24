# Project Context

Last updated: 2026-07-24

## Research Goal

- Dolphin 컨테이너에서 프로젝트별 중앙 Markdown 메모리를 안전하게 사용한다.

## Current Architecture Or Structure

- `config/runtime.env`의 `RESEARCH_MEMORY_ROOT` 한 값이 private host-side
  research-memory bundle을 가리킨다.
- `make_container.sh`는 bundle 내부의 client/config/key/known_hosts를 실제
  호스트 경로로 해석한 뒤 각각 읽기 전용 bind mount한다.

## Current Decisions

- 한 root는 `client.json`의 default profile과 하나의 프로젝트 전용 RPC key를
  사용한다. 여러 프로젝트 키는 root와 컨테이너를 분리한다.
- root 전체를 mount하거나 키를 이미지·저장소·runtime.env에 복사하지 않는다.

## Active Ideas

-

## Open Questions And Risks

- 실제 Docker daemon이 이 개발 환경에서는 실행 중이 아니므로, image build와
  Docker engine의 실제 mount 실행은 대상 host에서 재확인해야 한다.

## Next Steps

- host에서 `scripts/research-memory-init`으로 root를 만든 뒤 runtime.env에
  `RESEARCH_MEMORY_ROOT`를 설정하고 image rebuild 및 container recreate를 한다.
