# Execution Plan: AI 추천 실데이터 연동

상태: Complete
소유자: Backend / AI
시작일: 2026-09-17
완료일: 2026-09-18

## 목적

FastAPI 추천 엔진이 실제 PostgreSQL 경매 데이터를 점수화하고, Spring이 명세 94의 비동기 요청과 명세 95의 콜백으로 결과를 받아 `GET /api/v1/auctions/recommendation`의 일반 경매 순서에 반영한다.

## 범위

### 포함

- AI 추천 조회기를 실제 PostgreSQL 데이터로 실행
- 일반 경매 추천 요청의 비동기 Kafka 트리거
- HMAC이 적용된 추천 요청과 콜백
- Redis 추천 스냅샷 캐시와 장애 시 기존 마감 임박순 폴백
- AI가 돌려준 경매 ID 순서대로 기존 Spring 카드 DTO 조회
- 로컬 환경에서 AI → Spring → Android 홈까지 확인

### 제외

- 사용자 행동 기반 개인화 모델 학습
- 상품 임베딩이 필요한 유사 상품 추천의 Spring 비동기 계약 확장
- 라이브 방송 영상·WebSocket 기능 수정
- AI 상품 검수와 이상 입찰 탐지 추가 변경

## 완료 조건

- AI `/reco/health`가 `provider=postgres`를 반환한다.
- 실제 ACTIVE 일반 경매 ID가 AI 추천 순서로 반환된다.
- Spring이 Kafka Consumer에서만 AI 명세 94를 호출한다.
- 명세 95 콜백의 HMAC을 검증하고 Redis에 추천 스냅샷을 저장한다.
- 홈 추천 API가 AI 순서를 사용하며 AI/Redis 장애 시 기존 정렬로 정상 응답한다.
- AI 및 Backend 관련 테스트가 통과한다.

## 영향받는 컴포넌트

- `components/ai`: 비동기 추천 요청에 `scope`를 추가하고 실제 DB 조회를 검증
- `components/backend`: 추천 요청 이벤트, AI 콜백, Redis 캐시, 순서 보존 카드 조회
- `components/frontend`: 기존 응답 계약을 유지하므로 원칙적으로 코드 변경 없음
- `dib-orchestration`: 실행 계획과 통합 검증 결과 기록

## 작업 단계

- [x] 현재 상태와 제약 확인
- [x] AI 원격 브랜치의 실제 DB 추천 구현 동기화
- [x] AI 비동기 추천 계약에 일반 경매 범위 적용
- [x] Spring 추천 요청·콜백·캐시 구현
- [x] AI 추천 순서 기반 카드 조회 구현
- [x] 로컬 환경 설정 및 E2E 검증
- [x] 관련 테스트와 문서 갱신

## 진행 기록

- 2026-09-17: AI 브랜치를 원격 최신 커밋 `403b6aa`로 fast-forward했다.
- 2026-09-17: `PostgresProvider`, 실제 후보 SQL, DB 시각 UTC 변환, 임베딩 배치 구현을 확인했다.
- 2026-09-17: Spring 홈 추천은 아직 마감 임박순 폴백만 사용하고 추천 95 콜백은 미구현임을 확인했다.
- 2026-09-17: Kafka 추천 요청, HMAC 콜백, Redis 스냅샷, AI 순서 카드 조회와 마감 임박순 폴백을 구현했다.
- 2026-09-17: Java 25 기본 HTTP 클라이언트의 h2c 요청에서 Uvicorn이 빈 본문을 읽는 문제를 확인하고 AI 전용 클라이언트를 HTTP/1.1 전송기로 고정했다.
- 2026-09-18: 루트 Compose에 Backend와 AI를 포함하고 Android는 호스트 포트에 연결하는 구조로 확정했다.

## 결정 기록

| 날짜 | 결정 | 이유 |
| --- | --- | --- |
| 2026-09-17 | Spring은 동기 추천 API를 직접 호출하지 않고 명세 94→95 비동기 계약을 사용한다. | AI 장애가 홈 요청을 지연시키거나 실패시키지 않게 하고 Backend Harness를 준수한다. |
| 2026-09-17 | 추천 결과는 Redis 스냅샷으로 캐시하고 캐시 미스·장애 시 기존 마감 임박순으로 폴백한다. | 추천은 파생 데이터이며 원본 DB에 영구 저장할 필요가 없고 서비스 가용성이 우선이다. |
| 2026-09-17 | 첫 연결 범위는 일반 경매로 제한하고 라이브 방송 카드는 기존 조회를 유지한다. | 현재 홈의 `liveItems`는 방송 카드지만 AI 결과는 경매 ID라 계약이 다르며, 영상 기능도 별도 미완성 상태다. |
| 2026-09-17 | 현재는 비개인화 baseline이지만 회원별 키 구조를 유지한다. | 이후 행동 기반 개인화를 붙일 때 API와 캐시 구조를 다시 바꾸지 않기 위해서다. |

## 검증 결과

- AI 추천·내부 API 관련 테스트: `107 passed`.
- Backend 전체 테스트: `BUILD SUCCESSFUL`.
- Android `:app:testDebugUnitTest :app:assembleDebug`: `BUILD SUCCESSFUL` (연결된 기기가 없어 `adb reverse`만 생략됨).
- `docker compose --profile app config --quiet` 통과.
- Backend·AI 이미지 빌드 성공, PostgreSQL·Redis·Kafka·Backend·AI 모두 healthy 확인.
- AI `GET /reco/health`가 `provider=postgres`를 반환.
- AI 직접 추천 ID와 Spring 홈 일반 경매 ID 10개의 순서가 일치함을 확인.
- AI 컨테이너 중지와 Redis 추천 스냅샷 제거 후에도 홈 API가 마감 임박순 10개를 200으로 반환.
- AI 재기동 후 새 콜백을 받아 홈이 다시 AI 순서로 복구됨을 확인.

## 후속 작업

- 상품 임베딩 배치가 안정화되면 상품 상세의 유사 상품 API를 별도 비동기 계약으로 연결한다.
- `member_event` 기반 개인화 boost를 추가하고 인기순 baseline 대비 오프라인·온라인 지표를 비교한다.
