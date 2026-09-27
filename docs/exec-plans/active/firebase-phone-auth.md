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
- [ ] 컴포넌트 병합 후 통합 저장소 submodule 포인터 갱신

## 결정 기록

- Firebase는 휴대전화 소유 확인에 사용하고 DIB의 회원·JWT는 그대로 사용한다.
- Google 발급 ID 토큰은 클라이언트 결과만 신뢰하지 않고 백엔드에서 검증한다.
- Android 디버그 앱의 패키지명은 `com.ssafy.dib`이다. 릴리스 서명 지문은 현재 구성되지 않았다.
- 서비스 계정 비공개 키와 실제 환경 변수 값은 저장소에 넣지 않는다.
- 현재 `CHANGE_SENSITIVE`를 소비하는 변경 화면/API는 없으므로 공통 인증 경로만 전환한다.
- 로컬 서비스 계정 키는 사용자 설정 폴더에 보관하고, Docker에는 읽기 전용으로 연결한다. EKS에는 별도 키 Secret 또는 Workload Identity Federation이 필요하며 배포 설정은 별도 승인 후 적용한다.
- Git Flow에 따라 컴포넌트 PR이 `develop`에 병합되기 전에는 orchestration의 submodule 포인터를 기록하지 않는다.

## 검증 결과 및 미해결 사항

- Firebase 프로젝트 `ssafy-dib`: Phone 제공업체 활성화, 한국 SMS만 허용, debug SHA-1·SHA-256 등록 확인.
- Firebase 콘솔의 테스트 번호 `+82 10-9999-9999`와 코드 `111111` 사용. 로컬 키 한 개만 유지하고 사용 불가능했던 키 두 개는 폐기 확인.
- 백엔드 `compileJava`와 Firebase 인증·비밀번호 찾기·프로필 이미지 관련 단위/API 테스트 통과. Android `compileDebugKotlin`, `testDebugUnitTest` 통과.
- Pixel_8 에뮬레이터에서 Firebase 테스트 번호와 코드로 ID 토큰을 발급하고 로컬 Docker 백엔드의 인증 토큰 교환 API가 HTTP 200을 반환함을 확인했다. 테스트 전용 계측 코드는 로컬 서비스에 의존하므로 검증 후 제거했다.
- Docker 백엔드의 `/actuator/health`가 HTTP 200을 반환하고 서비스 계정 키가 읽기 전용으로 연결된 것을 확인했다.
- 백엔드의 기존 수정은 `75c8139`, Firebase 인증은 `10a48a5`로 커밋했다. Android Firebase 인증은 `b22052f`로 커밋했다. 세 커밋의 작업 브랜치를 원격에 푸시했다.
- Firebase 테스트 번호는 실제 SMS를 보내지 않아 사용량이 증가하지 않는다. 실제 번호로 로컬 요청한 결과 에뮬레이터 로그에 `17499 BILLING_NOT_ENABLED`가 확인됐다. 현재 Spark 프로젝트에서 실제 SMS를 사용하려면 결제 계정을 연결해 Blaze로 전환해야 한다. 요금제 변경은 수행하지 않았다.
- 배포 환경의 Firebase Admin SDK 자격증명은 EKS Secret 또는 Workload Identity Federation으로 별도 준비해야 한다. 이번 작업에서는 배포 설정을 변경하지 않았다.
