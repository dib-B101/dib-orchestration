# Harness Document Status

상태: Draft
기준일: 2026-09-07

## 원본과 적용 원칙

- 상세 요구사항·기능·REST·WebSocket·Kafka·오류 코드·Redis 정책의 원본은 [B101 명세서 Google Sheet](https://docs.google.com/spreadsheets/d/1qjqjh2OFjFtgLKkJVJVqcNBo5vOF85LSEs8z4MNtQAg/edit)다.
- 이 저장소의 문서는 에이전트와 개발자가 구현·검증할 때 필요한 안정된 제품 규칙, 컴포넌트 경계, 계약 요약과 인수 조건을 제공한다.
- Sheet와 저장소 문서가 충돌하면 구현을 진행하지 않고 Sheet의 최신 결정과 변경 이력을 확인한다.
- 사용자가 제공한 `dib.sql`은 완성 전 ERD의 참고 자료다. 최종 물리 스키마나 실행 가능한 마이그레이션으로 간주하지 않는다.

## 현재 정보로 갱신 가능한 문서

| 문서 | 상태 | 현재 작성 가능한 내용 |
| --- | --- | --- |
| [`product-specs/system-overview.md`](product-specs/system-overview.md) | Draft | 제품 목표, 사용자, 일반·Live 경매 흐름과 범위 |
| [`product-specs/auction-platform.md`](product-specs/auction-platform.md) | Draft | 두 경매 유형, 공통 정책, 권한과 인수 조건 |
| [`../ARCHITECTURE.md`](../ARCHITECTURE.md) | Draft | 컴포넌트·도메인 경계와 동기·비동기 통합 흐름 |
| [`design-docs/auction-platform.md`](design-docs/auction-platform.md) | Draft | 공통 Auction 모델, 상태 전이, 일관성·장애 정책과 ERD 갭 |
| [`contracts/auction-platform.md`](contracts/auction-platform.md) | Draft | REST·WebSocket·Kafka·Redis·오류 계약의 구현용 요약 |
| [`TEST_STRATEGY.md`](TEST_STRATEGY.md) | Draft | 핵심 통합 시나리오와 합격 조건 |
| [`DEMO_RUNBOOK.md`](DEMO_RUNBOOK.md) | Draft | 일반 경매와 Live 경매의 시연 흐름·대체 시나리오 |
| [`DEPLOYMENT.md`](DEPLOYMENT.md) | Draft | 필요한 런타임 의존성, 배포 경계와 smoke test |

## 추가 정보가 있어야 완료 가능한 문서와 항목

| 항목 | 필요한 정보 | 소유 후보 | 현재 처리 |
| --- | --- | --- | --- |
| 일반 경매 추천·인기 정책 | 점수 입력 신호, 가중치, 개인화 여부, 갱신 주기 | Product, AI | `TBD` 정책값으로 격리 |
| 스트리밍 통합 | 공급자, 송출·재생 프로토콜, 토큰 수명, webhook 서명 | Backend, Infrastructure | 공급자 중립 경계만 기록 |
| 최종 ERD·마이그레이션 | DB 엔진, 타입, 제약, 인덱스, Live 편성 모델 | Backend | 논리 모델과 SQL 갭만 기록 |
| 성공 지표 | 전환율, 시청 유지율, 경매 완료율 등 목표값 | Product | 지표 이름도 결정 전 `TBD` |
| 컴포넌트 테스트 명령 | 실제 빌드·단위·통합 테스트 명령 | 각 submodule | 책임과 합격 조건만 기록 |
| 최종 배포 절차 | 환경, 주소, 이미지 태그, 비밀값 이름, 스트림 설정 | Infrastructure | infra 문서를 원본으로 연결 |
| 시연 운영값 | 시연 시간, 진행자, 계정, 상품·방송 fixture | Demo owner | 필요한 fixture와 순서만 기록 |

## 갱신 조건

- 위 미정 항목이 확정되면 관련 제품·설계·계약 문서를 같은 변경에서 갱신한다.
- API나 이벤트 호환성이 바뀌면 Google Sheet를 먼저 갱신하고 계약 요약과 테스트 시나리오를 동기화한다.
- 물리 ERD가 확정되면 설계 문서의 SQL 갭 표를 실제 마이그레이션 링크와 검증 결과로 대체한다.
