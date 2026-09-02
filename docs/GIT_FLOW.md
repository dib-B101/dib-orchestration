# Git Flow Policy

이 문서는 다음 DIB 저장소에 공통으로 적용되는 Git 정책의 원본이다.

- `dib-orchestration`
- `dib-frontend`
- `dib-backend`
- `dib-ai`
- `dib-infra`

각 저장소는 정책을 복제하지 않고 이 문서를 참조한다. 저장소별 예외가 필요하면 임의로 적용하지 말고 이 문서에 근거와 적용 범위를 먼저 기록한다.

## 저장소 식별자

GitLab 단일 저장소의 원본 ref 백업에는 다음 식별자를 사용한다.

| 저장소 | 식별자 |
| --- | --- |
| `dib-orchestration` | `orch` |
| `dib-frontend` | `fe` |
| `dib-backend` | `be` |
| `dib-ai` | `ai` |
| `dib-infra` | `infra` |

## 장기 브랜치

| 브랜치 | 역할 |
| --- | --- |
| `main` | 배포 가능한 안정 버전과 릴리스 태그를 유지한다. |
| `develop` | 다음 릴리스를 위한 변경을 통합한다. |

## 작업 브랜치

| 유형 | 형식 | 시작 브랜치 | 병합 대상 | 예시 |
| --- | --- | --- | --- | --- |
| 기능 | `feature/<description>` | `develop` | `develop` | `feature/user-login` |
| 릴리스 | `release/<version>` | `develop` | `main`, `develop` | `release/1.2.0` |
| 긴급 수정 | `hotfix/<description>` | `main` | `main`, `develop` | `hotfix/login-timeout` |

`description`은 짧은 영문 소문자 kebab-case를 사용한다. 브랜치 이름에는 이슈 번호를 요구하지 않는다.

GitLab namespace 백업 branch는 `<repository-id>/<source-branch>` 형식을 사용한다. 예를 들어 frontend의 `feature/user-login`은 GitLab의 `fe/feature/user-login`으로 백업한다. 접두어 없는 GitLab `main`, `develop`은 전체 파일을 펼친 생성형 통합 branch로 예약한다.

## 병합 정책

### Feature

1. `develop`에서 `feature/<description>` 브랜치를 만든다.
2. 기능 구현과 검증을 완료한다.
3. 변경을 `develop`에 squash merge한다.
4. 병합 후 feature 브랜치를 삭제한다.

Squash 결과 커밋은 아래 커밋 메시지 정책을 따라야 한다.

### Release

1. 릴리스 준비 시점의 `develop`에서 `release/<version>` 브랜치를 만든다.
2. 릴리스 브랜치에서는 안정화, 버전 갱신과 문서 보완만 수행한다.
3. 검증이 끝나면 `main`에 `--no-ff` merge한다.
4. 동일한 release 브랜치를 `develop`에도 `--no-ff` merge한다.
5. `main`의 릴리스 커밋에 `v<major>.<minor>.<patch>` 태그를 생성한다.
6. 병합과 태그 확인 후 release 브랜치를 삭제한다.

### Hotfix

1. 운영 긴급 수정이 필요하면 `main`에서 `hotfix/<description>` 브랜치를 만든다.
2. 수정과 회귀 검증을 완료한다.
3. `main`에 `--no-ff` merge하고 새 버전 태그를 생성한다.
4. 동일한 hotfix 브랜치를 `develop`에도 `--no-ff` merge한다.
5. 양쪽 반영과 태그 확인 후 hotfix 브랜치를 삭제한다.

## 버전과 태그

Semantic Versioning을 사용한다.

- 버전: `<major>.<minor>.<patch>`
- Git 태그: `v<major>.<minor>.<patch>`
- 예시: `1.2.3`, `v1.2.3`

호환되지 않는 변경은 major, 하위 호환 기능은 minor, 하위 호환 수정은 patch를 증가시킨다.

GitLab에서는 컴포넌트 tag 충돌을 막기 위해 `<repository-id>/v<version>` 형식으로 백업한다.

- frontend: `fe/v1.2.0`
- backend: `be/v1.2.0`
- AI: `ai/v1.2.0`
- infra: `infra/v1.2.0`
- orchestration: `orch/v1.2.0`

접두어 없는 `v<version>`은 통합 `main`의 전체 제품 release에만 사용한다. 게시한 tag를 이동하거나 같은 이름으로 다시 만들지 않는다.

## 커밋 메시지

영문 Conventional Commit 타입과 한글 설명을 사용한다.

```text
<type>(<optional-scope>): <한글 설명>
```

scope는 선택 사항이며 저장소 안에서 일관된 영문 소문자를 사용한다.

