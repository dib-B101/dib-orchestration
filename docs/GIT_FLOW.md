# Git Flow Policy

이 문서는 다음 DIB 저장소에 공통으로 적용되는 Git 정책의 원본이다.

- `dib-orchestration`
- `dib-frontend`
- `dib-backend`
- `dib-ai`
- `dib-infra`

각 저장소는 정책을 복제하지 않고 이 문서를 참조한다. 저장소별 예외가 필요하면 임의로 적용하지 말고 이 문서에 근거와 적용 범위를 먼저 기록한다.

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

## 브랜치 보호와 PR

현재 강제 브랜치 보호 정책을 사용하지 않는다.

- PR 승인 인원, 필수 CI, 직접 push 금지를 저장소 설정으로 강제하지 않는다.
- PR 사용 여부와 검토 범위는 작업 영향도에 따라 팀이 결정한다.
- 자동 보호 장치가 없으므로 작업자는 병합 전에 테스트 결과, 대상 브랜치와 변경 범위를 직접 확인한다.
- `main`에 반영되는 릴리스와 hotfix는 태그 및 `develop` 역병합 여부를 반드시 검증한다.

## Submodule 변경

컴포넌트 저장소 변경과 orchestration의 submodule 포인터 변경은 별도 커밋으로 관리한다.

1. 대상 컴포넌트 저장소에서 변경을 먼저 병합한다.
2. `dib-orchestration`에서 해당 submodule을 승인된 커밋으로 갱신한다.
3. `git diff --submodule=log`로 커밋 범위를 확인한다.
4. 통합 검증 후 orchestration 변경을 병합한다.

submodule 내부의 미커밋 변경을 포함한 상태로 orchestration 포인터를 갱신하지 않는다.
