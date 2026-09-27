[CmdletBinding()]
param(
    [string]$ApiBaseUrl,
    [string]$WebSocketUrl,
    [string]$KakaoRedirectUri,
    [string]$Namespace = "default",
    [string]$IngressName = "dib-ingress",
    [string]$BackendDeployment = "dib-backend",
    [string]$BackendContainer = "app",
    [string]$BackendImage,
    [ValidatePattern('^\d+$')]
    [string]$RequiredMigrationVersion = "901",
    [string]$ApkOutput,
    [switch]$SkipAndroidBuild,
    [switch]$SkipGitCleanCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Require-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "필수 명령을 찾을 수 없습니다: $Name"
    }
}

function Assert-Success([string]$Operation) {
    if ($LASTEXITCODE -ne 0) {
        throw "$Operation 실패 (exit=$LASTEXITCODE)"
    }
}

function Restore-EnvironmentVariable([string]$Name, [AllowNull()][string]$Value) {
    if ($null -eq $Value) {
        Remove-Item "Env:$Name" -ErrorAction SilentlyContinue
    } else {
        Set-Item "Env:$Name" $Value
    }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$frontendRoot = Join-Path $repoRoot "components\frontend"
$gradleWrapper = Join-Path $frontendRoot "gradlew.bat"
$apkSource = Join-Path $frontendRoot "app\build\outputs\apk\debug\app-debug.apk"
$buildConfig = Join-Path $frontendRoot "app\build\generated\source\buildConfig\debug\com\ssafy\dib\BuildConfig.java"
$mergedManifest = Join-Path $frontendRoot "app\build\intermediates\merged_manifests\debug\processDebugManifest\AndroidManifest.xml"

Require-Command "git"
Require-Command "kubectl"
Require-Command "rg"

if (-not (Test-Path $gradleWrapper)) {
    throw "Gradle wrapper를 찾을 수 없습니다: $gradleWrapper"
}

Write-Step "Git 및 Kubernetes 대상 확인"
if (-not $SkipGitCleanCheck) {
    $dirty = @(git -C $repoRoot status --porcelain)
    Assert-Success "git status"
    if ($dirty.Count -gt 0) {
        throw "작업 트리가 깨끗하지 않습니다. 커밋/정리 후 다시 실행하세요. 긴급 검증만 할 때만 -SkipGitCleanCheck를 사용합니다.`n$($dirty -join "`n")"
    }
}

$context = (& kubectl config current-context).Trim()
Assert-Success "kubectl context 확인"
if ([string]::IsNullOrWhiteSpace($context)) {
    throw "활성 Kubernetes context가 없습니다."
}
Write-Host "Kubernetes context: $context"

if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    $albHost = (& kubectl get ingress $IngressName -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].hostname}').Trim()
    Assert-Success "Ingress 주소 조회"
    if ([string]::IsNullOrWhiteSpace($albHost)) {
        throw "Ingress에 ALB hostname이 없습니다: $Namespace/$IngressName"
    }
    $ApiBaseUrl = "http://$albHost"
}
$ApiBaseUrl = $ApiBaseUrl.TrimEnd('/')

$apiUri = $null
if (-not [Uri]::TryCreate($ApiBaseUrl, [UriKind]::Absolute, [ref]$apiUri)) {
    throw "유효하지 않은 API URL입니다: $ApiBaseUrl"
}
if ($apiUri.Scheme -notin @("http", "https")) {
    throw "API URL scheme은 http 또는 https여야 합니다: $ApiBaseUrl"
}
if ($apiUri.Host -match '^(localhost|127\.0\.0\.1|10\.0\.2\.2|0\.0\.0\.0)$') {
    throw "배포 APK에 로컬 API 주소를 사용할 수 없습니다: $ApiBaseUrl"
}
if ($apiUri.AbsolutePath -notin @("", "/")) {
    throw "API URL에는 경로를 넣지 마세요: $ApiBaseUrl"
}

if ([string]::IsNullOrWhiteSpace($WebSocketUrl)) {
    $wsScheme = if ($apiUri.Scheme -eq "https") { "wss" } else { "ws" }
    $WebSocketUrl = "${wsScheme}://$($apiUri.Authority)/ws"
}
$WebSocketUrl = $WebSocketUrl.TrimEnd('/')

$wsUri = $null
if (-not [Uri]::TryCreate($WebSocketUrl, [UriKind]::Absolute, [ref]$wsUri)) {
    throw "유효하지 않은 WebSocket URL입니다: $WebSocketUrl"
}
if ($wsUri.Scheme -notin @("ws", "wss") -or $wsUri.Host -ne $apiUri.Host -or $wsUri.AbsolutePath -ne "/ws") {
    throw "WebSocket URL은 API와 같은 호스트의 /ws여야 합니다: $WebSocketUrl"
}

Write-Host "API: $ApiBaseUrl"
Write-Host "WebSocket: $WebSocketUrl"

if (-not [string]::IsNullOrWhiteSpace($BackendImage)) {
    if ($BackendImage -match ':latest$') {
        throw "재현 가능한 배포를 위해 :latest 태그는 금지합니다. Git SHA 태그 이미지를 사용하세요."
    }
    Write-Step "불변 이미지로 백엔드 롤아웃"
    & kubectl set image "deployment/$BackendDeployment" "${BackendContainer}=$BackendImage" -n $Namespace
    Assert-Success "백엔드 이미지 변경"
    & kubectl rollout status "deployment/$BackendDeployment" -n $Namespace --timeout=300s
    Assert-Success "백엔드 롤아웃"
}

Write-Step "백엔드 Pod, 이미지 digest, Flyway V$RequiredMigrationVersion 확인"
$deployment = & kubectl get deployment $BackendDeployment -n $Namespace -o json | ConvertFrom-Json
Assert-Success "Deployment 조회"
if ($deployment.status.readyReplicas -ne $deployment.spec.replicas -or $deployment.status.availableReplicas -ne $deployment.spec.replicas) {
    throw "백엔드가 Ready 상태가 아닙니다: ready=$($deployment.status.readyReplicas), desired=$($deployment.spec.replicas)"
}

$podsResult = & kubectl get pods -n $Namespace -l "app=$BackendDeployment" -o json | ConvertFrom-Json
Assert-Success "Pod 조회"
$pods = @($podsResult.items)
if ($pods.Count -eq 0) {
    throw "백엔드 Pod를 찾을 수 없습니다."
}

$imageIds = @()
$migrationConfirmed = $false
foreach ($pod in $pods) {
    $status = @($pod.status.containerStatuses | Where-Object { $_.name -eq $BackendContainer })[0]
    if ($null -eq $status -or -not $status.ready -or $status.restartCount -ne 0) {
        throw "Pod 상태가 비정상입니다: $($pod.metadata.name), ready=$($status.ready), restarts=$($status.restartCount)"
    }
    if (-not [string]::IsNullOrWhiteSpace($BackendImage) -and $pod.spec.containers[0].image -ne $BackendImage) {
        throw "Pod 이미지가 요청한 이미지와 다릅니다: $($pod.spec.containers[0].image)"
    }
    $imageIds += $status.imageID
    $logs = (& kubectl logs $pod.metadata.name -n $Namespace) -join "`n"
    if ($logs -match "Current version of schema .*: $RequiredMigrationVersion" -or
        $logs -match "now at version v$RequiredMigrationVersion") {
        $migrationConfirmed = $true
    }
    if ($logs -match '(?m)^\d{4}-\d{2}-\d{2}T\S+\s+ERROR\s') {
        Write-Warning "Pod 로그에 ERROR/FAILED가 있습니다. 배포 승인 전에 직접 검토하세요: $($pod.metadata.name)"
    }
}
if (-not $migrationConfirmed) {
    throw "Pod 시작 로그에서 Flyway V$RequiredMigrationVersion 적용을 확인하지 못했습니다."
}
if (@($imageIds | Sort-Object -Unique).Count -ne 1) {
    throw "Pod들이 서로 다른 이미지 digest를 사용합니다: $($imageIds -join ', ')"
}

Write-Step "외부 API 및 V$RequiredMigrationVersion QA 시드 확인"
$health = Invoke-RestMethod -Method Get -Uri "$ApiBaseUrl/actuator/health" -TimeoutSec 20
if ($health.status -ne "UP") {
    throw "백엔드 health가 UP이 아닙니다: $($health.status)"
}
$recommendation = Invoke-WebRequest -Method Get -Uri "$ApiBaseUrl/api/v1/auctions/recommendation?size=1" -TimeoutSec 20
if ($recommendation.StatusCode -ne 200) {
    throw "추천 API smoke test 실패: HTTP $($recommendation.StatusCode)"
}
$seedLoginBody = @{
    email = "qa.seller1@dib.test"
    password = "Test1234!"
    deviceId = "qa-release-harness"
} | ConvertTo-Json
$seedLogin = Invoke-RestMethod -Method Post -Uri "$ApiBaseUrl/api/v1/auth/login" -ContentType "application/json" -Body $seedLoginBody -TimeoutSec 20
if ([string]::IsNullOrWhiteSpace($seedLogin.accessToken)) {
    throw "V$RequiredMigrationVersion QA 시드 계정 로그인이 실패했습니다."
}

$apkHash = $null
if (-not $SkipAndroidBuild) {
    Write-Step "Kubernetes Secret에서 공개 카카오 설정을 읽어 배포 APK 빌드"
    $kakaoKeyEncoded = (& kubectl get secret dib-secrets -n $Namespace -o jsonpath='{.data.KAKAO_CLIENT_ID}').Trim()
    Assert-Success "KAKAO_CLIENT_ID 조회"
    if ([string]::IsNullOrWhiteSpace($kakaoKeyEncoded)) {
        throw "dib-secrets에 KAKAO_CLIENT_ID가 없습니다."
    }
    $kakaoRestApiKey = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($kakaoKeyEncoded))

    if ([string]::IsNullOrWhiteSpace($KakaoRedirectUri)) {
        $redirectEncoded = (& kubectl get secret dib-secrets -n $Namespace -o jsonpath='{.data.KAKAO_REDIRECT_URIS}').Trim()
        Assert-Success "KAKAO_REDIRECT_URIS 조회"
        if ([string]::IsNullOrWhiteSpace($redirectEncoded)) {
            throw "dib-secrets에 KAKAO_REDIRECT_URIS가 없습니다."
        }
        $redirectList = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($redirectEncoded))
        $KakaoRedirectUri = @($redirectList -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })[0]
    }
    if (-not $KakaoRedirectUri.StartsWith("https://")) {
        throw "카카오 Redirect URI는 https여야 합니다: $KakaoRedirectUri"
    }

    $gradleEnvironmentNames = @(
        "ORG_GRADLE_PROJECT_DIB_API_BASE_URL",
        "ORG_GRADLE_PROJECT_DIB_WS_URL",
        "ORG_GRADLE_PROJECT_DIB_KAKAO_REST_API_KEY",
        "ORG_GRADLE_PROJECT_DIB_KAKAO_REDIRECT_URI"
    )
    $previousEnvironment = @{}
    foreach ($name in $gradleEnvironmentNames) {
        $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
    }

    try {
        $env:ORG_GRADLE_PROJECT_DIB_API_BASE_URL = $ApiBaseUrl
        $env:ORG_GRADLE_PROJECT_DIB_WS_URL = $WebSocketUrl
        $env:ORG_GRADLE_PROJECT_DIB_KAKAO_REST_API_KEY = $kakaoRestApiKey
        $env:ORG_GRADLE_PROJECT_DIB_KAKAO_REDIRECT_URI = $KakaoRedirectUri
        Push-Location $frontendRoot
        try {
            & $gradleWrapper clean :app:assembleDebug
            Assert-Success "Android 배포 APK 빌드"
        } finally {
            Pop-Location
        }
    } finally {
        foreach ($name in $gradleEnvironmentNames) {
            Restore-EnvironmentVariable $name $previousEnvironment[$name]
        }
        $kakaoRestApiKey = $null
    }

    if (-not (Test-Path $apkSource) -or -not (Test-Path $buildConfig)) {
        throw "APK 또는 BuildConfig 산출물이 없습니다."
    }
    $buildConfigText = Get-Content $buildConfig -Raw
    if ($buildConfigText -notmatch [regex]::Escape("API_BASE_URL = `"$ApiBaseUrl`"") -or
        $buildConfigText -notmatch [regex]::Escape("WEB_SOCKET_URL = `"$WebSocketUrl`"")) {
        throw "생성된 BuildConfig의 API/소켓 주소가 요청한 배포 주소와 다릅니다."
    }
    if ($buildConfigText -match 'API_BASE_URL = "https?://(localhost|127\.0\.0\.1|10\.0\.2\.2|0\.0\.0\.0)') {
        throw "생성된 BuildConfig에 로컬 API 주소가 들어갔습니다."
    }
    $mergedManifestText = Get-Content $mergedManifest -Raw
    if ($apiUri.Scheme -eq "http" -and $mergedManifestText -notmatch 'usesCleartextTraffic="true"') {
        throw "HTTP ALB를 사용하는데 debug APK merged manifest가 cleartext를 허용하지 않습니다."
    }

    if ([string]::IsNullOrWhiteSpace($ApkOutput)) {
        $artifactDirectory = Join-Path (Split-Path $repoRoot -Parent) "deploy-check"
        $ApkOutput = Join-Path $artifactDirectory ("dib-app-{0}-aws.apk" -f (Get-Date -Format "yyyyMMdd-HHmm"))
    }
    $apkDirectory = Split-Path $ApkOutput -Parent
    New-Item -ItemType Directory -Path $apkDirectory -Force | Out-Null
    Copy-Item -LiteralPath $apkSource -Destination $ApkOutput -Force

    Write-Step "APK 바이너리에 배포 호스트가 실제 포함됐는지 확인"
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $extractDirectory = Join-Path $tempRoot ("dib-release-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $extractDirectory | Out-Null
    try {
        Expand-Archive -LiteralPath $ApkOutput -DestinationPath $extractDirectory
        $dexFiles = @(Get-ChildItem $extractDirectory -Filter "classes*.dex")
        if ($dexFiles.Count -eq 0) {
            throw "APK에서 DEX 파일을 찾지 못했습니다."
        }
        & rg -a -l -F $ApiBaseUrl @($dexFiles.FullName) | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "APK DEX에서 배포 API 주소를 찾지 못했습니다: $ApiBaseUrl"
        }
        & rg -a -l -F $WebSocketUrl @($dexFiles.FullName) | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "APK DEX에서 배포 WebSocket 주소를 찾지 못했습니다: $WebSocketUrl"
        }
    } finally {
        $resolvedExtract = [IO.Path]::GetFullPath($extractDirectory)
        if ($resolvedExtract.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
            (Split-Path $resolvedExtract -Leaf).StartsWith("dib-release-")) {
            Remove-Item -LiteralPath $resolvedExtract -Recurse -Force
        }
    }
    $apkHash = (Get-FileHash -LiteralPath $ApkOutput -Algorithm SHA256).Hash
}

