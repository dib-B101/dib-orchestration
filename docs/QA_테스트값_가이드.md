# QA 테스트값 가이드 — 카드·계좌·운송장·계정

> 2026-09-22 기준. 백엔드 코드와 `flow_test.py`, Postman 컬렉션에서 실제로 쓰는 값만 적었다.
> 로컬(docker compose, `local` 프로필)과 배포(EKS, `prod` 프로필)에서 되는지 여부를 항목마다 표시한다.

| 항목 | 로컬 | 배포 |
|---|---|---|
| 토스 테스트 카드로 자동결제 | ✅ | ✅ (`TOSS_SECRET_KEY`가 `test_sk_`이면) |
| `/dev/**` 카드 직접 등록 | ✅ | ❌ (`local` 전용) |
| 정산 계좌 아무 숫자 | ✅ | ✅ |
| 운송장 끝자리 9 = 배송완료 | ✅ (`fake`) | ✅ (`CARRIER_PROVIDER` 미설정 시) |
| `DUMMY` 택배사 + 시각 운송장 | ✅ (`deliverytracker`) | ✅ (`deliverytracker` 설정 시) |
| 시드 계정 로그인 (`Test1234!`) | ✅ | ❌ (시드 미적용) |
| 인증번호 조회 `/dev/sms/...` | ✅ | ❌ → 백엔드 로그에서 확인 |

---

## 1. 계정

### 로컬 시드 계정 (V900 + V901)

| 계정 | 비밀번호 | 역할 |
|---|---|---|
| `user1@example.com` ~ `user29@example.com` | `Test1234!` | 일반 회원 (회원 1 = 기본 판매자) |
| `admin@example.com` | `Test1234!` | 관리자 (관리자 웹 로그인용, 회원 3) |

시드는 `local` 프로필의 Flyway 위치(`db/seed`)에만 있어 **배포 DB에는 없다.** 배포에서는 회원가입으로 만든다.
관리자 웹은 `http://localhost:3000/admin/` (로컬), `http://<ALB>/admin/` (배포).

### 회원가입 (전화 인증 필수)

1. `POST /api/v1/auth/phone-verifications` `{"phoneNumber":"01012345678","purpose":"SIGN_UP"}` → `verificationId`
   - `purpose`: `SIGN_UP` / `FIND_EMAIL` / `RESET_PASSWORD` / `CHANGE_SENSITIVE`. 빠지면 400.
2. 인증번호 6자리 확인
   - 로컬 Docker Compose: 기본 목업 인증번호 `111111` (`PHONE_VERIFICATION_FIXED_CODE`로 변경 가능). `GET /api/v1/dev/sms/{전화번호}/last-code`에서도 확인할 수 있다.
   - 배포: 문자가 실제로 안 간다. `kubectl logs deploy/dib-backend | Select-String "SMS 발송"` 에서 본다.
3. `POST /api/v1/auth/phone-verifications/{verificationId}/confirm` `{"code":"111111"}` → `verificationToken` (로컬 Docker Compose 기본값)
4. `POST /api/v1/auth/signup` 에 `phoneVerificationToken` 포함. 전화번호는 회원당 유일하다 — 새 계정마다 다른 번호.

`flow_test.py` 는 `010` + 무작위 8자리, 비밀번호 `Dib!Test1234` 로 매 실행 A/B/C 세 계정을 새로 만든다.

---

## 2. 결제 — 토스페이먼츠 테스트 카드

우리 서버 키는 `test_sk_…` (테스트 상점). 형식만 맞으면 어떤 번호든 승인되고 **실제 출금은 없다.**
카드 비밀번호는 빌링키 발급에 쓰지 않는다. 결제·환불(취소) 내역은 토스 개발자센터 테스트 콘솔에 남는다.

| 출처 | 카드번호 | 유효기간 (YY / MM) | 생년월일 (customerIdentityNumber) |
|---|---|---|---|
| `flow_test.py` | `5272891234123414` | `30` / `12` | `950101` |
| Postman 컬렉션 | `4330123412341234` | `30` / `12` | `990101` |

### 카드 등록 경로 — 로컬과 배포가 다르다

**로컬 (지름길)** — 카드번호를 서버에 직접 보낸다. 회원당 카드 1장, 이미 있으면 409 `PAYMENT_METHOD_ALREADY_EXISTS`.

```http
POST /api/v1/dev/members/{memberId}/payment-methods/card
{"cardNumber":"5272891234123414","cardExpirationYear":"30","cardExpirationMonth":"12","customerIdentityNumber":"950101"}
```

**배포 (정식 경로, 로컬에서도 가능)** — 토스 결제창에서 카드를 등록하고 받은 `authKey`·`customerKey` 를 보낸다.

1. `toss-billing-test.html` 을 브라우저로 열고 **테스트 클라이언트 키(`test_ck_…`)** 입력 → 카드 등록 → 위 카드번호 입력
2. 화면에 찍힌 `authKey`, `customerKey` 를 복사 (**authKey 는 몇 분 안에 써야 한다**)
3. `POST /api/v1/members/me/payment-methods` `{"authKey":"…","customerKey":"…"}` (로그인 토큰 필요)

