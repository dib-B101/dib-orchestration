# GitHub-GitLab 백업 및 통합 자동화

## 범위

GitHub의 `dib-orchestration`, `dib-frontend`, `dib-backend`, `dib-ai`, `dib-infra`를 개발 원본으로 유지하면서 SSAFY GitLab 단일 저장소에 다음 ref를 자동 생성한다.

- 원본 이력을 보존하는 namespace 백업 브랜치와 태그: `orch/*`, `fe/*`, `be/*`, `ai/*`, `infra/*`
- orchestration submodule 포인터의 실제 파일을 펼친 통합 브랜치: `main`, `develop`

GitHub PR, 리뷰, Issue와 Actions 실행 기록의 복제는 범위에 포함하지 않는다.

## 완료 조건

- GitHub의 모든 일반 브랜치와 태그가 지정된 GitLab namespace로 동기화된다.
- GitHub에서 삭제된 브랜치와 태그가 해당 namespace에서만 삭제된다.
- namespace 백업 ref의 commit SHA가 GitHub 원본과 일치한다.
- GitLab 통합 `main`, `develop`에 네 컴포넌트의 실제 tracked 파일이 존재한다.
- 통합 브랜치에 `.gitmodules`와 submodule gitlink가 남지 않는다.
- `.sync/components.lock`에 다섯 원본 저장소의 정확한 commit SHA가 기록된다.
- 비밀값이 workflow, script, 로그 또는 Git 이력에 포함되지 않는다.
- 로컬 bare repository를 대상으로 백업 및 통합 script를 검증한다.

## 영향받는 저장소

- `dib-orchestration`: reusable workflow, 통합 workflow, 동기화 script와 운영 문서
- `dib-frontend`: `fe` namespace 호출 workflow
- `dib-backend`: `be` namespace 호출 workflow
- `dib-ai`: `ai` namespace 호출 workflow
- `dib-infra`: `infra` namespace 호출 workflow

## 진행 상황

- [x] 요구사항과 branch/tag namespace 결정
- [x] 별도 작업 clone과 feature 브랜치 준비
- [x] namespace 백업 script 구현
- [x] 통합 `main`, `develop` 생성 script 구현
- [x] reusable workflow와 orchestration dispatcher 구현
- [x] 네 컴포넌트 caller workflow 구현
- [x] 로컬 기능 검증
- [x] orchestration 공통 workflow를 `main`에 배포
- [x] 네 컴포넌트 caller workflow를 `main`, `develop`에 배포
- [x] GitLab namespace 백업 ref와 GitHub 원본 SHA 일치 확인
- [x] orchestration `develop`의 컴포넌트 포인터 갱신
- [ ] 문서 및 실행 계획 완료 처리

## 주요 결정

- GitLab 인증은 SSH가 제공되지 않으므로 HTTPS Personal Access Token의 `write_repository` scope를 사용한다.
- GitHub Organization secret `GITLAB_MIRROR_USERNAME`, `GITLAB_MIRROR_TOKEN`을 선택된 다섯 저장소에 공유한다.
- 백업 ref는 경로와 이력을 변경하지 않고 namespace만 추가해 원본 commit SHA를 보존한다.
- GitLab 접두어 없는 `main`, `develop`은 생성형 통합 브랜치로 예약한다.
- 통합 파일 조합은 최신 component branch가 아니라 orchestration의 승인된 submodule 포인터를 기준으로 한다.
- `git push --mirror`를 사용하지 않고 namespace가 제한된 refspec과 `--prune`을 사용한다.
- 통합 branch는 기존 GitLab 통합 branch를 부모로 이어 fast-forward commit만 push한다.

## 검증 기록

- `bash -n`: 두 동기화 script 문법 검사 통과
- Prettier 3.6.2: 일곱 workflow YAML 형식 검사 통과
- actionlint 1.7.12: 일곱 GitHub Actions workflow 정적 검사 통과
- 로컬 bare GitLab 대역: feature branch 생성과 삭제 prune 확인
- namespace 격리: `fe/*` 재조정 중 `be/*` ref가 변경되지 않음을 확인
- 실제 GitHub 원격 다섯 저장소: `main`, `develop`의 namespace 백업 SHA가 모두 원본과 일치
- 통합 `main`, `develop`: 네 컴포넌트 파일과 `.sync/components.lock` 생성 확인
- 통합 결과: `.gitmodules` 없음, mode `160000` gitlink 0개 확인
- 동일 입력 재실행: 통합 branch commit이 추가되지 않는 멱등성 확인
- literal `glpat-` token 패턴이 변경 파일에 없음을 확인
- 실제 GitHub Actions: orchestration과 네 컴포넌트의 최초 백업 실행 성공
- 실제 GitLab 원격: `orch/*`, `fe/*`, `be/*`, `ai/*`, `infra/*` namespace 생성 확인
- 네 컴포넌트의 `main`, `develop` caller workflow 배포 및 실행 성공

## 미해결 문제 및 후속 작업

- GitHub Organization secret은 현재 CLI 계정 권한으로 목록을 읽을 수 없어 실제 workflow 실행으로 유효성을 확인해야 한다.
- GitLab 보호 branch에서 PAT 소유자의 push가 허용되어야 한다.
- 제품 통합 태그 자동화는 branch 동기화가 안정화된 뒤 별도 후속 작업으로 추가한다.
- orchestration 공통 workflow를 `main`에 먼저 병합한 뒤 네 컴포넌트 caller workflow를 push해야 한다.
