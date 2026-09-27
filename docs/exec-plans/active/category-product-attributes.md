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
- [ ] 컴포넌트 병합과 통합 버전 갱신

## 검증 결과

- Backend: `ProductAttributeCatalogTest` 통과. Testcontainers에서 V19 적용 후 상품 수정·JSONB 저장·상세 조회 통과.
- Android: `CategoryProductFieldsTest`, `ProductContractTest`, 기존 payload 호환성 테스트 통과.
- 최종 변경분으로 Backend `ProductAttributeCatalogTest`와 Testcontainers 상품 저장·조회 테스트 통과.
- 최종 변경분으로 Android `CategoryProductFieldsTest`와 `ProductContractTest` 통과.
- Backend·Frontend·Orchestration의 `git diff --check` 통과.

## 미해결 사항

- Backend PR: https://github.com/dib-B101/dib-backend/pull/62
- Frontend PR: https://github.com/dib-B101/dib-frontend/pull/240
- 검증한 컴포넌트 기능 커밋: Backend `92996f8`, Frontend `8ac3d41`.
- 컴포넌트 PR 병합 뒤 통합 저장소 submodule 포인터를 병합 커밋으로 갱신해야 한다.
