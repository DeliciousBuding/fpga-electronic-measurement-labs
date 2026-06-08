param(
  [int]$Port = 7357,
  [string]$Url = "",
  [string]$OutDir = "",
  [int]$WaitMs = 18000,
  [ValidateSet("", "light", "dark")]
  [string]$ColorScheme = ""
)

$ErrorActionPreference = "Stop"

function Get-Listener {
  param([int]$TargetPort)
  Get-NetTCPConnection -LocalPort $TargetPort -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1
}

function Resolve-Browser {
  $candidates = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe"
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }
  $cmd = Get-Command chrome -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $cmd = Get-Command msedge -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $headlessShell = Get-ChildItem "$env:LOCALAPPDATA\ms-playwright" `
    -Recurse `
    -Filter "chrome-headless-shell.exe" `
    -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending |
    Select-Object -First 1
  if ($headlessShell) {
    return $headlessShell.FullName
  }
  throw "Chrome/Edge not found. Install Chrome or Edge, or add it to PATH."
}

function Stop-BrowserProfileProcesses {
  param([string]$ProfileDir)
  $escaped = [Regex]::Escape($ProfileDir)
  Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object {
      ($_.Name -in @("chrome.exe", "msedge.exe", "chrome-headless-shell.exe")) -and
      ($_.CommandLine -match $escaped)
    } |
    ForEach-Object {
      Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

function Test-PngScreenshot {
  param(
    [string]$Path,
    [int]$ExpectedWidth,
    [int]$ExpectedHeight
  )

  if (!(Test-Path -LiteralPath $Path)) {
    throw "Screenshot not created: $Path"
  }
  $file = Get-Item -LiteralPath $Path
  if ($file.Length -lt 10000) {
    throw "Screenshot is unexpectedly small: $Path ($($file.Length) bytes)"
  }

  Add-Type -AssemblyName System.Drawing
  $image = [System.Drawing.Image]::FromFile($Path)
  try {
    if ($image.Width -ne $ExpectedWidth -or $image.Height -ne $ExpectedHeight) {
      throw "Screenshot dimensions mismatch: expected ${ExpectedWidth}x${ExpectedHeight}, got $($image.Width)x$($image.Height)"
    }

    $bitmap = New-Object System.Drawing.Bitmap($image)
    try {
      $samples = 0
      $distinct = New-Object 'System.Collections.Generic.HashSet[int]'
      $stepX = [Math]::Max(1, [Math]::Floor($image.Width / 24))
      $stepY = [Math]::Max(1, [Math]::Floor($image.Height / 24))
      for ($y = 0; $y -lt $image.Height; $y += $stepY) {
        for ($x = 0; $x -lt $image.Width; $x += $stepX) {
          $color = $bitmap.GetPixel($x, $y)
          [void]$distinct.Add($color.ToArgb())
          $samples++
        }
      }
      if ($distinct.Count -lt 8) {
        throw "Screenshot looks blank or too uniform: $Path (distinct sampled colors=$($distinct.Count), samples=$samples)"
      }
    } finally {
      $bitmap.Dispose()
    }
  } finally {
    $image.Dispose()
  }
}

function Test-PngDifferent {
  param(
    [string]$BeforePath,
    [string]$AfterPath,
    [int]$MinimumChangedSamples = 16
  )

  Add-Type -AssemblyName System.Drawing
  $before = [System.Drawing.Image]::FromFile($BeforePath)
  $after = [System.Drawing.Image]::FromFile($AfterPath)
  try {
    if ($before.Width -ne $after.Width -or $before.Height -ne $after.Height) {
      throw "Cannot compare screenshots with different dimensions: $BeforePath vs $AfterPath"
    }
    $beforeBitmap = New-Object System.Drawing.Bitmap($before)
    $afterBitmap = New-Object System.Drawing.Bitmap($after)
    try {
      $changed = 0
      $stepX = [Math]::Max(1, [Math]::Floor($before.Width / 24))
      $stepY = [Math]::Max(1, [Math]::Floor($before.Height / 24))
      for ($y = 0; $y -lt $before.Height; $y += $stepY) {
        for ($x = 0; $x -lt $before.Width; $x += $stepX) {
          if ($beforeBitmap.GetPixel($x, $y).ToArgb() -ne $afterBitmap.GetPixel($x, $y).ToArgb()) {
            $changed++
          }
        }
      }
      if ($changed -lt $MinimumChangedSamples) {
        throw "Scrolled screenshot is too similar to the initial screenshot: $AfterPath (changed sampled pixels=$changed)"
      }
    } finally {
      $beforeBitmap.Dispose()
      $afterBitmap.Dispose()
    }
  } finally {
    $before.Dispose()
    $after.Dispose()
  }
}

function Test-PngSimilar {
  param(
    [string]$ExpectedPath,
    [string]$ActualPath,
    [int]$MaximumChangedSamples = 96
  )

  Add-Type -AssemblyName System.Drawing
  $expected = [System.Drawing.Image]::FromFile($ExpectedPath)
  $actual = [System.Drawing.Image]::FromFile($ActualPath)
  try {
    if ($expected.Width -ne $actual.Width -or $expected.Height -ne $actual.Height) {
      throw "Cannot compare screenshots with different dimensions: $ExpectedPath vs $ActualPath"
    }
    $expectedBitmap = New-Object System.Drawing.Bitmap($expected)
    $actualBitmap = New-Object System.Drawing.Bitmap($actual)
    try {
      $changed = 0
      $stepX = [Math]::Max(1, [Math]::Floor($expected.Width / 24))
      $stepY = [Math]::Max(1, [Math]::Floor($expected.Height / 24))
      for ($y = 0; $y -lt $expected.Height; $y += $stepY) {
        for ($x = 0; $x -lt $expected.Width; $x += $stepX) {
          if ($expectedBitmap.GetPixel($x, $y).ToArgb() -ne $actualBitmap.GetPixel($x, $y).ToArgb()) {
            $changed++
          }
        }
      }
      if ($changed -gt $MaximumChangedSamples) {
        throw "Returned screenshot is too different from the initial screenshot: $ActualPath (changed sampled pixels=$changed)"
      }
    } finally {
      $expectedBitmap.Dispose()
      $actualBitmap.Dispose()
    }
  } finally {
    $expected.Dispose()
    $actual.Dispose()
  }
}

function Test-WebPerfMetrics {
  param([string]$Path)

  if (!(Test-Path -LiteralPath $Path)) {
    throw "Performance metrics not created: $Path"
  }
  $metrics = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
  $frame = $metrics.frameMetrics
  if ($null -eq $frame) {
    throw "Performance metrics missing frameMetrics: $Path"
  }

  if ([int]$frame.sampleCount -lt 20) {
    throw "Frame cadence sample is too short: $Path (sampleCount=$($frame.sampleCount))"
  }
  if ([double]$frame.avgFrameIntervalMs -gt 80) {
    throw "Average frame interval is too high: $Path (avg=$($frame.avgFrameIntervalMs)ms)"
  }
  if ([double]$frame.p95FrameIntervalMs -gt 140) {
    throw "P95 frame interval is too high: $Path (p95=$($frame.p95FrameIntervalMs)ms)"
  }
  if ([double]$frame.maxFrameIntervalMs -gt 280) {
    throw "Max frame interval is too high: $Path (max=$($frame.maxFrameIntervalMs)ms)"
  }

  $perf = $metrics.performanceMetrics
  if ($null -ne $perf) {
    $heap = [double]$perf.JSHeapUsedSize
    if ($heap -gt 805306368) {
      throw "JS heap used size is too high: $Path (JSHeapUsedSize=$heap)"
    }
    $taskDuration = [double]$perf.TaskDuration
    if ($taskDuration -gt 20) {
      throw "Browser task duration is too high: $Path (TaskDuration=$taskDuration)"
    }
  }
}

function Add-UrlQueryFlag {
  param(
    [string]$BaseUrl,
    [string]$Flag
  )

  $separator = if ($BaseUrl.Contains("?")) { "&" } else { "?" }
  return "$BaseUrl$separator$Flag"
}

$repoRoot = Resolve-Path "$PSScriptRoot\.."
if (!$Url) {
  $Url = "http://127.0.0.1:$Port"
}
if (!$OutDir) {
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $OutDir = Join-Path $repoRoot "artifacts\web-visual-qa\$stamp"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$resolvedOutDir = (Resolve-Path -LiteralPath $OutDir).Path

$uri = [Uri]$Url
$listener = $null
if ($uri.Host -in @("127.0.0.1", "localhost")) {
  $listener = Get-Listener -TargetPort $uri.Port
  if (!$listener) {
    throw "No local web preview is listening on $Url. Start it with tools\web-preview.ps1 -Restart."
  }
}

$browser = Resolve-Browser
$captureScript = Join-Path $PSScriptRoot "web-visual-qa-capture.mjs"
if (!(Test-Path -LiteralPath $captureScript)) {
  throw "Web visual QA capture helper not found: $captureScript"
}
$viewports = @(
  @{ Name = "desktop"; Width = 1280; Height = 720; ScrollY = 0; Tab = 0 },
  @{ Name = "mobile-390"; Width = 390; Height = 844; ScrollY = 0; Tab = 0 },
  @{ Name = "mobile-390-scroll"; Width = 390; Height = 844; ScrollY = 640; Tab = 0 },
  @{ Name = "mobile-390-scroll-return"; Width = 390; Height = 844; ScrollY = 0; Tab = 0; ScrollSequence = "640,700;-640,900" },
  @{ Name = "mobile-390-scanner"; Width = 390; Height = 844; ScrollY = 0; Tab = 0; TapSequence = "366,30,1800"; VisualQa = $true },
  @{ Name = "mobile-390-scanner-debug"; Width = 390; Height = 844; ScrollY = 0; Tab = 0; TapSequence = "366,30,1800;366,30"; VisualQa = $true },
  @{ Name = "mobile-390-effect"; Width = 390; Height = 844; ScrollY = 0; Tab = 1 },
  @{ Name = "mobile-390-scene"; Width = 390; Height = 844; ScrollY = 0; Tab = 2 },
  @{ Name = "mobile-390-settings"; Width = 390; Height = 844; ScrollY = 0; Tab = 3 },
  @{ Name = "mobile-460"; Width = 460; Height = 900; ScrollY = 0; Tab = 0 },
  @{ Name = "mobile-460-scroll"; Width = 460; Height = 900; ScrollY = 720; Tab = 0 }
)

$summary = @()
$initialScreenshots = @{}
$screenshotsByName = @{}
foreach ($viewport in $viewports) {
  $name = $viewport.Name
  $width = [int]$viewport.Width
  $height = [int]$viewport.Height
  $scrollY = [int]$viewport.ScrollY
  $tab = [int]$viewport.Tab
  $tapSequence = if ($viewport.ContainsKey("TapSequence")) { [string]$viewport.TapSequence } else { "" }
  $scrollSequence = if ($viewport.ContainsKey("ScrollSequence")) { [string]$viewport.ScrollSequence } else { "" }
  $captureUrl = if ($viewport.ContainsKey("VisualQa") -and $viewport.VisualQa) {
    Add-UrlQueryFlag -BaseUrl $Url -Flag "visualQa=1"
  } else {
    $Url
  }
  $tapX = [Math]::Round($width * (($tab * 2) + 1) / 8)
  $tapY = $height - 40
  $screenshot = Join-Path $resolvedOutDir "$name.png"
  $browserLog = Join-Path $resolvedOutDir "$name.browser-events.json"
  $metricsLog = Join-Path $resolvedOutDir "$name.perf.json"
  $stdoutLog = Join-Path $resolvedOutDir "$name.stdout.log"
  $stderrLog = Join-Path $resolvedOutDir "$name.stderr.log"
  $captured = $false
  $lastCaptureError = $null
  for ($attempt = 1; $attempt -le 3 -and !$captured; $attempt++) {
    if (Test-Path -LiteralPath $screenshot) {
      Remove-Item -LiteralPath $screenshot -Force
    }
    $userDataDir = Join-Path $resolvedOutDir "chrome-$name-try$attempt"
    New-Item -ItemType Directory -Force -Path $userDataDir | Out-Null

    $args = @(
      $captureScript,
      "--browser", $browser,
      "--url", $captureUrl,
      "--out", $screenshot,
      "--log-out", $browserLog,
      "--metrics-out", $metricsLog,
      "--profile", $userDataDir,
      "--width", "$width",
      "--height", "$height",
      "--scroll-y", "$scrollY",
      "--wait-ms", "$WaitMs"
    )
    if ($ColorScheme) {
      $args += @("--color-scheme", $ColorScheme)
    }
    if ($tab -ne 0) {
      $args += @("--tap-x", "$tapX", "--tap-y", "$tapY")
    }
    if ($tapSequence) {
      $args += @("--tap-sequence", $tapSequence)
    }
    if ($scrollSequence) {
      $args += @("--scroll-sequence", $scrollSequence)
    }
    & node @args > $stdoutLog 2> $stderrLog
    $exitCode = $LASTEXITCODE
    Stop-BrowserProfileProcesses -ProfileDir $userDataDir
    if ($exitCode -ne 0) {
      throw "Browser screenshot failed for $name with exit code $exitCode. See $stderrLog"
    }
    if (Test-Path -LiteralPath $screenshot) {
      try {
        Test-PngScreenshot -Path $screenshot -ExpectedWidth $width -ExpectedHeight $height
        $captured = $true
      } catch {
        $lastCaptureError = $_.Exception.Message
        Remove-Item -LiteralPath $screenshot -Force -ErrorAction SilentlyContinue
      }
    } else {
      $lastCaptureError = "Screenshot not created: $screenshot"
    }
    if (!$captured -and $attempt -lt 3) {
      Start-Sleep -Milliseconds 500
    }
  }
  if (!$captured) {
    throw "Could not capture a valid screenshot for $name after 3 attempts. Last error: $lastCaptureError"
  }
  Test-WebPerfMetrics -Path $metricsLog
  $viewportKey = "${width}x${height}"
  if ($scrollSequence) {
    # Sequence screenshots use explicit named checks below.
  } elseif ($scrollY -eq 0) {
    if (!$initialScreenshots.ContainsKey($viewportKey)) {
      $initialScreenshots[$viewportKey] = $screenshot
    } elseif ($tab -ne 0 -or $tapSequence) {
      Test-PngDifferent -BeforePath $initialScreenshots[$viewportKey] -AfterPath $screenshot
    }
  } elseif ($initialScreenshots.ContainsKey($viewportKey)) {
    Test-PngDifferent -BeforePath $initialScreenshots[$viewportKey] -AfterPath $screenshot
  }
  if ($name -eq "mobile-390-scroll-return" -and $screenshotsByName.ContainsKey("mobile-390")) {
    Test-PngSimilar -ExpectedPath $screenshotsByName["mobile-390"] -ActualPath $screenshot
  }
  if ($name -eq "mobile-390-scanner-debug" -and $screenshotsByName.ContainsKey("mobile-390-scanner")) {
    Test-PngDifferent -BeforePath $screenshotsByName["mobile-390-scanner"] -AfterPath $screenshot -MinimumChangedSamples 48
  }
  $screenshotsByName[$name] = $screenshot
  $file = Get-Item -LiteralPath $screenshot
  $perf = Get-Content -LiteralPath $metricsLog -Raw | ConvertFrom-Json
  $frame = $perf.frameMetrics
  $summary += "$name ${width}x${height} tab=$tab scrollY=$scrollY scrolls=$scrollSequence taps=$tapSequence $($file.Length) bytes $screenshot console=$browserLog perf=$metricsLog avgFrameMs=$([Math]::Round([double]$frame.avgFrameIntervalMs, 2)) p95FrameMs=$([Math]::Round([double]$frame.p95FrameIntervalMs, 2)) maxFrameMs=$([Math]::Round([double]$frame.maxFrameIntervalMs, 2))"
}

$summaryPath = Join-Path $resolvedOutDir "summary.txt"
$summary | Set-Content -Encoding UTF8 -Path $summaryPath
Write-Host "Web visual QA passed for $Url"
Write-Host "Summary: $summaryPath"
$summary | ForEach-Object { Write-Host $_ }