Write-Step "검증 증적 저장"
$backendCommit = (& git -C (Join-Path $repoRoot "components\backend") rev-parse HEAD).Trim()
$frontendCommit = (& git -C $frontendRoot rev-parse HEAD).Trim()
$evidence = [ordered]@{
    verifiedAt = (Get-Date).ToString("o")
    kubernetesContext = $context
    namespace = $Namespace
    backendDeployment = $BackendDeployment
    backendImage = $deployment.spec.template.spec.containers[0].image
    backendImageDigest = @($imageIds | Sort-Object -Unique)[0]
    backendCommit = $backendCommit
    frontendCommit = $frontendCommit
    flywayVersion = $RequiredMigrationVersion
    health = $health.status
    apiBaseUrl = $ApiBaseUrl
    webSocketUrl = $WebSocketUrl
    apkPath = $ApkOutput
    apkSha256 = $apkHash
}
$evidencePath = if ($SkipAndroidBuild) {
    Join-Path (Split-Path $repoRoot -Parent) "deploy-check\backend-release-evidence.json"
} else {
    "$ApkOutput.manifest.json"
}
New-Item -ItemType Directory -Path (Split-Path $evidencePath -Parent) -Force | Out-Null
$evidence | ConvertTo-Json | Set-Content -LiteralPath $evidencePath -Encoding utf8

Write-Host "`n배포 하네스 통과" -ForegroundColor Green
Write-Host "Backend: $($evidence.backendImage)"
Write-Host "Digest: $($evidence.backendImageDigest)"
Write-Host "Flyway: V$RequiredMigrationVersion"
Write-Host "Health: $($health.status)"
if (-not $SkipAndroidBuild) {
    Write-Host "APK: $ApkOutput"
    Write-Host "SHA256: $apkHash"
}
Write-Host "Evidence: $evidencePath"
