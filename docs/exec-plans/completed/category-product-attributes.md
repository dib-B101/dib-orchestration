# 카테고리별 상품 상세 정보

## 범위와 완료 조건

- 상품 등록·수정에서 카테고리별로 적절한 입력 명칭과 항목을 표시한다.
- 구매 연도는 공통 선택 항목으로 제공한다. 일반 카테고리 속성은 선택 항목이다.
- 티켓·교환권·e쿠폰은 유효기간과 미사용 여부, 식품·건강기능식품은 소비기한과 미개봉 여부를 필수로 확인한다.
- 백엔드는 카테고리와 값의 조합을 검증하고 상품 상세 조회에 저장한 정보를 반환한다.
- 기존 상품의 모델명·출시연도와 일반 카테고리의 기존 클라이언트 요청은 계속 처리한다. 안전 정보가 필요한 티켓·식품은 신규 등록 시 필수 정보를 요구한다.
- 관련 백엔드·Android 검증을 수행하고 변경 사항을 해당 컴포넌트에 기록한다.

## 영향 범위

- Backend: 상품 저장 스키마, 입력 검증, 상세 조회, 카테고리 메타데이터
- Frontend: 상품 등록·수정·상세 화면과 API 계약
- Orchestration: 이 실행 계획과 컴포넌트 버전

## 결정 기록

- 공통 필드는 관계형 컬럼으로 유지하고 카테고리별 필드는 JSONB에 저장한다. 기존 컬럼은 호환성을 위해 보존한다.
- 카테고리별 입력 정의는 서버가 제공해 앱과 검증 규칙이 같은 기준을 사용하게 한다.
- 상품의 구매 연도와 출시 연도는 의미가 달라 별도 항목으로 둔다.

## 진행 상황

- [x] 현재 상품 API·화면·스키마 확인
- [x] 서버 스키마·검증·API 구현
- [x] Android 동적 입력·상세 표시 구현
- [x] 검증 및 문서 정리
- [x] 컴포넌트 병합과 통합 버전 갱신

## 검증 결과

- Backend: `ProductAttributeCatalogTest`와 Testcontainers에서 V19 적용·상품 수정·JSONB 저장·상세 조회 테스트 통과.
- Android: `CategoryProductFieldsTest`, `ProductContractTest`, 기존 payload 호환성 테스트 통과.
- Backend·Frontend·Orchestration의 `git diff --check` 통과.
- Backend PR #62는 `0b2034a`로, Frontend PR #240은 `52069d9`로 squash 병합됨. 통합 저장소 포인터를 두 병합 커밋으로 갱신하고 `git submodule status --recursive`로 확인함.

## 결과와 후속 작업

- Backend PR: https://github.com/dib-B101/dib-backend/pull/62
- Frontend PR: https://github.com/dib-B101/dib-frontend/pull/240
- Backend 병합 커밋: `0b2034a`; Frontend 병합 커밋: `52069d9`.
- 남은 후속 작업 없음.

## 2026-09-27 카테고리명 정합성 수정

- 로컬 백엔드 컨테이너가 이전 버전이라 `GET /api/v1/categories`에서 `attributeSpecs`를 반환하지 않았고, 앱의 등록 화면에 동적 입력란이 나타나지 않았다.
- 현재 DB의 19개 카테고리명 중 기존 카탈로그와 이름이 다른 분류를 매핑하고, `예술·창작` 입력 항목을 추가했다. Backend PR #63을 `63d8f7b`로 병합하고 통합 저장소의 backend 포인터를 해당 커밋으로 갱신했다.
- Backend `ProductAttributeCatalogTest` 통과. Firebase 로컬 설정을 유지한 채 Docker 백엔드를 재빌드한 뒤 카테고리 19개 모두 `attributeSpecs`가 있는지 확인했다. Android 에뮬레이터에서 디지털기기 → 예술·창작 변경 시 입력란이 브랜드·모델명·출시연도에서 작가·제작자·재료·기법·크기로 바뀌는 것을 확인했다.

## 2026-09-27 입력 라벨과 예시 텍스트 통일

- Frontend PR #241 (`92fbd97`)과 #242 (`417f305`)를 병합하고 통합 저장소의 frontend 포인터를 최종 커밋으로 갱신했다. 상품 등록·수정에서 선택 항목의 `(선택)`을 제거하고 필수 항목에만 `*`를 표시한다. 카테고리별 플레이스홀더는 공통 입력란과 같은 글꼴 크기·색을 사용한다.
- Android `:app:compileDebugKotlin`, `:app:assembleDebug` 통과. 에뮬레이터 상품 등록 화면에서 디지털기기 입력란과 공통 구매 연도의 라벨·플레이스홀더를 확인했다.
