param(
  [string]$Device = "192.168.1.105:5555",
  [ValidateSet("debug", "release", "profile")]
  [string]$Mode = "release",
  [string]$TargetPlatform = "android-arm64",
  [switch]$SplitPerAbi,
  [switch]$NoVersionBump,
  [switch]$AllowPersonalDevice
)

$ErrorActionPreference = "Stop"

function Resolve-Adb {
  $cmd = Get-Command adb -ErrorAction SilentlyContinue
  if ($cmd) {
    return $cmd.Source
  }
  $fallback = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
  if (Test-Path -LiteralPath $fallback) {
    return $fallback
  }
  throw "adb not found. Add Android SDK platform-tools to PATH."
}

function Get-InstalledVersionCode {
  param([string]$AdbPath, [string]$TargetDevice)
  $dump = & $AdbPath -s $TargetDevice shell dumpsys package com.example.rgb_ble_controller 2>$null
  $line = $dump | Select-String -Pattern "versionCode=(\d+)" | Select-Object -First 1
  if (!$line) {
    return $null
  }
  return [int64]$line.Matches[0].Groups[1].Value
}

function Update-PubspecVersion {
  param([string]$PubspecPath, [Nullable[int64]]$InstalledVersionCode)

  $text = [System.IO.File]::ReadAllText(
    (Resolve-Path -LiteralPath $PubspecPath),
    [System.Text.UTF8Encoding]::new($false)
  )
  $match = [regex]::Match($text, "(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+(\d+)\s*$")
  if (!$match.Success) {
    throw "Unable to find version line in $PubspecPath"
  }

  $versionName = $match.Groups[1].Value
  $currentCode = [int64]$match.Groups[2].Value
  $dateFloor = [int64]((Get-Date -Format "yyyyMMdd") + "01")
  $nextCode = [Math]::Max($currentCode + 1, $dateFloor)
  if ($InstalledVersionCode.HasValue) {
    $nextCode = [Math]::Max($nextCode, $InstalledVersionCode.Value + 1)
  }
  if ($nextCode -gt 2100000000) {
    throw "versionCode $nextCode exceeds Android/Play maximum 2100000000"
  }

  $newLine = "version: $versionName+$nextCode"
  $updated = [regex]::Replace($text, "(?m)^version:\s*[0-9]+\.[0-9]+\.[0-9]+\+\d+\s*$", $newLine)
  if ($updated -ne $text) {
    [System.IO.File]::WriteAllText(
      (Resolve-Path -LiteralPath $PubspecPath),
      $updated,
      [System.Text.UTF8Encoding]::new($false)
    )
  }
  return $nextCode
}

$repoRoot = Resolve-Path "$PSScriptRoot\.."
$appRoot = Join-Path $repoRoot "app"
$pubspec = Join-Path $appRoot "pubspec.yaml"
$personalDevices = @("192.168.1.105:5555", "10AEAF3492000UQ")
$mayReadInstalledVersion = ($Device -notin $personalDevices) -or $AllowPersonalDevice

if (!$NoVersionBump) {
  $installed = $null
  if ($mayReadInstalledVersion) {
    $adb = Resolve-Adb
    $installed = Get-InstalledVersionCode -AdbPath $adb -TargetDevice $Device
  } elseif ($Device -in $personalDevices) {
    Write-Warning "Personal phone testing is disabled for $Device; skipping installed version lookup and bumping from local pubspec/date only."
  }
  $nextCode = Update-PubspecVersion -PubspecPath $pubspec -InstalledVersionCode $installed
  if ($installed) {
    Write-Host "Bumped versionCode to $nextCode (installed: $installed)"
  } else {
    Write-Host "Bumped versionCode to $nextCode"
  }
}

Push-Location $appRoot
try {
  $args = @("build", "apk", "--$Mode")
  if ($SplitPerAbi) {
    $args += "--split-per-abi"
  } elseif ($TargetPlatform) {
    $args += @("--target-platform", $TargetPlatform)
  }
  & flutter @args
  if ($LASTEXITCODE -ne 0) {
    throw "flutter $($args -join ' ') failed with exit code $LASTEXITCODE"
  }
} finally {
  Pop-Location
}
