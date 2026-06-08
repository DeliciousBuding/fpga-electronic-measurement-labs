param(
  [string]$Device = "[REDACTED]:5555",
  [string]$Package = "com.example.rgb_ble_controller",
  [string]$Activity = ".MainActivity",
  [string]$OutDir = "$PSScriptRoot\..\artifacts\device-smoke",
  [switch]$NoLaunch,
  [switch]$NoScreenshot,
  [switch]$RequireCurrentVersion,
  [int]$PostLaunchDelaySec = 3,
  [int]$LogcatTail = 1200,
  [int]$AdbTimeoutSec = 30,
  [switch]$AllowPersonalDevice
)

$ErrorActionPreference = "Stop"

$personalDevices = @("[REDACTED]:5555", "[REDACTED]")
if (($Device -in $personalDevices) -and !$AllowPersonalDevice) {
  throw "Personal phone testing is disabled for $Device. Do not run ADB/device smoke unless the user explicitly re-authorizes it."
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

function Invoke-AdbText {
  param([string[]]$Arguments)

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
    if (!$proc.WaitForExit($AdbTimeoutSec * 1000)) {
      try {
        $proc.Kill()
      } catch {}
      throw "adb $($Arguments -join ' ') timed out after ${AdbTimeoutSec}s"
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
}

function Invoke-AdbTextBestEffort {
  param([string[]]$Arguments)
  try {
    return Invoke-AdbText -Arguments $Arguments
  } catch {
    return "ERROR: $($_.Exception.Message)"
  }
}

function Save-AdbBytes {
  param(
    [string[]]$Arguments,
    [string]$Path
  )

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
    $stderr = $proc.StandardError.ReadToEnd()
    if (!$proc.WaitForExit($AdbTimeoutSec * 1000)) {
      try {
        $proc.Kill()
      } catch {}
      throw "adb $($Arguments -join ' ') timed out after ${AdbTimeoutSec}s"
    }
    if ($proc.ExitCode -ne 0) {
      throw "adb $($Arguments -join ' ') failed with exit code $($proc.ExitCode): $stderr"
    }
  } finally {
    $proc.Dispose()
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

function Write-Utf8File {
  param(
    [string]$Path,
    [string]$Content
  )
  [System.IO.File]::WriteAllText(
    (Resolve-Path -LiteralPath (Split-Path -Parent $Path)).Path + "\" + (Split-Path -Leaf $Path),
    $Content,
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Get-ResumedActivity {
  return Invoke-AdbTextBestEffort -Arguments @(
    "-s",
    $Device,
    "shell",
    "dumpsys activity activities | grep -E 'mResumedActivity|topResumedActivity|ResumedActivity'"
  )
}

function Get-PowerWindowStatus {
  $power = Invoke-AdbTextBestEffort -Arguments @(
    "-s",
    $Device,
    "shell",
    "dumpsys power | grep -E 'mWakefulness|mStayOn|mScreenOn|Display Power'"
  )
  $window = Invoke-AdbTextBestEffort -Arguments @(
    "-s",
    $Device,
    "shell",
    "dumpsys window | grep -E 'mCurrentFocus|mFocusedApp|mDreamingLockscreen|mScreenOn|mAwake'"
  )
  return [pscustomobject]@{
    Power = $power
    Window = $window
    Text = "Power:" + [Environment]::NewLine + $power + [Environment]::NewLine + [Environment]::NewLine + "Window:" + [Environment]::NewLine + $window
  }
}

$adb = Resolve-Adb
$repoRoot = Resolve-Path "$PSScriptRoot\.."
$pubspec = Join-Path $repoRoot "app\pubspec.yaml"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outRoot = [System.IO.Path]::GetFullPath($OutDir)

$devices = Invoke-AdbText -Arguments @("devices", "-l")
if ($devices -notmatch [regex]::Escape($Device) + "\s+device") {
  if ($Device -match "^\d{1,3}(\.\d{1,3}){3}:\d+$") {
    [void](Invoke-AdbTextBestEffort -Arguments @("disconnect", $Device))
    [void](Invoke-AdbTextBestEffort -Arguments @("connect", $Device))
    $devices = Invoke-AdbText -Arguments @("devices", "-l")
  }
}
if ($devices -notmatch [regex]::Escape($Device) + "\s+device") {
  throw "Target device $Device is not online. Current devices:`n$devices"
}

$targetDir = Join-Path $outRoot $timestamp
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
Write-Host "Writing device smoke artifacts to $targetDir"

$wakeCommand = "input keyevent WAKEUP; wm dismiss-keyguard; svc power stayon true; settings put global stay_on_while_plugged_in 7; settings put system screen_off_timeout 1800000"
[void](Invoke-AdbTextBestEffort -Arguments @("-s", $Device, "shell", $wakeCommand))

if (!$NoLaunch) {
  [void](Invoke-AdbTextBestEffort -Arguments @("-s", $Device, "shell", "am force-stop $Package"))
  $launch = Invoke-AdbTextBestEffort -Arguments @(
    "-s",
    $Device,
    "shell",
    "am start -n $Package/$Activity"
  )
  Start-Sleep -Seconds $PostLaunchDelaySec
  $activityInfo = Get-ResumedActivity
  if ($activityInfo -notmatch [regex]::Escape($Package)) {
    $fallbackLaunch = Invoke-AdbTextBestEffort -Arguments @(
      "-s",
      $Device,
      "shell",
      "monkey -p $Package -c android.intent.category.LAUNCHER 1"
    )
    Start-Sleep -Seconds $PostLaunchDelaySec
    $activityInfo = Get-ResumedActivity
    $launch = $launch + [Environment]::NewLine + "Fallback launcher:" + [Environment]::NewLine + $fallbackLaunch
  }
} else {
  $launch = "Launch skipped by -NoLaunch."
  $activityInfo = Get-ResumedActivity
}

$powerWindowStatus = Get-PowerWindowStatus

$deviceInfo = Invoke-AdbTextBestEffort -Arguments @(
  "-s",
  $Device,
  "shell",
  "getprop ro.product.model; getprop ro.product.manufacturer; getprop ro.build.version.release; getprop ro.build.version.sdk; settings get global stay_on_while_plugged_in; settings get system screen_off_timeout"
)
$packageInfo = Invoke-AdbTextBestEffort -Arguments @("-s", $Device, "shell", "dumpsys package $Package")
$bluetoothInfo = Invoke-AdbTextBestEffort -Arguments @("-s", $Device, "shell", "dumpsys bluetooth_manager")
$crashLog = Invoke-AdbTextBestEffort -Arguments @("-s", $Device, "logcat", "-d", "-t", "$LogcatTail", "*:E")
$flutterLog = Invoke-AdbTextBestEffort -Arguments @("-s", $Device, "logcat", "-d", "-t", "$LogcatTail", "flutter:I", "RGB_BLE:I", "*:S")

Write-Utf8File -Path (Join-Path $targetDir "devices.txt") -Content $devices
Write-Utf8File -Path (Join-Path $targetDir "device-info.txt") -Content $deviceInfo
Write-Utf8File -Path (Join-Path $targetDir "package.txt") -Content $packageInfo
Write-Utf8File -Path (Join-Path $targetDir "activity.txt") -Content $activityInfo
Write-Utf8File -Path (Join-Path $targetDir "power-window.txt") -Content $powerWindowStatus.Text
Write-Utf8File -Path (Join-Path $targetDir "bluetooth-manager.txt") -Content $bluetoothInfo
Write-Utf8File -Path (Join-Path $targetDir "logcat-errors.txt") -Content $crashLog
Write-Utf8File -Path (Join-Path $targetDir "logcat-flutter.txt") -Content $flutterLog

if (!$NoScreenshot) {
  Save-AdbBytes -Arguments @("-s", $Device, "exec-out", "screencap", "-p") -Path (Join-Path $targetDir "screen.png")
}

$versionLine = ($packageInfo -split "`r?`n" | Select-String -Pattern "versionName=|versionCode=" | Select-Object -First 4) -join "; "
$installedCodeMatch = [regex]::Match($packageInfo, "versionCode=(\d+)")
$installedVersionCode = if ($installedCodeMatch.Success) {
  [int64]$installedCodeMatch.Groups[1].Value
} else {
  $null
}
$sourceVersion = if (Test-Path -LiteralPath $pubspec) {
  $pubspecText = [System.IO.File]::ReadAllText(
    (Resolve-Path -LiteralPath $pubspec),
    [System.Text.UTF8Encoding]::new($false)
  )
  $sourceMatch = [regex]::Match($pubspecText, "(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+(\d+)\s*$")
  if ($sourceMatch.Success) {
    [pscustomobject]@{
      Name = $sourceMatch.Groups[1].Value
      Code = [int64]$sourceMatch.Groups[2].Value
      Raw = "$($sourceMatch.Groups[1].Value)+$($sourceMatch.Groups[2].Value)"
    }
  } else {
    $null
  }
} else {
  $null
}
$versionStatus = if ($sourceVersion -and $installedVersionCode) {
  if ($installedVersionCode -lt $sourceVersion.Code) {
    "WARNING: installed versionCode $installedVersionCode is older than source $($sourceVersion.Code). Device screenshot/logs may show stale UI."
  } elseif ($installedVersionCode -gt $sourceVersion.Code) {
    "WARNING: installed versionCode $installedVersionCode is newer than source $($sourceVersion.Code). Build version needs bump before install."
  } else {
    "OK: installed versionCode matches source $($sourceVersion.Code)."
  }
} elseif ($sourceVersion) {
  "WARNING: source version is $($sourceVersion.Raw), but installed versionCode could not be parsed."
} else {
  "WARNING: source version could not be parsed from $pubspec."
}
$versionIsStale = $sourceVersion -and $installedVersionCode -and ($installedVersionCode -lt $sourceVersion.Code)
$fatalPattern = "FATAL EXCEPTION|AndroidRuntime|FlutterJNI|SIGABRT|$([regex]::Escape($Package))|RGB_BLE|flutter"
$fatalLines = ($crashLog -split "`r?`n" | Select-String -Pattern $fatalPattern | Select-Object -First 20) -join [Environment]::NewLine
if (!$fatalLines) {
  $fatalLines = "No fatal crash keywords found in last $LogcatTail error lines."
}
$foregroundStatus = if ($activityInfo -match [regex]::Escape($Package)) {
  "OK: $Package is foreground/resumed."
} else {
  "WARNING: $Package is not foreground/resumed. Current activity:`n$activityInfo"
}
$screenStatus = if ($powerWindowStatus.Power -match "mWakefulness=Awake" -and $powerWindowStatus.Window -notmatch "mDreamingLockscreen=true") {
  "OK: screen is awake and keyguard/dream overlay is not reported."
} elseif ($powerWindowStatus.Power -match "mWakefulness=Asleep") {
  "WARNING: device is asleep; screenshot may be black even if the app is foreground."
} elseif ($powerWindowStatus.Window -match "mDreamingLockscreen=true") {
  "WARNING: lockscreen/dream overlay is active; screenshot may be black or not show the app even if Activity is resumed."
} else {
  "WARNING: screen/keyguard state is unclear. See power-window.txt."
}

$summary = @"
Device smoke summary
Timestamp: $timestamp
Device: $Device
Package: $Package
Launch: $launch
Version: $versionLine
Source version: $($sourceVersion.Raw)
Version status: $versionStatus
Foreground: $foregroundStatus
Screen: $screenStatus

Device info:
$deviceInfo

Crash scan:
$fatalLines

Artifacts:
$targetDir
"@

Write-Utf8File -Path (Join-Path $targetDir "summary.txt") -Content $summary
Write-Host $summary

if ($RequireCurrentVersion -and $versionIsStale) {
  throw "Installed versionCode $installedVersionCode is older than source $($sourceVersion.Code). Install the current APK before using device smoke as UI/BLE evidence."
}
