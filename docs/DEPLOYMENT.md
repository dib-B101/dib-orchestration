# Deployment

단기 프로젝트 환경을 재현 가능하게 배포하고 상태를 확인하기 위한 절차를 관리한다.

## 배포 대상

| 항목 | 값 |
| --- | --- |
| 배포 환경 | TBD |
| 배포 방식 | TBD |
| 접근 주소 | TBD |
| 인프라 원본 | `components/infra` |

## 사전 준비

- `git submodule update --init --recursive`로 컴포넌트 버전을 맞춘다.
- `.env.example`을 기준으로 필요한 환경변수를 준비한다.
- 실제 비밀값은 저장소에 커밋하지 않는다.
- `docs/TEST_STRATEGY.md`의 배포 진입 조건을 확인한다.

## 배포 절차

구체적인 명령은 배포 구성이 확정된 후 순서대로 기록한다.

1. TBD
2. TBD
3. TBD

## 로컬 통합 실행

배포 환경 확정 전에는 루트 Docker Compose로 PostgreSQL, Redis, Kafka, Spring Boot,
FastAPI를 함께 검증한다.

1. 루트의 `.env.example`을 `.env`로 복사하고 필수 HMAC 키를 채운다.
2. `docker compose --profile app up -d --build`로 전체 서비스를 실행한다.
3. `docker compose --profile app ps`에서 `backend`와 `ai`를 포함한 모든 서비스가
   healthy인지 확인한다.
4. `GET http://localhost:8000/reco/health`에서 추천 provider가 `postgres`인지 확인한다.
5. `GET http://localhost:8080/actuator/health`와
   `GET http://localhost:8080/api/v1/auctions/recommendation?size=10`을 smoke test한다.

Android 프론트엔드는 컨테이너에 넣지 않는다. Android Studio의 debug 빌드가
`adb reverse tcp:8080 tcp:8080`을 실행하므로 앱은 `127.0.0.1:8080`으로
호스트에 공개된 백엔드에 접속한다.

## 배포 확인

- 모든 컴포넌트가 정상 상태인지 확인한다.
- 핵심 API와 사용자 흐름을 smoke test한다.
- 배포된 버전이 orchestration의 submodule 커밋과 일치하는지 확인한다.
- 시연에 사용할 주소와 계정을 확인한다.

## 재배포 및 복구

장기 운영을 위한 복잡한 장애 대응 대신, 시연 가능한 마지막 검증 버전으로 되돌리는 절차를 기록한다.

1. 마지막 검증 버전: TBD
2. 복구 명령: TBD
3. 복구 후 확인 절차: TBD
