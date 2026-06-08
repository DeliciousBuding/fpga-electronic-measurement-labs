param(
  [string]$Device = "[REDACTED]:5555",
  [string]$Apk = "$PSScriptRoot\..\app\build\app\outputs\flutter-apk\app-debug.apk",
  [int]$InstallCommitTimeoutSec = 120,
  [int]$AdbEvidenceTimeoutSec = 30,
  [string]$OutDir = "$PSScriptRoot\..\artifacts\install-debug",
  [switch]$CollectInstallEvidence,
  [switch]$Install,
  [switch]$Launch,
  [switch]$Logcat,
  [switch]$AllowPersonalDevice
)

$ErrorActionPreference = "Stop"

$personalDevices = @("[REDACTED]:5555", "[REDACTED]")
if (($Device -in $personalDevices) -and !$AllowPersonalDevice) {
  throw "Personal phone testing is disabled for $Device. Do not run ADB/install/launch/logcat unless the user explicitly re-authorizes it."
}

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

$adb = Resolve-Adb

function Invoke-AdbShellBestEffort {
  param([string]$Command)
  try {
    & $adb -s $Device shell $Command *>$null
  } catch {}
}

function Invoke-AdbTextBestEffort {
  param([string[]]$Arguments)
  try {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $adb
    $psi.Arguments = Join-ProcessArguments -Arguments $Arguments
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    try {
      $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
      $stderrTask = $proc.StandardError.ReadToEndAsync()
      if (!$proc.WaitForExit($AdbEvidenceTimeoutSec * 1000)) {
        try {
          $proc.Kill()
        } catch {}
        throw "adb $($Arguments -join ' ') timed out after ${AdbEvidenceTimeoutSec}s"
      }
      $stdout = $stdoutTask.Result
      $stderr = $stderrTask.Result
      if ($proc.ExitCode -ne 0) {
        throw "adb $($Arguments -join ' ') failed with exit code $($proc.ExitCode): $stderr $stdout"
      }
      return $stdout.TrimEnd()
    } finally {
      $proc.Dispose()
    }
  } catch {
    return "ERROR: $($_.Exception.Message)"
  }
}

function Join-ProcessArguments {
  param([string[]]$Arguments)
  return ($Arguments | ForEach-Object {
      if ($_ -match '[\s"]') {
        '"' + ($_ -replace '"', '\"') + '"'
      } else {
        $_
      }
    }) -join " "
}

function Save-AdbBytesBestEffort {
  param(
    [string[]]$Arguments,
    [string]$Path
  )
  try {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $adb
    $psi.Arguments = Join-ProcessArguments -Arguments $Arguments
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    try {
      $file = [System.IO.File]::Create($Path)
      try {
        $proc.StandardOutput.BaseStream.CopyTo($file)
      } finally {
        $file.Dispose()
      }
      if (!$proc.WaitForExit($AdbEvidenceTimeoutSec * 1000)) {
        try {
          $proc.Kill()
        } catch {}
      }
    } finally {
      $proc.Dispose()
    }
  } catch {}
}

