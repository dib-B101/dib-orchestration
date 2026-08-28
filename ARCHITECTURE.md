# System Architecture

## 목적

이 문서는 DIB 시스템의 최상위 컴포넌트 경계와 통합 관계를 설명한다. 각 컴포넌트의 내부 구현은 해당 저장소 문서를 따른다.

## 컴포넌트 경계

| 컴포넌트 | 경로 | 책임 | 상세 문서 |
| --- | --- | --- | --- |
| Frontend | `components/frontend` | 사용자 인터페이스 | `components/frontend/README.md` |
| Backend | `components/backend` | API와 비즈니스 로직 | `components/backend/README.md` |
| AI | `components/ai` | AI 서비스와 모델 파이프라인 | `components/ai/README.md` |
| Infrastructure | `components/infra` | 인프라와 배포 환경 | `components/infra/README.md` |

## 시스템 관계

구체적인 프로토콜, 데이터 흐름과 배포 토폴로지는 아직 확정되지 않았다. 결정 후 `docs/design-docs/`에 설계 문서를 추가하고 이 문서에서 연결한다.

## 의존성 원칙

- 컴포넌트 내부 구현을 다른 컴포넌트가 직접 참조하지 않는다.
- 컴포넌트 간 통신은 명시적인 API 또는 이벤트 계약을 사용한다.
- 통합 계약의 원본은 `docs/contracts/`에서 관리한다.
- 배포 환경의 실제 구현은 `components/infra`가 소유한다.
- submodule 커밋은 검증된 시스템 조합을 표현한다.

## 미결정 사항

- 서비스 간 통신 방식
- 인증 및 인가 경계
- 데이터 소유권과 저장소 구성
- 로컬 통합 실행 방식
- 배포 환경과 관측성 구성
