# Firebase 휴대전화 인증 전환

## 범위와 완료 조건

- Android의 회원가입, 이메일 찾기, 비밀번호 찾기, 민감정보 변경 휴대전화 인증을 Firebase Phone Auth로 전환한다.
- 백엔드는 Firebase ID 토큰의 서명, 프로젝트, 전화번호, 최근 인증 시각을 검증한 뒤 기존 목적별 일회용 인증 토큰을 발급한다.
- 기존 DIB 계정과 세션 JWT는 유지하며, 이메일·전화번호 일치 검증과 재사용 방지 규칙을 보존한다.
- Android와 백엔드 자동 테스트, 로컬 Firebase 테스트 번호 검증을 완료한다.
- 기존 미커밋 프로필 이미지·비밀번호 찾기·컨테이너 설정 및 QA 기록을 각각 소유 저장소에서 검증 후 커밋한다.

## 영향받는 컴포넌트

- `components/frontend`: Firebase SDK 설정, 휴대전화 인증 화면과 API 계약
- `components/backend`: Firebase 토큰 검증과 목적별 인증 토큰 교환
- `dib-orchestration`: 제품 명세, 통합 설정, submodule 포인터

## 진행 상황

- [x] 기존 자체 SMS/Redis 인증 흐름 및 Firebase 공식 절차 조사
- [x] Firebase 콘솔의 Android 앱, Phone 제공업체, 한국 SMS 정책, debug SHA 지문 확인 및 설정
- [x] 백엔드 토큰 검증과 일회용 토큰 교환 구현
- [x] Android 회원가입·이메일 찾기·비밀번호 찾기 흐름 및 민감정보 변경용 공통 인증 목적 전환
- [x] Firebase 테스트 번호 및 Android 에뮬레이터 검증
- [x] 기존 미커밋 변경 검증 및 컴포넌트 커밋
- [x] 컴포넌트 병합 후 통합 저장소 submodule 포인터 갱신
- [x] EKS 배포: `dib-firebase-admin` Secret 읽기 전용 마운트와 백엔드 `a2dde56` 배포 검증
- [ ] 실기기에서 실제 번호 SMS 수신과 SMS 문구 언어 확인

## 결정 기록

- Firebase는 휴대전화 소유 확인에 사용하고 DIB의 회원·JWT는 그대로 사용한다.
- Google 발급 ID 토큰은 클라이언트 결과만 신뢰하지 않고 백엔드에서 검증한다.
- Android 디버그 앱의 패키지명은 `com.ssafy.dib`이다. 릴리스 서명 지문은 현재 구성되지 않았다.
- 서비스 계정 비공개 키와 실제 환경 변수 값은 저장소에 넣지 않는다.
- 현재 `CHANGE_SENSITIVE`를 소비하는 변경 화면/API는 없으므로 공통 인증 경로만 전환한다.
- 로컬 서비스 계정 키는 사용자 설정 폴더에 보관하고, Docker에는 읽기 전용으로 연결한다. EKS에는 별도 키 Secret 또는 Workload Identity Federation이 필요하며 배포 설정은 별도 승인 후 적용한다.
- Git Flow에 따라 컴포넌트 PR이 `develop`에 병합되기 전에는 orchestration의 submodule 포인터를 기록하지 않는다.
- EKS 자격증명은 서비스 계정 키를 Secret `dib-firebase-admin`(키 `firebase-admin.json`)으로 두고 백엔드 Pod의
  `/var/run/secrets/firebase/firebase-admin.json`에 읽기 전용 마운트한다. 키 파일은 저장소 밖 `$HOME\.dib-firebase-admin.json`에서
  `bootstrap.ps1`이 읽는다. Workload Identity Federation은 장기 과제로 남긴다. 인프라 반영 커밋은 `dib-infra` `15ef1bb`이다.
