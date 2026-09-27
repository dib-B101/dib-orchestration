$ErrorActionPreference = "Stop"

chcp 65001 *> $null
[Console]::InputEncoding = [Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding = [Text.UTF8Encoding]::new($false)
$env:PYTHONUTF8 = "1"

$dashboardRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$server = Join-Path $dashboardRoot "server.py"

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw "kubectl을 찾을 수 없습니다."
}

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "Python을 찾을 수 없습니다."
}

python $server @args
