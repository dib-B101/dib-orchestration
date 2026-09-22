# System Architecture

## 목적

이 문서는 DIB 시스템의 최상위 컴포넌트 경계와 통합 관계를 설명한다. 각 컴포넌트의 내부 구현은 해당 저장소 문서를 따른다.

## 컴포넌트 경계

| 컴포넌트 | 경로 | 책임 | 상세 문서 |
| --- | --- | --- | --- |
| Frontend | `components/frontend` | Android 사용자 앱과 React 관리자 콘솔 | `components/frontend/README.md` |
| Backend | `components/backend` | API와 비즈니스 로직 | `components/backend/README.md` |
| AI | `components/ai` | AI 서비스와 모델 파이프라인 | `components/ai/README.md` |
| Infrastructure | `components/infra` | 인프라와 배포 환경 | `components/infra/README.md` |

## 시스템 관계

- Frontend는 사용자 경험을 제공하고 Backend가 노출한 계약을 소비한다.
- Backend는 비즈니스 규칙, 데이터와 외부 연동을 소유한다.
- AI는 Backend와 합의한 경계를 통해 검수, 탐지와 추천 기능을 제공한다.
- Infrastructure는 컴포넌트가 실행되는 환경, 네트워크와 운영 기반을 소유한다.

API, 이벤트와 ERD는 개발 중 변경되는 상세 명세이므로 이 문서에 복제하지 않는다. 통합 작업마다 사용자가 제공한 최신 Sheet와 ERD를 기준으로 검토한다. 합의가 완료된 시스템 수준 결정만 관련 시스템 문서와 실행 계획에 남긴다.

## 의존성 원칙

- 컴포넌트 내부 구현을 다른 컴포넌트가 직접 참조하지 않는다.
- 컴포넌트 간 통신은 명시적인 API 또는 이벤트 계약을 사용한다.
- 확정된 통합 계약은 영향받는 시스템 문서와 컴포넌트 문서에서 함께 추적한다.
- 배포 환경의 실제 구현은 `components/infra`가 소유한다.
- submodule 커밋은 검증된 시스템 조합을 표현한다.
- 관리자 브라우저는 AI를 직접 호출하지 않고 JWT로 Backend 관리자 API를 호출한다. 상품 검수 요청과 결과 반영은 Backend가 AI 내부 API를 통해 수행한다.

## 미결정 사항

- 서비스 간 통신 방식과 계약
- 인증 및 인가 경계
- 데이터 소유권과 저장소 구성
- 로컬 통합 실행 방식
- 배포 환경과 관측성 구성
