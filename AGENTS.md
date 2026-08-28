# Repository Guide

## Purpose

이 저장소는 DIB 시스템의 통합 지식, 실행 계획, 컴포넌트 버전을 관리한다.
시스템 전체의 원본 문서는 `docs/`에 둔다. 컴포넌트 내부 구현은 각 submodule이 소유한다.

## Start Here

- 시스템 경계와 의존성: `ARCHITECTURE.md`
- 제품 명세 목록: `docs/product-specs/index.md`
- 설계 문서 목록: `docs/design-docs/index.md`
- 작업 계획 규칙: `docs/PLANS.md`
- Git Flow 및 커밋 정책: `docs/GIT_FLOW.md`
- 테스트 전략: `docs/TEST_STRATEGY.md`
- 배포 절차: `docs/DEPLOYMENT.md`
- 시연 절차: `docs/DEMO_RUNBOOK.md`
- 진행 중인 계획: `docs/exec-plans/active/`

## Component Repositories

- Frontend: `components/frontend/`
- Backend: `components/backend/`
- AI: `components/ai/`
- Infrastructure: `components/infra/`

컴포넌트를 변경할 때는 해당 디렉터리의 `AGENTS.md`와 로컬 문서를 우선 확인한다.

## Documentation Ownership

- 제품 목표, 사용자 흐름, 시스템 계약과 통합 정책은 이 저장소에서 관리한다.
- 내부 코드 구조, 구현 세부사항과 컴포넌트 전용 운영법은 해당 submodule에서 관리한다.
- 같은 내용을 여러 저장소에 복제하지 말고 원본 문서에 상대 링크를 건다.
- 확정되지 않은 사실을 추측하지 말고 `TBD`와 필요한 결정 사항을 기록한다.

## Working Rules

- 여러 컴포넌트에 영향을 주는 복잡한 작업은 `docs/exec-plans/active/`에 실행 계획을 먼저 작성한다.
- 실행 계획에는 범위, 완료 조건, 진행 상황, 결정 기록과 검증 결과를 유지한다.
- 완료한 실행 계획은 내용을 보존한 채 `docs/exec-plans/completed/`로 이동한다.
- 아키텍처 변경 시 `ARCHITECTURE.md`와 관련 설계 문서 및 인덱스를 함께 갱신한다.
- 제품 동작 변경 시 관련 제품 명세와 인수 조건을 함께 갱신한다.
- 테스트, 배포 또는 시연 절차가 바뀌면 해당 실행 문서를 함께 갱신한다.
- submodule 포인터 변경 시 대상 저장소의 커밋과 검증 결과를 기록한다.
- 모든 DIB 저장소의 브랜치, 병합, 버전 태그와 커밋 메시지는 `docs/GIT_FLOW.md`를 따른다.

## Verification

- 모든 상대 링크가 유효한지 확인한다.
- `git submodule status --recursive`로 submodule 상태를 확인한다.
- `git diff --submodule=log`로 컴포넌트 버전 변경을 검토한다.
- 변경된 문서의 인덱스와 상태가 일치하는지 확인한다.
- 코드 또는 구성 변경은 해당 컴포넌트의 검증 명령을 따른다.

## Safety

- 비밀값과 실제 환경 변수 값은 커밋하지 않는다.
- 사용자 승인 없이 배포, 권한 변경, 데이터 삭제를 수행하지 않는다.
- 요청 범위를 벗어난 submodule 변경이나 버전 갱신을 하지 않는다.
