# 닉네임 중복 안내와 비밀번호 재설정 메일

## 범위와 완료 조건

- Android 가입 화면에서 닉네임 중복 오류를 닉네임 입력칸 아래에 표시하고, 수정 시 오류를 지운다.
- 백엔드의 비밀번호 재설정 링크를 Gmail SMTP로 실제 발송한다. 발신 계정과 앱 비밀번호는 환경 변수로만 주입한다.
- 이메일의 재설정 링크가 Android 앱의 재설정 화면을 연다.
- 새 동작을 단위 테스트와 빌드로 검증한다. 실제 SMTP 발송은 설정된 계정으로 별도 확인한다.

## 영향 컴포넌트

- `components/frontend`: 가입 오류 UI, Android App Link 진입
- `components/backend`: SMTP 발송, 설정과 메일 템플릿
- `components/infra`: 기존 HTTPS App Link 호스트의 재설정 경로와 배포 환경 변수
- `docs/product-specs/system-overview.md`: 인수 조건

## 진행 상황

- [x] 현재 가입 및 비밀번호 재설정 흐름 확인
- [x] 구현
- [x] 단위 테스트, Android 빌드 및 PowerShell 문법 검증

## 결정

- 닉네임 중복 확인용 버튼/API 대신 가입 결과의 중복 오류를 해당 입력칸에 연결한다. 서버의 가입 시 중복 검사와 DB 고유 제약은 유지한다.
- 재설정 링크에는 기존 CloudFront HTTPS App Link 호스트를 사용한다. 임의의 앱 스킴보다 도메인 검증이 가능하다.
- 운영 환경에서 SMTP 설정이 없으면 조용히 성공 처리하지 않는다. 로컬의 로그 발송은 명시적으로 SMTP를 켜지 않았을 때만 사용한다.
- 실제 SMTP 비밀번호는 소스와 문서에 기록하지 않는다.

## 검증 결과 및 남은 작업

- 백엔드: `SmtpEmailSenderTest`, `PasswordResetServiceImplTest` 8개 통과.
- Android: `PasswordResetAppLinkTest` 통과, debug Kotlin/매니페스트 컴파일 통과.
- 인프라: `bootstrap.ps1`, `deploy.ps1` PowerShell 구문 검사 통과. Terraform CLI가 없어 HCL fmt/validate는 실행하지 못했다.
- `git diff --submodule=log`와 `git submodule status --recursive`로 컴포넌트 커밋을 검토했다.
- 실제 Gmail 발송과 단말 App Link 연결은 SMTP 환경 변수 주입 및 인프라 적용 후 확인해야 한다. 비밀값은 저장소에 기록하지 않았다.
- 컴포넌트 feature 브랜치의 develop 병합 후 orchestration submodule 포인터를 갱신한다.
