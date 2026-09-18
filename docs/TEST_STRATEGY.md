# Test Strategy

단기 프로젝트의 개발 결과가 통합 환경에서 배포되고 시연될 수 있는지 검증하기 위한 기준을 관리한다.

## 테스트 수준

| 수준 | 책임 | 목적 | 실행 명령 |
| --- | --- | --- | --- |
| Frontend | `dib-frontend` | 주요 화면과 사용자 상호작용 검증 | `components/frontend/gradlew.bat assembleDebug testDebugUnitTest` |
| Backend | `dib-backend` | API와 비즈니스 규칙 검증 | `components/backend/gradlew.bat test` |
| AI | `dib-ai` | 추론 흐름과 결과 형식 검증 | `docker compose exec ai pytest -q` |
| Infrastructure | `dib-orchestration` | 배포 구성과 환경 유효성 검증 | `docker compose --profile app config --quiet` |
| Integration | `dib-orchestration` | 컴포넌트 간 핵심 흐름 검증 | `components/backend/gradlew.bat test --tests "com.b101.dib.scenario.TradeCycleIntegrationTest"` |

각 컴포넌트의 상세 테스트 구현과 명령은 해당 저장소가 관리한다. 이 문서에는 전체 테스트 범위와 통합 합격 조건을 기록한다.

## 통합 테스트

통합 테스트 시나리오와 기대 결과는 제품 명세 및 `docs/contracts/`의 계약을 기준으로 작성한다.

| 시나리오 | 관련 컴포넌트 | 기대 결과 | 상태 |
| --- | --- | --- | --- |
| 동일가·서로 다른 가격 동시입찰 | Backend, PostgreSQL | 동일가는 1명만 성공, 최종 최고가·입찰자 일치 | Automated |
| 마감 직전 입찰 | Backend | 남은 시간이 15초로 재설정되고 연장 횟수 증가 | Automated |
| 유찰·재등록 | Backend | 무입찰 종료 후 같은 경매를 초기화해 재시작 | Automated |
| 검수 거절·수정·승인 | Backend, AI 계약 | 상태가 `REJECTED → PENDING → REGISTERED`로 전이 | Automated |
| 낙찰자 결제 실패·차순위 낙찰 | Backend, Toss mock | 만료 후 차순위 알림·수락·주문·결제 생성 | Automated |
| 배송·구매확정·정산 | Backend, 배송 fake | 배송 완료 후 수동/자동 확정 및 정산 생성 | Automated |
| 거래 신고 보류·환불/재개 | Backend, Toss mock | 신고 중 출고 차단, 처리 뒤 환불 또는 거래 재개 | Automated |
| 문의 답변·알림·추가 문의 | Backend | 관리자 답변 알림과 후속 문의 생성 | Automated |
| 라이브 입찰·재연결 | Backend, WebSocket | Snapshot이 현재 경매·최고가를 복구하고 정상 종료 | Automated + device check |
| 상품 이미지 업로드 | Backend, Frontend | 실제 파일 저장·HTTP 조회·앱 상대 URL 해석 | Automated + runtime check |

## 배포 및 시연 진입 조건

- 각 컴포넌트의 필수 테스트가 통과한다.
- 핵심 통합 시나리오가 통과한다.
- 사용할 submodule 커밋이 확정되어 있다.
- 환경변수와 비밀값이 저장소 밖에서 준비되어 있다.
- 알려진 실패 항목과 시연 영향이 기록되어 있다.

## 결과 기록

테스트 실행 일시, 대상 커밋, 환경, 결과와 알려진 문제를 해당 실행 계획 또는 시연 기록에 남긴다.

### 2026-09-18 로컬 통합 환경

- Backend 전체 테스트: 성공
- Frontend debug APK 및 unit test: 성공
- AI: 281 passed, 11 skipped
- Compose backend/AI health: `UP` / `ok`
- 실제 multipart 상품 이미지 업로드 및 HTTP 이미지 조회: 성공
- 남은 수동 확인: LiveKit 영상 송출 중 네트워크 단절·재연결(입찰 STOMP 상태 복구는 확인 완료)
