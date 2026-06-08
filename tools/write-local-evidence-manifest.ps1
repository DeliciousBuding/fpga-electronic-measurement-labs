param(
  [string]$OutDir = "",
  [string]$ReportRoot = ""
)

$ErrorActionPreference = "Stop"

function Get-LatestDirectory {
  param(
    [string]$Path,
    [string]$Name
  )

  if (!(Test-Path -LiteralPath $Path)) {
    throw "Evidence directory missing for ${Name}: $Path"
  }
  $dir = Get-ChildItem -LiteralPath $Path -Directory |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if (!$dir) {
    throw "No evidence runs found for ${Name}: $Path"
  }
  return $dir
}

function Get-FileEvidence {
  param(
    [string]$Path,
    [string]$Kind,
    [string]$Description
  )

  if (!(Test-Path -LiteralPath $Path)) {
    throw "Required evidence file missing: $Path"
  }
  $item = Get-Item -LiteralPath $Path
  $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
  return [PSCustomObject]@{
    kind = $Kind
    description = $Description
    path = $item.FullName
    bytes = $item.Length
    lastWriteTime = $item.LastWriteTime.ToString("o")
    sha256 = $hash.Hash.ToLowerInvariant()
  }
}

function Find-ReportMarkdown {
  param([string]$Root)

  $candidate = Get-ChildItem -LiteralPath $Root -Recurse -Filter "*RGB*.md" -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Length -gt 15000 -and
      (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8) -match "WebVisualQA"
    } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if (!$candidate) {
    throw "Could not discover RGB report Markdown under: $Root"
  }
  return $candidate.FullName
}

