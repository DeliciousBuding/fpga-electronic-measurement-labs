param(
  [int]$Port = 7357,
  [switch]$Restart,
  [switch]$Stop,
  [switch]$Status
)

$ErrorActionPreference = "Stop"

function Get-Listener {
  param([int]$TargetPort)
  Get-NetTCPConnection -LocalPort $TargetPort -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1
}

function Resolve-Flutter {
  $cmd = Get-Command flutter -ErrorAction SilentlyContinue
  if ($cmd) {
    return $cmd.Source
  }
  $fallback = "D:\Code\Tools\flutter\bin\flutter.bat"
  if (Test-Path -LiteralPath $fallback) {
    return $fallback
  }
  throw "flutter not found. Add Flutter to PATH or install it at $fallback."
}

function Test-WebConfigured {
  param([string]$FlutterAppRoot)
  return (Test-Path -LiteralPath (Join-Path $FlutterAppRoot "web"))
}

$repoRoot = Resolve-Path "$PSScriptRoot\.."
$appRoot = Join-Path $repoRoot "app"
$webConfigured = Test-WebConfigured -FlutterAppRoot $appRoot
$listener = Get-Listener -TargetPort $Port

if ($Status) {
  if ($listener) {
    $proc = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
    Write-Host "Web preview listening on http://127.0.0.1:$Port (pid=$($listener.OwningProcess), process=$($proc.ProcessName))"
  } else {
    Write-Host "Web preview is not listening on port $Port"
  }
  if (!$webConfigured) {
    Write-Warning "Flutter app is not configured for web: missing $appRoot\web. Use flutter create . --platforms web only after deciding to add web platform files."
  }
  exit 0
}

if (!$webConfigured -and !$Stop) {
  throw "Flutter app is not configured for web: missing $appRoot\web. Refusing to start web preview until web platform files are intentionally added."
}

if (($Restart -or $Stop) -and $listener) {
  Write-Host "Stopping existing listener on port $Port (pid=$($listener.OwningProcess))"
  Stop-Process -Id $listener.OwningProcess -Force
  Start-Sleep -Milliseconds 500
}

if ($Stop) {
  Write-Host "Web preview stopped"
  exit 0
}

$listener = Get-Listener -TargetPort $Port
if ($listener) {
  Write-Host "Web preview already running: http://127.0.0.1:$Port (pid=$($listener.OwningProcess))"
  exit 0
}

$flutter = Resolve-Flutter
$args = @(
  "run",
  "-d",
  "web-server",
  "--web-hostname",
  "127.0.0.1",
  "--web-port",
  "$Port"
)

$process = Start-Process `
  -FilePath $flutter `
  -ArgumentList $args `
  -WorkingDirectory $appRoot `
  -WindowStyle Hidden `
  -PassThru

Write-Host "Started Flutter web preview pid=$($process.Id)"
Write-Host "Open http://127.0.0.1:$Port"
