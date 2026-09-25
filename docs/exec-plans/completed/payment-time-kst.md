# 결제 일시 KST 보정

상태: 구현 및 자동 검증 완료, 배포 전
일자: 2026-09-25

## 범위와 완료 조건

- 새 결제의 `paidAt`을 실제 승인 순간의 KST 현지 시각으로 저장한다. 구매자 거래 상세 및 같은 값을 쓰는 결제 조회에 적용한다.
- 서버 JVM 기본 시간대가 UTC여도 9시간 차이가 나지 않는다.
- 사용자의 선택에 따라 기존 결제 기록은 변경하지 않는다.

## 조사와 결정

- 기존 저장 경로 `Payment.approved`가 `LocalDateTime.now()`를 사용했다. Dockerfile과 Kubernetes Deployment에는 JVM 시간대 지정이 없어 실행 환경에 따라 결제 일시가 달라질 수 있다.
- Android의 `formatServerTime`은 시간대 정보가 없는 `LocalDateTime` 응답을 현지 벽시계로 표시한다. 그래서 서버가 UTC 벽시계를 저장하면 KST 화면에서 9시간 빠진다.
- Toss 승인 응답의 `approvedAt` 오프셋을 KST로 변환해 저장한다. 값이 없으면 KST 현재 시각을 사용한다. 서버 전체 시간대를 변경하면 주문 마감과 기존 타임스탬프에 영향을 줄 수 있으므로 결제 외 도메인은 이번 범위에서 변경하지 않는다.

## 변경 및 검증

- Backend [PR #60](https://github.com/dib-B101/dib-backend/pull/60) `develop` 병합 커밋: `3e0a428902d065e04ed523ecde4498df76eb7295`.
- UTC JVM 설정에서 `PaymentTest`를 재실행했다. UTC와 `+09:00` 승인 시각의 KST 변환 및 승인 시각 누락 시 KST 현재 시각 검증이 통과했다.
- `git submodule status --recursive`와 `git diff --submodule=log`로 backend 포인터 변경 범위를 확인했다.
- 실제 결제사 승인 및 배포 환경의 JVM·DB 세션 시간대는 이번 로컬 검증에서 확인하지 않았다. 배포 승인은 별도로 필요하다.

## 후속 점검

- 주문 마감, 스케줄러와 다른 도메인의 `LocalDateTime.now()` 및 DB `CURRENT_TIMESTAMP` 사용처는 시간대 계약을 정한 뒤 별도 검증이 필요하다.