function Write-Utf8File {
  param(
    [string]$Path,
    [string]$Content
  )
  $parent = Split-Path -Parent $Path
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  [System.IO.File]::WriteAllText(
    (Resolve-Path -LiteralPath $parent).Path + "\" + (Split-Path -Leaf $Path),
    $Content,
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Save-InstallEvidence {
  param(
    [string]$Reason,
    [string]$SessionId
  )
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $targetDir = Join-Path ([System.IO.Path]::GetFullPath($OutDir)) $stamp
  New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

  $activity = Invoke-AdbTextBestEffort -Arguments @("-s", $Device, "shell", "dumpsys activity activities | grep -E 'mResumedActivity|topResumedActivity|ResumedActivity'")
  $packageInstaller = Invoke-AdbTextBestEffort -Arguments @("-s", $Device, "logcat", "-d", "-t", "800", "PackageInstaller:*", "PackageManager:*", "PackageManagerService:*", "VivoPermissionManager:*", "*:S")
  $errors = Invoke-AdbTextBestEffort -Arguments @("-s", $Device, "logcat", "-d", "-t", "800", "*:E")
  $package = Invoke-AdbTextBestEffort -Arguments @("-s", $Device, "shell", "dumpsys package com.example.rgb_ble_controller")
  $sessions = Invoke-AdbTextBestEffort -Arguments @("-s", $Device, "shell", "pm list staged-sessions; pm list packages -i | grep rgb_ble_controller")
  $summary = @"
Install evidence
Timestamp: $stamp
Device: $Device
APK: $Apk
Reason: $Reason
Session: $SessionId

Activity:
$activity

Artifacts:
$targetDir
"@

  Write-Utf8File -Path (Join-Path $targetDir "summary.txt") -Content $summary
  Write-Utf8File -Path (Join-Path $targetDir "activity.txt") -Content $activity
  Write-Utf8File -Path (Join-Path $targetDir "package-installer-logcat.txt") -Content $packageInstaller
  Write-Utf8File -Path (Join-Path $targetDir "logcat-errors.txt") -Content $errors
  Write-Utf8File -Path (Join-Path $targetDir "package.txt") -Content $package
  Write-Utf8File -Path (Join-Path $targetDir "sessions.txt") -Content $sessions
  Save-AdbBytesBestEffort -Arguments @("-s", $Device, "exec-out", "screencap", "-p") -Path (Join-Path $targetDir "screen.png")
  Write-Host "Install evidence saved to $targetDir"
}

& $adb -s $Device shell "input keyevent WAKEUP; wm dismiss-keyguard; svc power stayon true; settings put global stay_on_while_plugged_in 7; settings put system screen_off_timeout 1800000" | Out-Null

Write-Host "Device:"
& $adb -s $Device shell "getprop ro.product.model; settings get global stay_on_while_plugged_in; settings get system screen_off_timeout"

if ($CollectInstallEvidence) {
  Save-InstallEvidence -Reason "manual-collect" -SessionId ""
  exit 0
}

if ($Install) {
  if (!(Test-Path -LiteralPath $Apk)) {
    throw "APK not found: $Apk"
  }
  $apkItem = Get-Item -LiteralPath $Apk
  $remoteApk = "/data/local/tmp/rgb-controller-install.apk"
  $sessionId = $null
  $commitJob = $null
  $committed = $false
  Invoke-AdbShellBestEffort "rm -f $remoteApk"
  try {
    Write-Host "Installing $Apk via package-manager session"
    $create = & $adb -s $Device shell "pm install-create -r -t -g -S $($apkItem.Length)"
    Write-Host $create
    if ($create -notmatch "\[(\d+)\]") {
      throw "Unable to create install session: $create"
    }
    $sessionId = $Matches[1]
    & $adb -s $Device push $Apk $remoteApk
    & $adb -s $Device shell "pm install-write -S $($apkItem.Length) $sessionId base.apk $remoteApk"
    $commitJob = Start-Job -ScriptBlock {
      param($AdbPath, $TargetDevice, $InstallSessionId)
      & $AdbPath -s $TargetDevice shell "pm install-commit $InstallSessionId" 2>&1
    } -ArgumentList $adb, $Device, $sessionId
    if (!(Wait-Job $commitJob -Timeout $InstallCommitTimeoutSec)) {
      Stop-Job $commitJob | Out-Null
      Remove-Job $commitJob | Out-Null
      $commitJob = $null
      if ($sessionId) {
        Invoke-AdbShellBestEffort "pm install-abandon $sessionId"
      }
      Save-InstallEvidence -Reason "install-commit-timeout" -SessionId $sessionId
      throw "Install commit timed out after ${InstallCommitTimeoutSec}s; abandoned session $sessionId"
    }
    $commitOutput = Receive-Job $commitJob
    Remove-Job $commitJob | Out-Null
    $commitJob = $null
    Write-Host $commitOutput
    if ($commitOutput -match "Failure|Exception|Error") {
      if ($commitOutput -match "INSTALL_FAILED_ABORTED|User rejected permissions") {
        Save-InstallEvidence -Reason "install-commit-aborted" -SessionId $sessionId
        throw "Install commit failed because the phone rejected the install permission prompt. Unlock the vivo device and allow the package install confirmation, then rerun this command. Raw output: $commitOutput"
      }
      Save-InstallEvidence -Reason "install-commit-failure" -SessionId $sessionId
      throw "Install commit failed: $commitOutput"
    }
    $committed = $true
  } finally {
    if ($commitJob) {
      Stop-Job $commitJob -ErrorAction SilentlyContinue | Out-Null
      Remove-Job $commitJob -ErrorAction SilentlyContinue | Out-Null
    }
    if ($sessionId -and !$committed) {
      Invoke-AdbShellBestEffort "pm install-abandon $sessionId"
    }
    Invoke-AdbShellBestEffort "rm -f $remoteApk"
  }
}

if ($Launch) {
  & $adb -s $Device shell am start -n com.example.rgb_ble_controller/.MainActivity
}

if ($Logcat) {
  & $adb -s $Device logcat -d "*:S" "flutter:I" "RGB_BLE:I"
}