- 배포 APK는 release 키스토어가 없고 release 빌드가 https만 허용하므로 debug 서명 APK를 사용한다.
  빌드한 PC의 debug SHA-1·SHA-256을 Firebase Android 앱에 등록해야 실기기 앱 확인을 통과한다.

## 검증 결과 및 미해결 사항

- Firebase 프로젝트 `ssafy-dib`: Phone 제공업체 활성화, 한국 SMS만 허용, debug SHA-1·SHA-256 등록 확인.
- Firebase 콘솔의 테스트 번호 `+82 10-9999-9999`와 코드 `111111` 사용. 로컬 키 한 개만 유지하고 사용 불가능했던 키 두 개는 폐기 확인.
- 백엔드 `compileJava`와 Firebase 인증·비밀번호 찾기·프로필 이미지 관련 단위/API 테스트 통과. Android `compileDebugKotlin`, `testDebugUnitTest` 통과.
- Pixel_8 에뮬레이터에서 Firebase 테스트 번호와 코드로 ID 토큰을 발급하고 로컬 Docker 백엔드의 인증 토큰 교환 API가 HTTP 200을 반환함을 확인했다. 테스트 전용 계측 코드는 로컬 서비스에 의존하므로 검증 후 제거했다.
- Docker 백엔드의 `/actuator/health`가 HTTP 200을 반환하고 서비스 계정 키가 읽기 전용으로 연결된 것을 확인했다.
- 백엔드의 기존 수정은 `75c8139`, Firebase 인증은 `10a48a5`로 커밋했다. Android Firebase 인증은 `b22052f`로 커밋했다. 세 커밋의 작업 브랜치를 원격에 푸시했다.
- Firebase 테스트 번호는 실제 SMS를 보내지 않아 사용량이 증가하지 않는다. 실제 번호로 로컬 요청한 결과 에뮬레이터 로그에 `17499 BILLING_NOT_ENABLED`가 확인됐다. 현재 Spark 프로젝트에서 실제 SMS를 사용하려면 결제 계정을 연결해 Blaze로 전환해야 한다. 요금제 변경은 수행하지 않았다.
- 사용자 전환 후 Firebase 콘솔에서 Blaze 요금제를 확인했다. 이후 로컬 에뮬레이터의 실제 번호 요청은 `17028 Invalid app info in play_integrity_token`으로 실패했다. 설치 APK의 SHA-1·SHA-256과 Firebase 등록값이 일치함을 확인하고, 디버그 에뮬레이터에서만 reCAPTCHA 앱 확인을 사용하도록 수정했다.
- 2026-09-27 EKS 새 스택에 백엔드 `a2dde56`(digest `sha256:a08ac083…`)을 배포했다. 백엔드 Pod 2개 Ready, 재시작 0회이고
  두 Pod 모두 키 파일이 읽기 전용이며 해시가 원본과 같다. ALB 경유 `/actuator/health`는 UP, QA 하네스의 V901·QA 계정 로그인 검증을 통과했다.
- 배포 서버의 토큰 교환 API는 가짜 토큰에 `400 INVALID_VERIFICATION`을 반환한다. 키 없이 띄운 로컬 대조군은 `503 FIREBASE_UNAVAILABLE`이었다.
- 배포 APK로 에뮬레이터에서 이메일 찾기를 테스트 번호로 진행했다. 틀린 코드에는 "인증번호가 올바르지 않아요.", 올바른 코드에는
  토큰 교환 성공 뒤 "해당 휴대전화 번호로 가입한 계정을 찾을 수 없어요."가 표시됐다. 새 DB라 계정이 없는 것이 정상이다.
- Firebase에는 다른 PC의 debug 지문만 있어 배포 APK 서명 지문(SHA-1 `08:F2:DC:65…`, SHA-256 `5C:60:0C:81…`)을 추가 등록했다.
- 미확인: 실기기의 실제 번호 SMS 수신과 SMS 문구 언어. 에뮬레이터 debug 빌드는 인증 요청 시 Chrome 첫 실행 약관 화면이 뜬다.
