# DIB Live Trace

실제 EKS 배포 환경을 읽기 전용으로 관찰하는 로컬 발표용 대시보드다. AWS에 Grafana나 Prometheus를
추가하지 않는다. `kubectl` 로그와 Metrics API, HPA, Kafka consumer group만 조회한다.

## 실행

```powershell
cd C:\Users\SSAFY\Desktop\dev\dib\dib-orchestration
.\tools\qa-live-dashboard\run.ps1
```

브라우저가 자동으로 `http://127.0.0.1:8765`를 연다. 다른 PC에는 노출되지 않는다.

포트를 바꾸거나 브라우저 자동 실행을 끌 수 있다.

```powershell
.\tools\qa-live-dashboard\run.ps1 --port 8877 --no-browser
```

## 표시 정보

- Backend Pod별 Ready, AZ, CPU, 메모리, 재시작 횟수
- HPA 현재/목표 replica와 CPU
- WebSocket 연결 통계
- Kafka consumer group/topic별 lag
- 경매 종료, 결제, 이상입찰, AI 추천과 상품 검수 이벤트
- Backend/AI 오류 요약

원본 로그 전체를 노출하지 않고 발표에 필요한 이벤트만 파싱한다. 토큰, 비밀번호, 이메일과 전화번호는
표시 전에 마스킹한다. 로그는 저장하지 않고 프로세스 메모리의 최근 240건만 유지한다.

백엔드가 `[DIB-TRACE] stage=... requestId=... durationMs=...` 형식을 출력하면 별도 변경 없이 단계별
타임라인으로 표시한다.
