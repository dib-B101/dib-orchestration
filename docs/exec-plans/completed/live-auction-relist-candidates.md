# Execution Plan: 유찰 상품 라이브 경매 재편성

상태: Complete
소유자: Codex
시작일: 2026-09-23
완료일: 2026-09-23

## 목적

등록 직후 상품만 경매 후보에 보이고, 유찰되었거나 이전 Live 방송에 편성됐던 상품이 이후 후보 목록에서 사라지는 상태 조건 오류를 수정한다.

## 범위

- Backend의 Live 편성 가능 경매 조회 조건
- 유찰 경매를 새 Live에 편성할 때의 재등록 처리와 이전 방송 연결 해제
- Android Live 상품 편성 목록 조회 및 상태 안내
- 상태별 회귀 테스트

## 완료 조건

- 승인된 상품의 미시작 `SCHEDULED` 경매가 Live 편성 후보에 보인다.
- 입찰 없이 종료된 `ENDED` 경매가 이전 종료 Live 편성 이력과 무관하게 후보에 보이고 다시 편성된다.
- 낙찰·판매 완료, 진행 중, 취소, 검수 중·거절 상품은 신규 Live 후보에 보이지 않는다.
- 일반 경매 재시작 흐름은 유지된다.
- Backend 테스트와 Android 빌드가 통과한다.

## 영향받는 컴포넌트

- Backend
- Frontend Android

## 진행 상황

- [x] APK와 현재 코드의 API 주소·조회 조건 확인
- [x] 배포 DB 상태와 Redis 키를 읽기 전용으로 대조
- [x] 원인을 `GENERAL + SCHEDULED` 고정 조회 및 이전 `live_broadcast_id` 잔존으로 특정
- [x] Live 편성 후보 계약 및 유찰 재편성 구현
- [x] 상태별 자동 테스트 추가
- [x] Backend 테스트 및 Android 빌드 검증

## 결정 기록

| 날짜 | 결정 | 이유 |
| --- | --- | --- |
| 2026-09-23 | Redis 전체 삭제는 하지 않는다. | 후보 목록은 DB 조회이며 배포 Redis에 누락된 과거 경매 Snapshot도 없어 원인이 아니다. |
| 2026-09-23 | `LIVE_AVAILABLE` 조회 상태를 별도로 둔다. | 공개 경매의 `SCHEDULED`, `ENDED` 의미를 바꾸지 않고 판매자의 Live 편성 가능 규칙을 서버 한 곳에서 보장한다. |
| 2026-09-23 | 무입찰 `ENDED`만 재편성하면서 이전 종료 Live 연결을 교체한다. | 낙찰 상품 재판매와 진행 중 방송에서의 상품 탈취를 막으면서 유찰 상품 재사용을 허용한다. |

## 검증 결과

- Backend `LiveBroadcastCommandServiceImplTest`, `AuctionTimeRangeTest`: 성공
- Backend 전체 테스트: 243개 중 236개 성공. PostgreSQL 미기동 및 Docker/Testcontainers 사용 불가로 환경 의존 통합 테스트 7개 실패
- Android 전체 `testDebugUnitTest`: 성공
- Android `assembleDebug`: 성공
- Backend/Frontend `git diff --check`: 공백 오류 없음
- Backend main `12e4696`: 클린 `bootJar`와 관련 회귀 테스트 성공, 원격 main 푸시 완료
- Frontend main `a6dc2d6`: 클린 전체 단위 테스트와 `assembleDebug` 성공, 원격 main 푸시 완료

## 미해결 문제와 후속 작업

- 배포 전 PostgreSQL·Docker가 준비된 CI에서 Backend 전체 통합 테스트를 다시 실행한다.
- 이 작업에서는 사용자 승인 없는 배포와 DB/Redis 변경을 수행하지 않았다.
