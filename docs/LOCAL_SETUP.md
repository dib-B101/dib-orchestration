# 로컬 실행 체크리스트

## 1. 준비

- Docker Desktop 설치 및 실행
- Android Studio 설치
- Android SDK 설치
- JDK 17 설치 또는 Android Studio JBR 사용

## 2. 저장소 받기

```powershell
git clone --recurse-submodules https://github.com/dib-B101/dib-orchestration.git
cd dib-orchestration
git submodule update --init --recursive
```

## 3. 환경변수 설정

```powershell
Copy-Item .env.example .env
```

`.env`에서 다음 값을 설정한다.

```properties
PHONE_VERIFICATION_HMAC_SECRET=<랜덤 문자열>
PHONE_VERIFICATION_FIXED_CODE=111111
DIB_SERVICE_HMAC_SECRET=<랜덤 문자열>
DIB_AI_HMAC_SECRET=<다른 랜덤 문자열>
TOSS_SECRET_KEY=<토스 테스트 시크릿 키>
```

## 4. 서버 실행

```powershell
docker compose --profile app up -d --build
docker compose --profile app ps
```

## 5. Android 로컬 설정

`%USERPROFILE%\.gradle\gradle.properties`에 추가한다.

```properties
DIB_API_BASE_URL=http://10.0.2.2:8080
DIB_WS_URL=ws://10.0.2.2:8080/ws
DIB_TOSS_CLIENT_KEY=<토스 테스트 클라이언트 키>
DIB_SESSION_IDLE_TIMEOUT_MINUTES=30
```

## 6. 앱 실행

1. Android Studio에서 `components/frontend`를 연다.
2. Gradle Sync를 실행한다.
3. Android Emulator를 실행한다.
4. `app` 구성을 실행한다.
5. Android API 37 에뮬레이터에서는 로컬 네트워크 권한을 허용한다.

## 7. `127.0.0.1` 사용 시 디바이스별 설정

```powershell
adb devices
adb -s <디바이스 ID> reverse tcp:8080 tcp:8080
adb -s <디바이스 ID> reverse --list
```

## 8. 종료

```powershell
docker compose down
```

## 9. DB까지 초기화

```powershell
docker compose down -v
docker compose --profile app up -d --build
```
