# Deployment

> 상태: Draft

일반 경매와 Live 경매를 통합 환경에 재현 가능하게 배포하고 핵심 계약을 확인하기 위한 상위 절차다. 실제 명령과 인프라 구현의 원본은 `components/infra`와 그 내부 문서가 소유한다.

## 배포 대상

| 항목 | 역할 | 현재 상태 |
| --- | --- | --- |
| Frontend | 일반 경매 UI, Live 피드와 방송 제어 | 컴포넌트 문서 확인 필요 |
| Backend | REST, WebSocket, 경매·거래 도메인 | 컴포넌트 문서 확인 필요 |
| AI | 상품 심사, 이상 거래 탐지 | 컴포넌트 문서 확인 필요 |
| 관계형 DB | 거래 상태의 영속 원본 | 엔진·스키마 TBD |
| Redis | 실시간 상태, 스케줄, 캐시, presence | 키 원본은 Google Sheet |
| Kafka | 버전 도메인 이벤트 | 토픽 원본은 Google Sheet |
| Object Storage | 상품·방송 이미지와 미디어 | 인프라 구성 확인 필요 |
| Streaming Provider | Live 영상 송출과 상태 신호 | 공급자·프로토콜 TBD |

현재 Infrastructure 개요는 AWS의 S3/ECR, VPC/EKS/RDS/Redis, Kafka와 ALB/HPA 방향을 기술한다. 이는 배포 시점에 `components/infra`의 실제 구성과 다시 검증한다.

## 사전 준비

- `git submodule update --init --recursive`로 검증 대상 컴포넌트 버전을 맞춘다.
- 각 컴포넌트의 예시 설정을 기준으로 환경변수를 준비하며 실제 비밀값은 커밋하지 않는다.
- DB migration의 대상 엔진과 `dib.sql` 초안 대비 확정 스키마를 확인한다.
- Streaming Provider 자격 정보, webhook 접근과 이미지 fallback 자산을 준비한다.
- Kafka 토픽, Redis 정책과 외부 네트워크 접근 조건을 확인한다.
- [`docs/TEST_STRATEGY.md`](TEST_STRATEGY.md)의 배포 진입 조건을 확인한다.

## 논리 배포 순서

1. 네트워크, Object Storage와 이미지/ECR 저장소를 준비한다.
2. 관계형 DB, Redis와 Kafka를 준비하고 schema/topic 정책을 적용한다.
3. AI와 Backend를 배포하고 내부 health 및 외부 연동을 확인한다.
4. Streaming Provider 연동과 상태 callback/webhook을 확인한다.
5. Frontend를 배포하고 Backend·WebSocket·송출 endpoint를 연결한다.
6. 통합 smoke test를 실행한 뒤 검증된 submodule 조합을 기록한다.

정확한 명령, namespace, manifest/Terraform 경로와 되돌리기 명령은 `components/infra/docs/`의 확정 문서를 따른다. 현재 저장소에서는 임의로 만들지 않는다.

## Smoke test

- 익명 사용자가 일반 경매 홈·검색·상세를 조회한다.
- 회원이 일반 경매에 입찰하고 최고가 WebSocket 이벤트를 수신한다.
- 예약 경매가 자동 시작되고 마감 연장 후 한 번만 종료된다.
- 판매자가 Live 설정·상품 구성을 완료하고 방송과 상품 경매를 시작한다.
- 익명 Live 시청자는 제한된 상태만 받고 회원은 입찰·채팅 권한을 얻는다.
- 활성 상품 경매 중 방송 종료와 두 번째 상품 경매 시작이 거절된다.
- 송출 장애를 주입했을 때 이미지 fallback과 경매 지속 정책이 작동한다.
- Kafka/Redis 재시도 뒤 DB의 최종 거래 상태가 일관된다.

## 배포 정보와 복구

| 항목 | 값 |
| --- | --- |
| 배포 환경·접근 주소 | TBD |
| 컴포넌트별 배포 명령 | TBD (`components/infra` 확정 필요) |
| 관측성 dashboard·alert | TBD |
| 마지막 검증 버전 | TBD |
| 복구 명령 | TBD |

복구 후 health check, 일반 경매 조회·입찰, Live 방송 상태와 데이터 migration 버전을 재확인한다.
