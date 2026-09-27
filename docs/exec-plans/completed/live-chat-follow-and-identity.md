# Execution Plan: Live 댓글 위치와 작성자 식별 일치

상태: 구현 완료, 실서버 계정 전환 검증 대기
소유자: 프런트엔드·백엔드
시작일: 2026-09-25

## 목적

새 Live 댓글을 즉시 볼 수 있게 하고, 댓글 수락 응답에 앱 프로필의 회원 ID를 임의로 붙이지 않도록 한다.

## 범위

### 포함

- Live 댓글 목록에서 새 댓글 도착 시 최신 위치로 이동
- WebSocket 댓글 수락 응답에 서버가 인증한 작성자 정보 제공
- 프런트엔드에서 서버의 작성자 정보로 댓글 표시 및 세션 불일치 감지
- 세션 불일치 시 기존 Live 연결을 통한 댓글·입찰 전송 차단
- 관련 계약 테스트와 컴포넌트 검증

### 제외

- 라이브 영상, 입찰 정책, 기존 댓글 저장소 구조 변경
- 재현 정보가 없는 운영 데이터의 특정 계정 수정

## 완료 조건

- 새 댓글이 도착하면 최신 댓글이 표시되고 과거 댓글 추가 조회는 현재 위치를 유지한다.
- 댓글 작성자 ID와 닉네임은 WebSocket 인증 주체에 따라 서버가 보낸 값을 사용한다.
- 앱 세션과 Live 연결의 작성자 ID가 다르면 오인 표시와 댓글·입찰 전송을 막고 연결을 다시 맺는다.
- 변경된 계약 테스트와 빌드가 통과한다.

## 영향받는 컴포넌트

- Frontend: Compose Live 댓글 목록, WebSocket 수락 응답 처리
- Backend: Live WebSocket 댓글 수락 응답
- Orchestration: 실행 결과 및 검증된 submodule 버전 기록

## 작업 단계

- [x] 현재 댓글·인증 흐름 확인
- [x] 구현
- [x] 자동 검증 및 코드 검토
- [x] 결과 기록 및 계획 완료 처리

## 진행 기록

- 2026-09-25: 프런트엔드 LazyColumn은 새 항목을 추가해도 위치 이동을 호출하지 않음을 확인했다.
- 2026-09-25: Backend는 STOMP CONNECT의 Bearer 토큰에서 Principal 회원 ID를 얻어 댓글을 저장하고 브로드캐스트한다. 프런트엔드의 CHAT_ACCEPTED 임시 메시지는 서버 응답에 작성자 정보가 없어 앱 프로필 ID를 붙인다.
- 사용자에게 계정 전환 재현 순서를 요청했으나 기억나지 않는다고 답했다. 특정 운영 사례는 아직 재현되지 않았다.
- 2026-09-25: Backend [PR #59](https://github.com/dib-B101/dib-backend/pull/59)를 `develop`에 병합했다. 결과 커밋은 `580668af4348a21baf752ee359e86946e011f6e6`이다.
- 2026-09-25: Frontend [PR #232](https://github.com/dib-B101/dib-frontend/pull/232)를 `develop`에 병합했다. 결과 커밋은 `3a89eca4985630055f5f962a8ab06cd3d47f92f0`이다.

## 결정 기록

| 날짜 | 결정 | 이유 |
| --- | --- | --- |
| 2026-09-25 | 댓글 수락 응답에 서버 작성자 정보를 추가한다. | 앱 프로필만으로 서버 저장 작성자를 단정할 수 없다. |
| 2026-09-25 | 이전 댓글 추가 조회에는 자동 이동하지 않는다. | 과거 내용을 읽는 위치를 보존한다. |

## 검증 결과

- Frontend: `:app:testDebugUnitTest :app:assembleDebug --offline` 통과, `:app:lintDebug` 통과.
- Backend: `test --tests com.b101.dib.websocket.controller.LiveWebsocketControllerTest` 통과. 인증 Principal의 회원 ID와 닉네임이 수락 응답·브로드캐스트에 동일하게 들어가는지 확인했다.
- Backend 전체 `test`는 로컬 PostgreSQL 연결 부재로 `DibApplicationTests.contextLoads`에서 실패했다. 연결 대기 중 실행을 중단했다.
- `git submodule status --recursive`와 `git diff --submodule=log`로 두 컴포넌트 커밋 범위를 확인했다.
- 실제 Live 방송에서 서로 다른 두 계정으로 댓글을 쓰는 기기 검증은 테스트 계정과 재현 순서가 없어 수행하지 못했다.

## 후속 작업

- 실제 계정 불일치 사례의 기기·서버 로그가 확보되면 추가 원인을 확인한다.
- 개발 서버에서 두 계정으로 순차 로그인하고 댓글을 보낸 뒤, 작성 직후·재진입 후 작성자 ID와 닉네임이 같은지 확인한다.
