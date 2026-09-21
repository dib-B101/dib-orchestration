# Kakao OAuth Android 통합

## 범위와 완료 조건

- 현재 백엔드의 `authorizationCode + redirectUri + deviceId` 계약을 유지한다.
- Android 앱에서 Kakao REST OAuth 인증을 시작하고 HTTPS App Link callback을 처리한다.
- OAuth `state`를 로컬에 일회성·만료 방식으로 검증한다.
- 기존 Kakao 회원은 DIB 세션을 저장하고 홈으로 이동한다.
- 신규 Kakao 회원은 휴대전화 인증과 추가정보 입력 후 가입 및 로그인한다.
- Kakao 키와 Redirect URI는 빌드 설정으로 주입하고 저장소에 비밀값을 남기지 않는다.
- 백엔드는 허용된 Redirect URI만 Kakao 토큰 교환에 사용한다.
- 관련 단위 테스트와 가능한 빌드 검증을 통과한다.

## 영향 컴포넌트

- Frontend: OAuth 브라우저 진입, App Link, API 계약, 신규 회원 화면, 세션 저장
- Backend: Redirect URI allowlist 검증과 설정
- Orchestration: 실행 계획 및 검증 결과

## 진행 상황

- [x] 기존 프론트엔드·백엔드 흐름과 테스트 확인
- [x] Android OAuth 및 가입 흐름 구현
- [x] 백엔드 Redirect URI 검증 구현
- [x] 테스트와 문서 갱신
- [ ] 실제 Kakao 설정을 사용한 Android 통합 검증

## 결정 기록

- Kakao Android SDK가 토큰을 앱에서 발급하는 구조로 계약을 변경하지 않고, Kakao REST OAuth authorization code를 Android가 수신해 현재 백엔드로 전달한다.
- Redirect URI는 HTTPS App Link로 한정하고 Gradle 속성으로 주입한다.
- 앱은 Kakao access token을 저장하지 않으며 DIB access/refresh token만 기존 암호화 저장소에 보관한다.
- OAuth `state`는 앱 전용 SharedPreferences에서 10분 TTL로 한 번만 소비한다.

## 검증 결과

- 작업 전 백엔드 Kakao 관련 테스트 38개 통과.
- 변경 후 백엔드 Kakao 관련 테스트 39개 통과(실행 39, 실패 0).
- Backend `develop` 병합 커밋 `8ca19e2`, Frontend `develop` 병합 커밋 `049b3c9`로 반영했다.
- PR: `dib-backend#54`, `dib-frontend#223` (squash merge 및 작업 브랜치 삭제 완료).
- 프론트엔드 Gradle 스크립트 구성 단계는 통과했다. 계약·가입 테스트와 lint/assemble은 로컬 Android SDK가 없어 task 의존성 결정 단계에서 중단됐다.
- Frontend와 Backend 모두 `git diff --check` 오류 없음(CRLF 변환 경고만 존재).

## 미해결 문제

- 실제 Kakao REST API 키와 등록된 HTTPS Redirect URI가 제공되어야 실계정 E2E 검증이 가능하다.
- Redirect URI 호스트에 `/.well-known/assetlinks.json`을 배포해야 Android App Link가 검증된다.
