# GitLab 백업 및 통합 동기화

GitHub의 다섯 저장소를 개발 원본으로 유지하면서 SSAFY GitLab 단일 저장소에 원본 ref 백업과 통합 `main`, `develop`을 생성한다.

## GitLab ref 구조

| GitLab ref | 원본 또는 역할 |
| --- | --- |
| `main` | `dib-orchestration/main`이 고정한 실제 컴포넌트 파일의 통합본 |
| `develop` | `dib-orchestration/develop`이 고정한 실제 컴포넌트 파일의 통합본 |
| `orch/*` | `dib-orchestration` 원본 ref 백업 |
| `fe/*` | `dib-frontend` 원본 ref 백업 |
| `be/*` | `dib-backend` 원본 ref 백업 |
| `ai/*` | `dib-ai` 원본 ref 백업 |
| `infra/*` | `dib-infra` 원본 ref 백업 |

namespace 백업은 파일과 이력을 변경하지 않아 원본 commit SHA를 유지한다. 통합 branch는 여러 저장소의 파일을 펼쳐 새 commit을 생성하므로 별도 SHA를 가진다.

## 필수 GitHub Organization secrets

`dib-B101` Organization의 `Settings > Secrets and variables > Actions`에서 다음 secret을 생성하고 다섯 저장소에만 허용한다.

| Secret | 값 |
| --- | --- |
| `GITLAB_MIRROR_USERNAME` | GitLab Personal Access Token을 만든 사용자의 username |
| `GITLAB_MIRROR_TOKEN` | `write_repository` scope의 GitLab Personal Access Token |

실제 secret 값을 파일, commit, 로그 또는 채팅에 기록하지 않는다.

## Workflow 배치

`dib-orchestration`이 다음 공통 workflow와 script를 소유한다.

- `.github/workflows/reusable-gitlab-backup.yml`
- `.github/workflows/reusable-build-gitlab-integration.yml`
- `.github/workflows/gitlab-sync.yml`
- `scripts/gitlab-sync/reconcile-backup.sh`
- `scripts/gitlab-sync/build-integration.sh`

각 컴포넌트 저장소는 `.github/workflows/gitlab-backup.yml`에서 공통 백업 workflow를 호출하고 저장소 식별자만 전달한다.

## 최초 적용 순서

1. 공통 workflow와 script를 `dib-orchestration/main`에 먼저 반영한다.
2. orchestration의 `Synchronize GitLab` workflow를 `main` 대상으로 수동 실행해 GitLab `main`을 최초 생성한다.
3. GitLab 프로젝트의 default branch가 `main`인지 확인한다.
4. 동일 workflow를 `develop` 대상으로 실행한다.
5. orchestration 백업으로 `orch/*`가 생성됐는지 확인한다.
6. frontend, backend, AI와 infra의 caller workflow를 각 저장소 `main`에 반영한다.
7. 각 컴포넌트의 `Back up to GitLab` workflow를 수동 실행한다.
8. GitLab의 `main`, `develop`을 보호하고 PAT 소유자의 push를 허용한다.

컴포넌트 caller를 먼저 반영하면 공통 reusable workflow가 아직 `main`에 없어 실행이 실패하므로 순서를 바꾸지 않는다.

## 수동 실행

GitHub Actions에서 `Synchronize GitLab`을 선택하고 `Run workflow`를 실행한다. 통합 대상은 `all`, `main`, `develop` 중 선택한다. 각 컴포넌트 저장소에서는 `Back up to GitLab`을 수동 실행해 해당 namespace 전체를 재조정할 수 있다.

## 검증

원본과 namespace 백업 SHA를 비교한다.

```powershell
$githubSha = (git ls-remote https://github.com/dib-B101/dib-frontend.git refs/heads/develop).Split()[0]
$gitlabSha = (git ls-remote https://lab.ssafy.com/s15-bigdata-recom-sub1/S15P21B101.git refs/heads/fe/develop).Split()[0]
$githubSha -eq $gitlabSha
```

결과는 `True`여야 한다. 통합 `main`, `develop`에는 다음 항목이 모두 존재해야 한다.

- `components/frontend/`
- `components/backend/`
- `components/ai/`
- `components/infra/`
- `.sync/components.lock`

통합 결과에는 `.gitmodules`와 mode `160000`의 gitlink가 없어야 한다.

## 운영 규칙

- GitHub에서만 branch, commit, PR, merge와 tag 작업을 수행한다.
- GitLab에서 직접 branch, commit, MR 또는 tag를 만들지 않는다.
- 컴포넌트 변경을 통합하려면 먼저 대상 저장소에서 병합하고 orchestration submodule 포인터를 갱신한다.
- `develop`은 통합 검증 대상, `main`은 검증된 안정 버전으로 유지한다.
- Git Flow에 따라 병합한 작업 branch는 GitHub에서 삭제한다. 예약 동기화가 GitLab namespace의 누락된 삭제를 복구한다.
- PAT를 회전할 때 GitHub Organization secret만 교체하고 workflow 파일은 변경하지 않는다.

## 장애 처리

- `401` 또는 `403`: PAT 만료, `write_repository` scope와 프로젝트 push 권한을 확인한다.
- protected branch 거절: GitLab `main`, `develop` 규칙에서 PAT 소유자의 push 허용 여부를 확인한다.
- reusable workflow를 찾을 수 없음: orchestration 공통 workflow가 `main`에 먼저 병합됐는지 확인한다.
- 통합 SHA 불일치: orchestration submodule을 `git submodule update --init --recursive`로 다시 맞춘다.
- branch/tag 누락: 해당 GitHub 저장소의 `Back up to GitLab`을 수동 실행한다.