| 타입 | 용도 |
| --- | --- |
| `feat` | 새로운 기능 |
| `fix` | 버그 수정 |
| `docs` | 문서 변경 |
| `refactor` | 동작 변경 없는 구조 개선 |
| `test` | 테스트 추가 또는 수정 |
| `perf` | 성능 개선 |
| `build` | 빌드 시스템 또는 의존성 변경 |
| `ci` | CI 설정 변경 |
| `chore` | 그 밖의 유지보수 작업 |
| `revert` | 기존 변경 되돌리기 |

예시:

```text
feat(auth): 소셜 로그인 기능 추가
fix: 토큰 만료 시 재요청 오류 수정
docs: Git Flow 정책 문서화
```

## 커밋 작성자 식별

GitHub와 GitLab이 커밋을 같은 팀원의 활동으로 연결할 수 있도록 각 팀원은 두 서비스에 등록하고 인증한 동일한 이메일을 사용한다.

```bash
git config --global user.name "팀원이 식별 가능한 표시 이름"
git config --global user.email "GitHub와 GitLab에서 인증한 동일 이메일"
```

- `user.name`은 커밋에 표시되는 이름이며 GitHub username과 같을 필요는 없다.
- `user.email`은 커밋 작성자를 계정에 연결하는 기준이므로 GitHub와 GitLab 양쪽에서 인증된 주소여야 한다.
- 설정 변경은 이후 생성되는 커밋부터 적용되며 이미 게시한 커밋의 작성자를 바꾸기 위해 이력을 재작성하지 않는다.
- PR merge commit은 실제로 병합한 계정이 작성자로 표시될 수 있다.
- `Unverified` 표시는 작성자 계정 불일치가 아니라 GPG 또는 SSH commit 서명이 검증되지 않았다는 의미다.
- 커밋 작성자와 원격에 push한 사용자는 서로 다를 수 있다. 자동 동기화의 GitLab push 활동은 PAT 소유자로 기록된다.

## 브랜치 보호와 PR

현재 강제 브랜치 보호 정책을 사용하지 않는다.

- PR 승인 인원, 필수 CI, 직접 push 금지를 저장소 설정으로 강제하지 않는다.
- 일반 기능, release와 hotfix는 작업 브랜치에서 진행하고 PR을 통해 `develop` 또는 `main`에 병합한다.
- 초기 자동화 설정, CI 복구 또는 긴급 정책 문서처럼 팀이 명시적으로 합의한 변경만 예외적으로 장기 브랜치에 직접 push할 수 있다.
- 자동 보호 장치가 없으므로 작업자는 병합 전에 테스트 결과, 대상 브랜치와 변경 범위를 직접 확인한다.
- `main`에 반영되는 릴리스와 hotfix는 태그 및 `develop` 역병합 여부를 반드시 검증한다.

## Submodule 변경

컴포넌트 저장소 변경과 orchestration의 submodule 포인터 변경은 별도 커밋으로 관리한다.

1. 대상 컴포넌트 저장소에서 변경을 먼저 병합한다.
2. `dib-orchestration`에서 해당 submodule을 승인된 커밋으로 갱신한다.
3. `git diff --submodule=log`로 커밋 범위를 확인한다.
4. 통합 검증 후 orchestration 변경을 병합한다.

submodule 내부의 미커밋 변경을 포함한 상태로 orchestration 포인터를 갱신하지 않는다.

## GitHub-GitLab 동기화

GitHub의 다섯 저장소가 개발 원본이며 GitLab 단일 저장소는 읽기 전용 백업 및 통합본이다.

- 원본 branch와 tag는 `orch/*`, `fe/*`, `be/*`, `ai/*`, `infra/*` namespace로 백업한다.
- namespace 백업 ref는 원본 commit SHA를 유지한다.
- GitLab `main`, `develop`은 orchestration의 같은 이름 branch가 고정한 submodule commit을 일반 directory로 펼쳐 생성한다.
- 통합 branch는 `.sync/components.lock`에 원본 commit SHA를 기록한다.
- 동기화에는 HTTPS Personal Access Token의 `write_repository` scope를 사용한다.
- GitHub branch와 tag의 push 또는 삭제는 대응하는 namespace 백업을 갱신한다. PR 생성 자체는 별도의 동기화 조건이 아니다.
- orchestration의 `main` 또는 `develop`에 merge 또는 push가 발생하면 대응하는 GitLab 통합 branch를 갱신한다.
- namespace 백업은 원본 commit 작성자와 SHA를 보존한다. 통합 branch는 orchestration commit 작성자를 author로, 자동화 계정을 committer로 사용하는 별도 생성 commit이므로 컴포넌트별 commit 이력을 직접 표시하지 않는다.
- GitLab에서 직접 commit, branch, tag 또는 MR을 만들지 않는다.
- namespace가 제한된 refspec만 사용하고 무제한 `git push --mirror`는 사용하지 않는다.
- GitHub PR, 리뷰, Issue와 Actions 이력은 GitLab으로 복제하지 않는다.

설정, 최초 적용, 검증과 장애 처리는 [`GITLAB_SYNC.md`](GITLAB_SYNC.md)를 따른다.
