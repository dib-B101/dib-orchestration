# QA 배포 하네스

이 문서는 DIB QA 배포의 단일 진입점이다. 사람이 Gradle 전역 설정이나 예전 APK를 믿고 배포하지 않는다.
반드시 `scripts/qa-release-harness.ps1`을 통과한 APK와 증적 JSON만 QA에 전달한다.

## 절대 규칙

1. 배포 APK에 `localhost`, `127.0.0.1`, `10.0.2.2`를 API 주소로 넣지 않는다.
2. API 주소는 Kubernetes Ingress의 현재 ALB hostname에서 자동으로 얻는다.
3. WebSocket 주소는 같은 호스트의 `/ws`만 사용한다.
4. 백엔드 이미지는 `latest`가 아니라 Git SHA 태그를 사용한다.
5. 모든 백엔드 Pod가 같은 image digest, Ready, 재시작 0회여야 한다.
6. Flyway가 최소 V901이고 `qa.seller1@dib.test` 로그인이 성공해야 한다.
7. APK를 만든 뒤 생성 소스만 보지 않고 DEX 안에서 API와 WebSocket 전체 주소를 다시 찾는다.
8. 하네스가 만든 `*.manifest.json`이 없는 APK는 배포 APK로 취급하지 않는다.
9. DB 삭제, Secret 전체 재생성, Redis flush는 이 하네스의 작업이 아니며 자동 실행하지 않는다.

## 1. 사전 조건

```powershell
aws sts get-caller-identity
aws eks update-kubeconfig --name dib-eks --region ap-northeast-2
kubectl config current-context
kubectl get deployment dib-backend
```

다음 Kubernetes Secret 키가 있어야 한다. 값은 출력하지 않는다.

```powershell
kubectl get secret dib-secrets -o json |
  ConvertFrom-Json |
  ForEach-Object { $_.data.PSObject.Properties.Name | Sort-Object }
```

필수 키:

- `KAKAO_CLIENT_ID`: 앱에 넣는 카카오 REST API 키
- `KAKAO_REDIRECT_URIS`: 앱과 백엔드가 공통으로 쓰는 HTTPS callback
- 백엔드 실행에 필요한 DB, JWT, Redis, Kafka 등의 기존 키

`dib-secrets`를 삭제 후 재생성하지 않는다. 필요한 키만 부분 갱신한다.

## 2. 코드와 이미지 고정

루트와 네 submodule의 변경을 모두 커밋하고 원격 `main`에 push한다.

```powershell
git status --short
git submodule status --recursive
git -C components/backend rev-parse HEAD
git -C components/frontend rev-parse HEAD
```

백엔드 이미지는 backend Git SHA로 빌드하고 ECR에 push한다. 아래 `<BACKEND_SHA>`에는
`git -C components/backend rev-parse --short=7 HEAD` 결과를 넣는다.

```powershell
$account = (aws sts get-caller-identity | ConvertFrom-Json).Account
$region = "ap-northeast-2"
$sha = git -C components/backend rev-parse --short=7 HEAD
$image = "$account.dkr.ecr.$region.amazonaws.com/dib-backend:$sha"

aws ecr get-login-password --region $region |
  docker login --username AWS --password-stdin "$account.dkr.ecr.$region.amazonaws.com"

docker build --platform linux/amd64 -t $image components/backend
docker push $image
```

## 3. 배포와 APK 생성: 이 명령만 사용

```powershell
cd C:\Users\SSAFY\Desktop\dev\dib\dib-orchestration

$account = (aws sts get-caller-identity | ConvertFrom-Json).Account
$region = "ap-northeast-2"
$sha = git -C components/backend rev-parse --short=7 HEAD
$image = "$account.dkr.ecr.$region.amazonaws.com/dib-backend:$sha"

.\scripts\qa-release-harness.ps1 -BackendImage $image -RequiredMigrationVersion 901
```

하네스의 순서는 다음과 같다.

