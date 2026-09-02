# dib-orchestration

DIB 프로젝트의 통합 문서, 아키텍처, 실행 계획과 컴포넌트 버전을 관리하는 저장소입니다.

## 시작하기

```bash
git clone --recurse-submodules https://github.com/dib-B101/dib-orchestration.git
cd dib-orchestration
```

이미 저장소를 복제했다면 다음 명령으로 컴포넌트를 내려받습니다.

```bash
git submodule update --init --recursive
```

## 컴포넌트

| 경로 | 저장소 | 책임 |
| --- | --- | --- |
| `components/frontend` | `dib-frontend` | 사용자 인터페이스 |
| `components/backend` | `dib-backend` | API와 비즈니스 로직 |
| `components/ai` | `dib-ai` | AI 서비스와 모델 파이프라인 |
| `components/infra` | `dib-infra` | 인프라와 배포 환경 |

## 문서

- 에이전트 작업 지도: [`AGENTS.md`](AGENTS.md)
- 시스템 구조: [`ARCHITECTURE.md`](ARCHITECTURE.md)
- 제품 명세: [`docs/product-specs/index.md`](docs/product-specs/index.md)
- 설계 문서: [`docs/design-docs/index.md`](docs/design-docs/index.md)
- 실행 계획: [`docs/PLANS.md`](docs/PLANS.md)
- Git Flow 정책: [`docs/GIT_FLOW.md`](docs/GIT_FLOW.md)
- GitLab 백업 및 통합 동기화: [`docs/GITLAB_SYNC.md`](docs/GITLAB_SYNC.md)
- 테스트 전략: [`docs/TEST_STRATEGY.md`](docs/TEST_STRATEGY.md)
- 배포 절차: [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md)
- 시연 절차: [`docs/DEMO_RUNBOOK.md`](docs/DEMO_RUNBOOK.md)

이 저장소에는 시스템 전체에 적용되는 문서를 둡니다. 컴포넌트 내부 구현 문서는 해당 submodule에서 관리합니다.
