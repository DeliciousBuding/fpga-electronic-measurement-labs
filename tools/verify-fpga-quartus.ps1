param(
  [string]$OutDir = "$PSScriptRoot\..\artifacts\fpga-quartus",
  [int]$MaxWarnings = 0,
  [int]$MaxLogicElements = 2000,
  [int]$MaxRegisters = 1200,
  [int]$MaxPins = 8,
  [int]$MaxMult9 = 8
)

$ErrorActionPreference = "Stop"

function Resolve-Tool {
  param(
    [string]$Name,
    [string[]]$Fallbacks = @()
  )
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if ($cmd) {
    return $cmd.Source
  }
  foreach ($fallback in $Fallbacks) {
    if (Test-Path -LiteralPath $fallback) {
      return $fallback
    }
  }
  throw "$Name not found. Add Quartus bin64 directory to PATH."
}

$repoRoot = Resolve-Path "$PSScriptRoot\.."
$projectRoot = Join-Path $repoRoot "final-rgb-controller"
$projectName = "final-rgb-controller"
if (!(Test-Path -LiteralPath (Join-Path $projectRoot "$projectName.qpf"))) {
  throw "Quartus project not found: $projectRoot\$projectName.qpf"
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runDir = Join-Path $OutDir $stamp
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$resolvedRunDir = (Resolve-Path -LiteralPath $runDir).Path
$stdoutLog = Join-Path $resolvedRunDir "quartus-map.stdout.log"
$stderrLog = Join-Path $resolvedRunDir "quartus-map.stderr.log"
$reportCopy = Join-Path $resolvedRunDir "$projectName.map.rpt"
$summaryCopy = Join-Path $resolvedRunDir "$projectName.map.summary"

$quartusMap = Resolve-Tool "quartus_map" @("C:\altera_lite\25.1std\quartus\bin64\quartus_map.exe")

Push-Location $projectRoot
try {
  $proc = Start-Process `
    -FilePath $quartusMap `
    -ArgumentList @("--read_settings_files=on", "--write_settings_files=off", $projectName) `
    -NoNewWindow `
    -PassThru `
    -Wait `
    -RedirectStandardOutput $stdoutLog `
    -RedirectStandardError $stderrLog
  if ($proc.ExitCode -ne 0) {
    throw "quartus_map failed with exit code $($proc.ExitCode). Logs: $stdoutLog $stderrLog"
  }
} finally {
  Pop-Location
}

$report = Join-Path $projectRoot "output_files\$projectName.map.rpt"
$summary = Join-Path $projectRoot "output_files\$projectName.map.summary"
if (!(Test-Path -LiteralPath $report)) {
  throw "Quartus map report not found: $report"
}
Copy-Item -LiteralPath $report -Destination $reportCopy -Force
if (Test-Path -LiteralPath $summary) {
  Copy-Item -LiteralPath $summary -Destination $summaryCopy -Force
}

$reportText = Get-Content -LiteralPath $report -Raw
$stdoutText = Get-Content -LiteralPath $stdoutLog -Raw
if ($reportText -notmatch "Analysis\s+&\s+Synthesis\s+Status\s*;\s*Successful") {
  throw "Quartus Analysis & Synthesis was not successful. Report: $reportCopy"
}
if ($stdoutText -notmatch "Analysis\s+&\s+Synthesis\s+was\s+successful\.\s+0\s+errors") {
  throw "quartus_map did not report 0 errors. Log: $stdoutLog"
}

$warningMatch = [regex]::Match($stdoutText, "Analysis\s+&\s+Synthesis\s+was\s+successful\.\s+0\s+errors,\s+(\d+)\s+warnings?")
$warningCount = if ($warningMatch.Success) { [int]$warningMatch.Groups[1].Value } else { -1 }
if ($warningCount -lt 0) {
  throw "Could not parse Quartus warning count. Log: $stdoutLog"
}
if ($warningCount -gt $MaxWarnings) {
  throw "Quartus warning budget exceeded: warnings=$warningCount, max=$MaxWarnings. Report: $reportCopy"
}
$resourceMatch = [regex]::Match(
  $reportText,
  "Total logic elements\s*;\s*([0-9,]+).*?Total registers\s*;\s*([0-9,]+).*?Total pins\s*;\s*([0-9,]+).*?Embedded Multiplier 9-bit elements\s*;\s*([0-9,]+)",
  [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (!$resourceMatch.Success) {
  throw "Could not parse Quartus resource summary. Report: $reportCopy"
}

$logicElements = [int]($resourceMatch.Groups[1].Value -replace ",", "")
$registers = [int]($resourceMatch.Groups[2].Value -replace ",", "")
$pins = [int]($resourceMatch.Groups[3].Value -replace ",", "")
$mult9 = [int]($resourceMatch.Groups[4].Value -replace ",", "")

if ($logicElements -gt $MaxLogicElements) {
  throw "Quartus logic element budget exceeded: LEs=$logicElements, max=$MaxLogicElements. Report: $reportCopy"
}
if ($registers -gt $MaxRegisters) {
  throw "Quartus register budget exceeded: registers=$registers, max=$MaxRegisters. Report: $reportCopy"
}
if ($pins -gt $MaxPins) {
  throw "Quartus pin budget exceeded: pins=$pins, max=$MaxPins. Report: $reportCopy"
}
if ($mult9 -gt $MaxMult9) {
  throw "Quartus multiplier budget exceeded: mult9=$mult9, max=$MaxMult9. Report: $reportCopy"
}

Write-Host "Quartus Analysis & Synthesis passed: 0 errors, $warningCount warnings"
Write-Host "Resources: LEs=$logicElements/$MaxLogicElements, registers=$registers/$MaxRegisters, pins=$pins/$MaxPins, mult9=$mult9/$MaxMult9"
Write-Host "Report: $reportCopy"
if (Test-Path -LiteralPath $summaryCopy) {
  Write-Host "Summary: $summaryCopy"
}
