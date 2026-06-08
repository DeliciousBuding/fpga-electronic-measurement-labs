param(
  [switch]$AllLocal,
  [switch]$SkipAnalyze,
  [switch]$SkipTests,
  [switch]$WebStatus,
  [switch]$WebVisualQA,
  [switch]$FpgaSim,
  [switch]$QuartusMap,
  [switch]$ReportDraft,
  [switch]$ApkQuality,
  [switch]$EvidenceManifest,
  [switch]$DeliverablePackage,
  [switch]$FieldEvidence,
  [switch]$RequireFieldEvidence,
  [switch]$DeviceSmoke,
  [switch]$AllowDeviceOffline,
  [switch]$AllowStaleInstalledApp,
  [switch]$DeviceSmokeNoScreenshot,
  [switch]$Release,
  [string]$Device = "[REDACTED]:5555",
  [ValidateSet("debug", "release", "profile")]
  [string]$Mode = "release",
  [string]$TargetPlatform = "android-arm64",
  [switch]$SplitPerAbi,
  [switch]$NoVersionBump,
  [switch]$AllowPersonalDevice
)

$ErrorActionPreference = "Stop"

function Invoke-Step {
  param(
    [string]$Name,
    [scriptblock]$Action
  )

  Write-Host ""
  Write-Host "==> $Name"
  & $Action
  Write-Host "OK: $Name"
}

function Invoke-Flutter {
  param([string[]]$FlutterArgs)

  Push-Location $appRoot
  try {
    & flutter @FlutterArgs
    if ($LASTEXITCODE -ne 0) {
      throw "flutter $($FlutterArgs -join ' ') failed with exit code $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }
}

function Convert-TargetPlatformToAbi {
  param([string]$Platform)

  switch ($Platform) {
    "android-arm64" { return "arm64-v8a" }
    "android-arm" { return "armeabi-v7a" }
    "android-x64" { return "x86_64" }
    default { throw "Unsupported Android target platform for APK quality verification: $Platform" }
  }
}

$repoRoot = Resolve-Path "$PSScriptRoot\.."
$appRoot = Join-Path $repoRoot "app"
$webPreviewScript = Join-Path $PSScriptRoot "web-preview.ps1"
$webVisualQaScript = Join-Path $PSScriptRoot "web-visual-qa.ps1"
$fpgaSimScript = Join-Path $PSScriptRoot "verify-fpga-sim.ps1"
$quartusMapScript = Join-Path $PSScriptRoot "verify-fpga-quartus.ps1"
$reportDraftScript = Join-Path $PSScriptRoot "verify-report-draft.ps1"
$apkQualityScript = Join-Path $PSScriptRoot "verify-android-apk.ps1"
$evidenceManifestScript = Join-Path $PSScriptRoot "write-local-evidence-manifest.ps1"
$deliverablePackageScript = Join-Path $PSScriptRoot "verify-deliverable-package.ps1"
$fieldEvidenceScript = Join-Path $PSScriptRoot "verify-field-evidence.ps1"
$buildAndroidScript = Join-Path $PSScriptRoot "build-android.ps1"
$deviceSmokeScript = Join-Path $PSScriptRoot "device-smoke.ps1"
$personalDevices = @("[REDACTED]:5555", "[REDACTED]")

if ($AllLocal) {
  if ($DeviceSmoke -or $Release) {
    throw "-AllLocal is a no-device local gate. Do not combine it with -DeviceSmoke or -Release."
  }
  $WebStatus = $true
  $WebVisualQA = $true
  $FpgaSim = $true
  $QuartusMap = $true
  $ReportDraft = $true
  $ApkQuality = $true
  $EvidenceManifest = $true
}

if (($Device -in $personalDevices) -and !$AllowPersonalDevice -and $DeviceSmoke) {
  throw "Personal phone testing is disabled for $Device. Omit -DeviceSmoke or explicitly re-authorize and pass -AllowPersonalDevice."
}

if (!(Test-Path -LiteralPath $appRoot)) {
  throw "Flutter app directory not found: $appRoot"
}

if (!$SkipAnalyze) {
  Invoke-Step "flutter analyze" {
    Invoke-Flutter @("analyze")
  }
}

if (!$SkipTests) {
  Invoke-Step "flutter test" {
    Invoke-Flutter @("test")
  }
}

if ($WebStatus) {
  if (!(Test-Path -LiteralPath $webPreviewScript)) {
    throw "Web preview script not found: $webPreviewScript"
  }
  Invoke-Step "web preview status" {
    & $webPreviewScript -Status
    if ($LASTEXITCODE -ne 0) {
      throw "web-preview.ps1 -Status failed with exit code $LASTEXITCODE"
    }
  }
}

if ($WebVisualQA) {
  if (!(Test-Path -LiteralPath $webVisualQaScript)) {
    throw "Web visual QA script not found: $webVisualQaScript"
  }
  Invoke-Step "web visual QA" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $webVisualQaScript
    if ($LASTEXITCODE -ne 0) {
      throw "web-visual-qa.ps1 failed with exit code $LASTEXITCODE"
    }
  }
}

if ($FpgaSim) {
  if (!(Test-Path -LiteralPath $fpgaSimScript)) {
    throw "FPGA simulation script not found: $fpgaSimScript"
  }
  Invoke-Step "FPGA ModelSim simulation" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $fpgaSimScript
    if ($LASTEXITCODE -ne 0) {
      throw "verify-fpga-sim.ps1 failed with exit code $LASTEXITCODE"
    }
  }
}