$repoRoot = Resolve-Path "$PSScriptRoot\.."
$artifactsRoot = Join-Path $repoRoot "artifacts"
if (!$OutDir) {
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $OutDir = Join-Path $artifactsRoot "local-evidence\$stamp"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$resolvedOutDir = (Resolve-Path -LiteralPath $OutDir).Path

$webDir = Get-LatestDirectory -Path (Join-Path $artifactsRoot "web-visual-qa") -Name "WebVisualQA"
$simDir = Get-LatestDirectory -Path (Join-Path $artifactsRoot "fpga-sim") -Name "FPGA simulation"
$quartusDir = Get-LatestDirectory -Path (Join-Path $artifactsRoot "fpga-quartus") -Name "Quartus Analysis and Synthesis"

$reportSearchRoot = if ($ReportRoot) {
  (Resolve-Path -LiteralPath $ReportRoot).Path
} else {
  Join-Path $env:USERPROFILE "Documents"
}
$reportMarkdown = Find-ReportMarkdown -Root $reportSearchRoot
$reportDir = Split-Path -Parent $reportMarkdown
$reportBaseName = [IO.Path]::GetFileNameWithoutExtension($reportMarkdown)
$reportDocx = (Get-ChildItem -LiteralPath $reportDir -Filter "$reportBaseName*.docx" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1).FullName
$reportPdf = (Get-ChildItem -LiteralPath $reportDir -Filter "$reportBaseName*.pdf" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1).FullName
$checklist = (Get-ChildItem -LiteralPath $reportDir -Filter "*RGB*.md" |
  Where-Object {
    $_.FullName -ne $reportMarkdown -and
    $_.Length -lt 10000 -and
    (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8) -match "PDF" -and
    (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8) -match "DOCX"
  } |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1).FullName

if (!$reportDocx -or !$reportPdf -or !$checklist) {
  throw "Could not discover report DOCX/PDF/checklist evidence files."
}

$apk = Join-Path $repoRoot "app\build\app\outputs\flutter-apk\app-release.apk"
$webSummary = Join-Path $webDir.FullName "summary.txt"
$simTranscript = Join-Path $simDir.FullName "modelsim-transcript.log"
$quartusReport = Join-Path $quartusDir.FullName "final-rgb-controller.map.rpt"
$quartusSummary = Join-Path $quartusDir.FullName "final-rgb-controller.map.summary"

$pngCount = @(Get-ChildItem -LiteralPath $webDir.FullName -Filter "*.png").Count
$browserEventCount = @(Get-ChildItem -LiteralPath $webDir.FullName -Filter "*.browser-events.json").Count
$perfCount = @(Get-ChildItem -LiteralPath $webDir.FullName -Filter "*.perf.json").Count
if ($pngCount -lt 11 -or $browserEventCount -lt 11 -or $perfCount -lt 11) {
  throw "Latest WebVisualQA run is incomplete: png=$pngCount browserEvents=$browserEventCount perf=$perfCount ($($webDir.FullName))"
}

$files = @(
  Get-FileEvidence -Path $webSummary -Kind "web-visual-qa-summary" -Description "WebVisualQA summary for latest local visual/perf run"
  Get-FileEvidence -Path $simTranscript -Kind "fpga-modelsim-transcript" -Description "ModelSim full-link and WS2812 timing transcript"
  Get-FileEvidence -Path $quartusReport -Kind "quartus-map-report" -Description "Quartus Analysis and Synthesis report"
  Get-FileEvidence -Path $quartusSummary -Kind "quartus-map-summary" -Description "Quartus Analysis and Synthesis summary"
  Get-FileEvidence -Path $reportMarkdown -Kind "course-report-markdown" -Description "Course report Markdown draft"
  Get-FileEvidence -Path $reportDocx -Kind "course-report-docx" -Description "Course report DOCX local validation draft"
  Get-FileEvidence -Path $reportPdf -Kind "course-report-pdf" -Description "Course report PDF local validation draft"
  Get-FileEvidence -Path $checklist -Kind "course-submit-checklist" -Description "Course submission checklist"
  Get-FileEvidence -Path $apk -Kind "android-release-apk" -Description "Flutter Android release APK"
)

$manifest = [PSCustomObject]@{
  generatedAt = (Get-Date).ToString("o")
  repoRoot = (Resolve-Path -LiteralPath $repoRoot).Path
  noDeviceEvidence = $true
  forbiddenDeviceTargets = @("[REDACTED]:5555", "[REDACTED]")
  recommendedGate = "powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\verify-app.ps1 -AllLocal"
  latestRuns = [PSCustomObject]@{
    webVisualQa = $webDir.FullName
    fpgaSim = $simDir.FullName
    fpgaQuartus = $quartusDir.FullName
  }
  counts = [PSCustomObject]@{
    webVisualQaPng = $pngCount
    webVisualQaBrowserEvents = $browserEventCount
    webVisualQaPerf = $perfCount
    evidenceFiles = $files.Count
  }
  evidence = $files
}

$manifestPath = Join-Path $resolvedOutDir "manifest.json"
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

$markdownPath = Join-Path $resolvedOutDir "manifest.md"
$lines = @(
  "# Local Evidence Manifest",
  "",
  "- Generated: $($manifest.generatedAt)",
  "- No device evidence: $($manifest.noDeviceEvidence)",
  ('- Recommended gate: `' + $manifest.recommendedGate + '`'),
  ('- WebVisualQA: `' + $webDir.FullName + '`'),
  ('- FPGA simulation: `' + $simDir.FullName + '`'),
  ('- Quartus: `' + $quartusDir.FullName + '`'),
  "- WebVisualQA files: png=$pngCount, browserEvents=$browserEventCount, perf=$perfCount",
  "",
  "## Evidence Files",
  ""
)
foreach ($file in $files) {
  $lines += ('- `' + $file.kind + '` - ' + $file.bytes + ' bytes - SHA256 `' + $file.sha256 + '` - `' + $file.path + '`')
}
$lines | Set-Content -LiteralPath $markdownPath -Encoding UTF8

Write-Host "Local evidence manifest written."
Write-Host "Manifest JSON: $manifestPath"
Write-Host "Manifest Markdown: $markdownPath"
Write-Host "Evidence files: $($files.Count)"