1. dirty worktree와 Kubernetes context 검사
2. Ingress에서 현재 ALB 주소 자동 조회
3. 로컬 API 주소와 `latest` 이미지 거부
4. 백엔드 이미지 교체 및 rollout 대기
5. replica Ready, 재시작 횟수, image digest 동일성 검사
6. Pod 시작 로그에서 Flyway V901 확인
7. 외부 health, 추천 API, V901 QA 계정 로그인 smoke test
8. Kubernetes Secret에서 카카오 공개 설정을 읽고 Gradle 환경변수로 주입
9. `clean :app:assembleDebug` 실행
10. BuildConfig와 APK DEX에서 실제 AWS API·WebSocket 주소 재검증
11. APK와 SHA-256, 커밋, 이미지 digest를 담은 증적 JSON 생성

성공 출력의 `APK`, `SHA256`, `Evidence` 세 항목을 QA 기록에 함께 남긴다.

## 4. 백엔드는 이미 배포됐고 APK만 다시 만들 때

`-BackendImage`를 생략한다. 현재 배포의 Pod·digest·V901·외부 API는 그대로 검증하고 APK만 새로 만든다.

```powershell
.\scripts\qa-release-harness.ps1 -RequiredMigrationVersion 901
```

주소를 수동 입력할 필요가 없다. 특별한 이유로 직접 지정한다면 API와 WebSocket을 반드시 함께 준다.

```powershell
.\scripts\qa-release-harness.ps1 `
  -ApiBaseUrl "http://<ALB_HOST>" `
  -WebSocketUrl "ws://<ALB_HOST>/ws" `
  -RequiredMigrationVersion 901
```

## 5. 실기기 설치

하네스 성공 출력에 나온 APK 경로를 그대로 사용한다. 예전 APK 이름을 재사용하지 않는다.

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$phone = "R3CY107VMJW"

& $adb devices -l
& $adb -s $phone install -r "<하네스가 출력한 APK 절대경로>"
```

`device not found`면 빌드 문제가 아니다. 휴대폰 잠금을 풀고 USB 연결 모드를 파일 전송으로 바꾼 뒤
휴대폰의 USB 디버깅 허용 팝업을 승인한다. `adb devices -l`에서 상태가 `device`가 된 뒤 설치한다.

## 6. 실패 시 배포 승인 금지

| 하네스 오류 | 의미 | 조치 |
| --- | --- | --- |
| 로컬 API 주소 거부 | 에뮬레이터 설정이 배포에 섞임 | 주소를 직접 고치지 말고 Ingress 자동 조회 사용 |
| `:latest` 거부 | 어느 커밋인지 재현 불가 | Git SHA 태그로 다시 빌드·push |
| Pod digest 불일치 | 구/신 이미지 혼재 | rollout 상태와 ReplicaSet 확인 |
| V901 확인 실패 | 이미지가 낡았거나 DB migration 미적용 | Pod 시작 로그와 Flyway history 확인 |
| QA 시드 로그인 실패 | V901 시드 또는 인증 문제 | 배포 승인 중단 후 백엔드 로그 확인 |
| DEX에서 AWS 주소 없음 | 잘못된 Gradle property로 APK 생성 | APK 폐기 후 하네스로 재빌드 |
| HTTP인데 cleartext 미허용 | Android가 ALB 요청을 차단 | debug merged manifest 확인 또는 ALB HTTPS 전환 |

## 7. 롤백

장애가 있으면 새 DB 데이터를 삭제하지 않는다. 먼저 직전의 검증된 불변 이미지로 Deployment만 되돌린다.

```powershell
kubectl rollout history deployment/dib-backend
kubectl rollout undo deployment/dib-backend --to-revision=<정상_REVISION>
kubectl rollout status deployment/dib-backend --timeout=300s
```

Flyway migration은 기본적으로 역삭제하지 않는다. 스키마 호환성 문제가 있으면 별도 forward-fix migration을 만든다.

## 현재 기준선

- EKS: `dib-eks`, `ap-northeast-2`, namespace `default`
- Backend Deployment: `dib-backend`, container `app`, replica 2
- 필수 Flyway 기준: V901
- Android package: `com.ssafy.dib`
- WebSocket endpoint: `/ws`

주소와 이미지 digest는 바뀔 수 있으므로 문서에 적힌 과거 값을 복사하지 않고 하네스가 매번 조회한다.
