# Android 거래 화면 개선과 로컬 seed 복구

## 범위와 완료 조건

- Android 로그인 비밀번호 입력의 완료 동작, 사진 재정렬 미리보기 스크롤, 상품 등록 입력 검증을 수정한다.
- 경매 상세의 가격·남은 시간 정렬과 입찰 버튼을 조정하고, 최상위 입찰자의 초록색 강조를 유지한다.
- 내 거래 카드의 정보를 줄별로 표시하고 사진 배지의 스타일·크기·위치를 맞춘다. 최고가 여부에 따라 입찰 가격을 구분한다.
- 비밀번호 입력 후 완료 키는 로그인과 같은 검증·제출 경로를 실행한다. 사진 재정렬 시 미리보기 횡스크롤 인덱스를 유지한다.
- 등록 텍스트 필드에 입력 조건 팝업을 표시하고, 출시연도는 비워두거나 1900~2100년인 경우에만 다음 단계로 진행한다.
- 백엔드 로컬 seed의 참조 오류를 고치고 Docker 개발 DB를 초기화해 프로젝트 seed 전체를 적용한다.
- Android 빌드·관련 테스트, Flyway 성공 이력과 주요 테이블 건수를 확인한다.

## 영향 컴포넌트

- `components/frontend`: Android Compose 화면
- `components/backend`: 로컬 전용 Flyway seed
- `dib-orchestration`: 이 계획만 기록하며 submodule 포인터는 병합 전 갱신하지 않는다.

## 진행 상황

- [x] 현재 UI 및 서버 등록 조건 조사
- [x] 프론트엔드 화면 수정, 빌드 및 사진 순서 관련 단위 테스트 통과
- [x] 경매 상세와 내 거래 화면 수정, Android 빌드 확인
- [x] 로컬 seed 참조 수정과 전체 적용
- [x] DB 건수 및 최종 변경 검증

## 결정 기록

- 사용자가 로컬 Docker DB의 기존 데이터 삭제와 전체 seed 재적용을 승인했다.
- 출시연도는 서버의 1900~2100 제한에 맞춘다.
- 경매 상세의 시작가는 경매 예정 상태에서 주 가격으로 유지하고, 진행 중에는 현재가·남은 시간 카드에서 뺀다.
- 내 거래의 최고가 여부는 해당 경매에서 내가 낸 최고 입찰가와 현재가를 비교한다. 종료·정보 부족 시 중립색을 쓴다.
- 실행 중이던 백엔드 이미지는 작업 트리보다 오래된 seed를 포함해, 현 소스로 다시 빌드한다.
- 최신 seed는 19개 카테고리를 만들지만 일부 상품이 이전 21개 분류 ID를 참조하여 마이그레이션이 중단됐다. 참조를 현재 분류에 맞춘다.

## 검증 결과

- `:app:compileDebugKotlin --offline`: 성공
- `:app:testDebugUnitTest --tests com.ssafy.dib.ProductImageTypeTest --offline`: 성공
- `:app:testDebugUnitTest --tests com.ssafy.dib.ProductDetailStateTest --offline`: 성공
- 수정한 V900 SQL 직접 적용: 성공
- 최신 백엔드 Docker 이미지 빌드 및 Flyway V900/V901 재적용: 성공
- 로컬 DB: 회원 30, 상품 93, 사진 183, 경매 93, 입찰 423, 카테고리 19건
- 백엔드·AI·PostgreSQL 컨테이너 healthy 확인

## 후속 작업

- 컴포넌트 변경을 각각 검토·병합한 뒤 orchestration의 submodule 포인터를 갱신한다.
