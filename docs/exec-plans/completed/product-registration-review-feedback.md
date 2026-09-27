# 상품 등록 이후 검수 피드백 개선

## 범위와 완료 조건

- Android 상품 등록 성공 시 접수 완료 전용 화면 없이 등록 상품 관리로 이동하고 완료 안내를 표시한다.
- 등록 상품 카드에서 검수 상태, 다음 행동, 수정·삭제 동작을 읽기 쉽게 구분한다.
- AI 검수 결과가 확정되면 판매자 알림을 저장·푸시하고, Android 알림 목록과 등록 상품 목록에 반영한다.
- 기존 등록 실패, 검수 중, 승인, 거절 동작을 유지한다.

## 영향 컴포넌트

- `components/frontend`: 상품 등록 이동, 목록 카드, 알림 수신과 목록 재조회
- `components/backend`: AI 검수 결과 알림 생성

## 진행 상황

- [x] 기존 등록 결과 화면, 상품 목록, 알림 연결 구조 조사
- [x] 등록 성공 이동과 카드 레이아웃 변경
- [x] 검수 결과 알림과 실시간 목록 갱신
- [x] 프런트·백엔드 검증

## 결정 기록

- 알림 종류는 기존 `SYSTEM`을 사용하고 `productId`를 채운다. 새 DB enum 값 없이 기존 알림 경로에서 상품 목록을 열 수 있다.
- 목록은 상품 알림을 받으면 재조회하고, 접속 중 알림을 놓친 경우를 위해 검수 중 상품이 보이는 동안 주기적으로 재조회한다.

## 검증 결과와 후속 작업

- Android `:app:assembleDebug` 성공. 최신 APK를 에뮬레이터에 설치했다.
- 백엔드 `ProductModerationTxServiceImplTest`와 `TradeCycleIntegrationTest` 통과.
- `git diff --check` 오류 없음. `git submodule status --recursive` 확인.
- 사용자 승인 후 로컬 Docker 백엔드만 재빌드·재시작했다. `docker compose --profile app ps backend`에서 healthy, `/actuator/health`에서 `UP`을 확인했다.
- 최종 반영 전 Android `:app:assembleDebug --offline`, `:app:testDebugUnitTest --offline` 및 백엔드 `ProductModerationTxServiceImplTest`를 다시 실행해 통과했다.
- Frontend `develop` 병합 커밋 `ab16c13` ([PR #230](https://github.com/dib-B101/dib-frontend/pull/230)), Backend `develop` 병합 커밋 `6160ea2` ([PR #58](https://github.com/dib-B101/dib-backend/pull/58))를 통합 저장소 서브모듈 포인터에 반영했다.
