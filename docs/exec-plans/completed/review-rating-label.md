# 거래 평가 선택 별점 표시

상태: 구현 및 자동 검증 완료
일자: 2026-09-25

## 범위와 완료 조건

- 구매자가 평가에서 0~5점을 고르면 현재 점수가 안내 문구와 제출 버튼에 일치하게 표시된다.
- 별 다섯 개를 눌렀을 때 `0점 주기`가 현재 평가처럼 보이지 않는다. 0점 선택은 계속 가능하다.

## 조사와 결정

- 기존 다이얼로그의 `0점 주기` 문구는 선택 별점과 무관하게 항상 표시됐다.
- 0점 선택 동작을 명확한 별도 버튼으로 두고, 현재 선택 점수를 `N점 선택됨`과 `N점 평가 보내기`로 표시한다. 선택 전에는 제출을 비활성화한다.

## 변경 및 검증

- Frontend [PR #233](https://github.com/dib-B101/dib-frontend/pull/233) `develop` 병합 커밋: `0ddfbef5deef47f971535fa4ec59f4d9c9f51321`.
- `:app:testDebugUnitTest :app:lintDebug :app:assembleDebug --offline` 통과.
- `git submodule status --recursive`와 `git diff --submodule=log`로 frontend 포인터 변경 범위를 확인했다.
- 실제 기기의 수동 UI 확인은 수행하지 않았다.