앱에서 결제창을 띄우려면 빌드에 `-PDIB_TOSS_CLIENT_KEY=test_ck_…` 가 들어가야 한다.
배포 Secret 의 `TOSS_SECRET_KEY` 가 `REPLACE-` 로 비어 있으면 낙찰 자동결제가 실패하고 주문은 `PENDING` 으로 남는다.

---

## 3. 정산 계좌

은행 실명 조회 API 가 없다. **형식만 검사**한다. 로컬·배포 동일.

| 필드 | 규칙 | 예 |
|---|---|---|
| `bankName` | 비어 있지 않은 문자열 | `국민은행` |
| `accountNumber` | 숫자·하이픈 8~30자 (`^[0-9-]{8,30}$`) | `123456-78-901234` |
| `accountHolder` | 비어 있지 않은 문자열 | `홍길동` |

```http
PUT /api/v1/members/me/settlement-account
```

휴대폰 재인증은 받지 않는다. 가입 때 본인인증을 마친 계정이라 등록·변경 모두
`phoneVerificationToken` 없이 저장된다. 구버전 앱이 그 필드를 계속 보내도 무시된다.

---

## 4. 배송 — 운송장 번호

서버 환경변수 **`CARRIER_PROVIDER`** 가 무엇인지 먼저 확인한다. 규칙이 완전히 다르다.

### `fake` (기본값 — 환경변수 없으면 이것)

| 택배사 코드 | 운송장 | 결과 |
|---|---|---|
| `CJ` `HANJIN` `LOGEN` `LOTTE` `EPOST` | 숫자 9~14자리, **끝자리 9** | 배송완료 → 이후 구매확정 가능 |
| 같음 | 끝자리 9 아님 (`123456781`) | 배송중 유지 |
| `KDEXP` 등 목록 밖 | — | 400 `UNSUPPORTED_CARRIER` |
| 아무 택배사 | `12-34` 처럼 형식 위반 | 400 `INVALID_TRACKING` |

배포에서 앱으로 시연할 거면 이 모드가 편하다. 앱 택배사 목록의 **CJ대한통운 + `123456789`** 로 바로 배송완료.

### `deliverytracker` (현재 로컬 `.env` 값)

실제 Delivery Tracker API 를 부른다. 실제 택배사 코드에 가짜 번호를 넣으면 `INVALID_TRACKING` 이다.
테스트는 전용 택배사 **`DUMMY`** 로 한다. 앱 택배사 목록에는 숨겨져 있어 Postman 에서만 코드로 넣는다.

| 택배사 코드 | 운송장 형식 | 결과 |
|---|---|---|
| `DUMMY` | `YYYY-MM-DDTHH:00:00Z` (UTC, **3시간 단위 정각**) | 그 시각이 지났으면 배송완료, 미래면 배송중 |

예: 지금이 UTC 10:20 이면 `2026-09-22T09:00:00Z` → 배송완료, `2026-09-22T12:00:00Z` → 배송중.
`flow_test.py --carrier deliverytracker` 가 이 값을 자동으로 만든다. **스크립트의 `--carrier` 와 서버 값이 다르면 배송 단계가 실패한다** (하자가 아니라 설정 불일치).

```http
POST /api/v1/orders/{orderId}/shipment
{"carrier":"CJ","trackingNumber":"123456789"}
```

---

## 5. 로컬에만 있는 지름길 (`/api/v1/dev/**`, `local` 프로필 전용)

| 엔드포인트 | 용도 |
|---|---|
| `POST /dev/members/{id}/payment-methods/card` | 카드번호로 즉시 카드 등록 |
| `GET /dev/sms/{phone}/last-code` | 마지막 인증번호 |
| `POST /dev/auctions/{id}/bids` | 임의 회원으로 입찰 (알림은 안 생김) |
| `POST /dev/auctions/{id}/end` | 경매 강제 종료 (상태만 바꿈, 낙찰 알림은 안 생김) |
| `POST /dev/orders/{id}/expire` | 결제 기한 만료 → 주문 취소 |
| `POST /dev/orders/{id}/auto-confirm` | 자동 구매확정 |
| `GET /dev/members/{id}/notifications` | 회원 알림 목록 |

배포에서는 전부 404 다. 실제 타이머(일반 경매 최소 5분, 라이브 30초~5분)와 백엔드 로그로 대신한다.

---

## 6. 한 번에 돌리기

```bash
# 로컬 스택 (dib-orchestration 에서)
docker compose --profile app up -d

# 10개 시나리오 전체. --carrier 는 서버 .env 의 CARRIER_PROVIDER 와 맞춘다
PYTHONUTF8=1 python flow_test.py --base http://localhost:8080 --seller-id 1 --carrier deliverytracker
```

배포 서버에 돌릴 때는 `--base http://<ALB>` 로 바꾼다. 단 `/dev/**` 를 쓰는 단계는 실패한다 — 스크립트는 로컬 전용이다.