if ($QuartusMap) {
  if (!(Test-Path -LiteralPath $quartusMapScript)) {
    throw "Quartus verification script not found: $quartusMapScript"
  }
  Invoke-Step "Quartus Analysis & Synthesis" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $quartusMapScript
    if ($LASTEXITCODE -ne 0) {
      throw "verify-fpga-quartus.ps1 failed with exit code $LASTEXITCODE"
    }
  }
}

if ($ReportDraft) {
  if (!(Test-Path -LiteralPath $reportDraftScript)) {
    throw "Report draft verification script not found: $reportDraftScript"
  }
  Invoke-Step "report draft verification" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $reportDraftScript
    if ($LASTEXITCODE -ne 0) {
      throw "verify-report-draft.ps1 failed with exit code $LASTEXITCODE"
    }
  }
}

if ($ApkQuality) {
  if (!(Test-Path -LiteralPath $apkQualityScript)) {
    throw "Android APK quality verification script not found: $apkQualityScript"
  }
  Invoke-Step "Android APK quality verification" {
    $targetAbi = Convert-TargetPlatformToAbi -Platform $TargetPlatform
    & powershell -NoProfile -ExecutionPolicy Bypass -File $apkQualityScript -TargetAbi $targetAbi
    if ($LASTEXITCODE -ne 0) {
      throw "verify-android-apk.ps1 failed with exit code $LASTEXITCODE"
    }
  }
}

if ($EvidenceManifest) {
  if (!(Test-Path -LiteralPath $evidenceManifestScript)) {
    throw "Local evidence manifest script not found: $evidenceManifestScript"
  }
  Invoke-Step "local evidence manifest" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $evidenceManifestScript
    if ($LASTEXITCODE -ne 0) {
      throw "write-local-evidence-manifest.ps1 failed with exit code $LASTEXITCODE"
    }
  }
}

if ($DeliverablePackage) {
  if (!(Test-Path -LiteralPath $deliverablePackageScript)) {
    throw "Deliverable package verification script not found: $deliverablePackageScript"
  }
  Invoke-Step "deliverable package verification" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $deliverablePackageScript
    if ($LASTEXITCODE -ne 0) {
      throw "verify-deliverable-package.ps1 failed with exit code $LASTEXITCODE"
    }
  }
}

if ($FieldEvidence -or $RequireFieldEvidence) {
  if (!(Test-Path -LiteralPath $fieldEvidenceScript)) {
    throw "Field evidence verification script not found: $fieldEvidenceScript"
  }
  Invoke-Step "field evidence status" {
    $fieldArgs = @()
    if ($RequireFieldEvidence) {
      $fieldArgs += "-RequireComplete"
    }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $fieldEvidenceScript @fieldArgs
    if ($LASTEXITCODE -ne 0) {
      throw "verify-field-evidence.ps1 failed with exit code $LASTEXITCODE"
    }
  }
}

if ($DeviceSmoke) {
  if (!(Test-Path -LiteralPath $deviceSmokeScript)) {
    throw "Device smoke script not found: $deviceSmokeScript"
  }
  Invoke-Step "device smoke" {
    $smokeArgs = @("-Device", $Device)
    if ($DeviceSmokeNoScreenshot) {
      $smokeArgs += "-NoScreenshot"
    }
    if ($AllowPersonalDevice) {
      $smokeArgs += "-AllowPersonalDevice"
    }
    if (!$AllowStaleInstalledApp) {
      $smokeArgs += "-RequireCurrentVersion"
    }

    & powershell -NoProfile -ExecutionPolicy Bypass -File $deviceSmokeScript @smokeArgs
    if ($LASTEXITCODE -ne 0) {
      if ($AllowDeviceOffline) {
        Write-Warning "device-smoke.ps1 failed, continuing because -AllowDeviceOffline was set."
      } else {
        throw "device-smoke.ps1 failed with exit code $LASTEXITCODE"
      }
    }
  }
}

if ($Release) {
  if (!(Test-Path -LiteralPath $buildAndroidScript)) {
    throw "Android build script not found: $buildAndroidScript"
  }
  Invoke-Step "Android APK build ($Mode)" {
    $buildArgs = @(
      "-Device",
      $Device,
      "-Mode",
      $Mode
    )

    if ($SplitPerAbi) {
      $buildArgs += "-SplitPerAbi"
    } elseif ($TargetPlatform) {
      $buildArgs += @("-TargetPlatform", $TargetPlatform)
    }

    if ($NoVersionBump) {
      $buildArgs += "-NoVersionBump"
    }
    if ($AllowPersonalDevice) {
      $buildArgs += "-AllowPersonalDevice"
    }

    & powershell -NoProfile -ExecutionPolicy Bypass -File $buildAndroidScript @buildArgs
    if ($LASTEXITCODE -ne 0) {
      throw "build-android.ps1 failed with exit code $LASTEXITCODE"
    }
  }
}

Write-Host ""
Write-Host "Verification completed."
