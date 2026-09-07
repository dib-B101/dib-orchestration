# 통합 경매 플랫폼 계약 요약

> 상태: Draft
>
> 상세 원본: 요구사항, 기능, REST API, WebSocket, Kafka, 공통 오류 코드, Redis Key·TTL Google Sheet
>
> 원칙: 필드·타입·오류·TTL의 행 단위 값은 Sheet를 우선한다.

## REST 경계

### 일반 경매

| 목적 | 메서드·경로 | 인증 |
| --- | --- | --- |
| 홈(추천/마감임박/인기) | `GET /api/v1/auctions/home` | 선택 |
| 목록·검색 | `GET /api/v1/auctions` | 선택 |
| 상세 | `GET /api/v1/auctions/{auctionId}` | 선택 |
| 생성 | `POST /api/v1/auctions` | 필수, 판매자 |
| 시작 전 수정 | `PATCH /api/v1/auctions/{auctionId}` | 필수, 소유자 |
| 시작 전 취소 | `DELETE /api/v1/auctions/{auctionId}` | 필수, 소유자 |

상세 원본의 REST ID는 108~113이다. `GET /api/v1/auctions/{auctionId}/bids`와 `GET /api/v1/auctions/{auctionId}/bid-snapshot`은 일반 경매에서 익명 마스킹 조회를 허용한다.

### Live

Backend는 다음 능력을 REST로 제공한다.

- 방송 생성과 설정 변경
- 최대 10개 상품 라인업 구성·순서 관리
- 송출 세션 준비
- 방송 즉시 시작
- 선택 상품 경매 즉시 시작
- 방송 종료(활성 경매가 없을 때만)
- 현재 방송 상세 및 방송 중 Live 피드 조회

Live의 상품 상세·입찰 내역 등 회원 활동 API는 인증을 요구한다. 익명 응답은 영상 재생에 필요한 정보, 현재 상품/경매 상태와 시청자 수로 제한한다.

## WebSocket 경계

| 채널 | 주요 이벤트 | 접근 |
| --- | --- | --- |
| `auction:{auctionId}` | `SUBSCRIBE_AUCTION`, `SNAPSHOT`, `PLACE_BID`, `HIGHEST_BID_UPDATED`, `AUCTION_EXTENDED`, `AUCTION_ENDED`, `SYNC` | 일반 경매 조회 이벤트는 익명 허용, 입찰은 회원만. Live 경매 채널은 회원만 |
| `live:{liveBroadcastId}` | 방송 상태, 현재 상품, 현재 경매 상태, 시청자 수, 채팅 | 익명은 상태 미러링만 수신하고 채팅·입찰은 불가 |

재연결 시 클라이언트는 마지막 수신 버전으로 `SYNC`하고 서버는 스냅샷 또는 누락분을 제공한다. 권한은 연결 시점과 명령 처리 시점에 모두 검사한다.

## Kafka 경계

- 일반 경매 생명주기: `auction.scheduled.v1`, `auction.started.v1`, `auction.ended.v1`, `auction.cancelled.v1`
- 입찰: 입찰 접수·최고가 변경·연장·종료 결과 관련 버전 이벤트
- Live: 방송 시작/종료, 상품 경매 열림/닫힘, 송출 상태 변경 관련 버전 이벤트

이벤트는 고유 ID, 발생 시각, 스키마 버전과 도메인 식별자를 가진다. 경매 관련 토픽의 파티션 키는 `auctionId`로 하여 같은 경매의 순서를 보존하고, 소비자는 이벤트 ID로 멱등 처리한다. 정확한 토픽명과 payload는 Kafka Sheet를 따른다.

## Redis 경계

- 일반 경매 시작·종료 스케줄과 스케줄 버전
- 경매 실시간 최고가·종료 시각·상태
- 경매 카드, 상세, 목록·검색, 추천·인기 캐시
- Live 방송 상태, 현재 상품·경매, 방송 중 피드
- Live presence/시청자 수와 송출 복구 타이머

키 패턴, 자료구조와 TTL은 Redis Sheet가 원본이다. Redis 유실 시 DB와 이벤트로 핵심 거래 상태를 복구할 수 있어야 한다.

## 공통 오류 경계

구현 시 최소한 다음 의미를 구별한다.

- `INVALID_AUCTION`: 대상 경매가 없거나 유효하지 않음
- `AUCTION_SCHEDULE_INVALID`: 시작·종료 예약 조건 위반
- `AUCTION_STARTED`: 시작 후 수정·취소 시도
- `PRODUCT_ALREADY_LISTED`: 상품의 활성 노출 충돌
- `LIVE_AUCTION_ALREADY_ACTIVE`: 방송 내 동시 상품 경매 시작 시도
- `LIVE_END_BLOCKED_BY_AUCTION`: 활성 경매가 있는 방송 종료 시도
- `STREAM_UNAVAILABLE`: 송출 장애 중 신규 상품 경매 시작 시도

HTTP/WS 매핑, 코드 번호와 메시지는 공통 오류 코드 Sheet를 따른다.

## 공통 불변조건

- 서버는 `auctionType`별 조회 권한을 판정한다.
- 익명 요청은 상태 변경을 수행하지 않는다.
- 판매자는 자기 경매에 입찰할 수 없고 현재 최고 입찰자는 자기 가격을 올릴 수 없다.
- 최초 입찰 예치금은 입찰액의 10%, 최소 1,000원이며 이후 추가 충전하지 않는다.
- 최소 입찰 증가는 1,000원이고, 마지막 30초 내 유효 입찰은 15초 무제한 연장한다.
- Live 상품 경매 시작과 방송 종료 명령은 현재 방송·경매 상태를 조건부로 갱신한다.

## 변경 관리

호환 가능한 필드 추가는 기존 버전에서 허용할 수 있으나 소비자는 알 수 없는 필드를 무시해야 한다. 의미 변경, 필드 제거, 타입 변경은 API 또는 이벤트의 새 버전으로 제공한다. Sheet 변경과 이 요약, 제품 명세, 설계 문서의 불변조건을 같은 작업에서 검토한다.
