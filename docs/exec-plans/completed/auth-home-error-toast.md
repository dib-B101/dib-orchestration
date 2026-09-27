# 시작·로그인·홈 오류 안내 Toast 전환

상태: 구현 및 자동 검증 완료
일자: 2026-09-25

## 범위와 완료 조건

- 시작 화면의 카카오 로그인 오류, 로그인 화면의 일반 로그인 오류, 홈 화면의 네트워크·목록 오류를 본문 공간을 차지하지 않는 하단 Toast로 표시한다.
- 이메일·비밀번호 형식 오류는 해당 입력란 아래에 유지한다.

## 조사와 결정

- 홈은 목록 오류를 배너로, 로그인과 시작 화면은 일반 오류를 본문 문구로 표시해 오류 발생 시 요소 위치가 바뀌었다.
- 기존 `DibSnackbarHost`를 재사용한다. 홈의 당겨서 새로고침은 유지한다.
- 카카오 로그인 설정 누락은 같은 버튼을 반복해 눌러도 매번 Toast를 보여주도록 공통 Toast 호스트에서 직접 알린다.

## 변경 및 검증

- Frontend [PR #234](https://github.com/dib-B101/dib-frontend/pull/234) `develop` 병합 커밋: `d6b61ce0119516f1faaaec6b3331b1835fe3a8be`.
- `:app:testDebugUnitTest :app:lintDebug :app:assembleDebug --offline` 통과.
- `git submodule status --recursive`와 `git diff --submodule=log`로 frontend 포인터 변경 범위를 확인했다.
- 연결된 에뮬레이터가 없어 실제 화면 수동 확인은 수행하지 않았다.
