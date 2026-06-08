param(
  [string]$EvidenceDir = "",
  [switch]$RequireComplete
)

$ErrorActionPreference = "Stop"

function Find-FieldEvidenceDir {
  $root = Join-Path $env:USERPROFILE "Documents"
  $candidate = Get-ChildItem -LiteralPath $root -Directory -Recurse -Filter "field-evidence" -ErrorAction SilentlyContinue |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "README.md") } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if (!$candidate) {
    throw "Could not find field-evidence directory under user Documents."
  }
  return $candidate.FullName
}

function Get-Files {
  param(
    [string]$Path,
    [string[]]$Patterns
  )

  $files = @()
  foreach ($pattern in $Patterns) {
    $files += @(Get-ChildItem -LiteralPath $Path -File -Filter $pattern -ErrorAction SilentlyContinue)
  }
  return @($files | Sort-Object FullName -Unique)
}

if (!$EvidenceDir) {
  $EvidenceDir = Find-FieldEvidenceDir
}
$resolvedEvidenceDir = (Resolve-Path -LiteralPath $EvidenceDir).Path

$requirements = @(
  [PSCustomObject]@{
    id = "ble-scan"
    title = "latest APK BLE scan screenshot"
    directory = "01-ble-scan"
    patterns = @("*.png", "*.jpg", "*.jpeg", "*.webp")
    minFiles = 1
  },
  [PSCustomObject]@{
    id = "ble-connect"
    title = "CH9143 connection screenshot or diagnostic export"
    directory = "02-ble-connect"
    patterns = @("*.png", "*.jpg", "*.jpeg", "*.webp", "*.json", "*.txt", "*.md")
    minFiles = 1
  },
  [PSCustomObject]@{
    id = "led-effects"
    title = "real WS2812 LED photos or video screenshots"
    directory = "03-led-effects"
    patterns = @("*.png", "*.jpg", "*.jpeg", "*.webp", "*.mp4", "*.mov")
    minFiles = 3
  },
  [PSCustomObject]@{
    id = "serial-log"
    title = "serial COM log with sent bytes and ACK/status frame"
    directory = "04-serial-log"
    patterns = @("serial-log.md", "*.png", "*.jpg", "*.jpeg", "*.txt", "*.csv")
    minFiles = 1
  },
  [PSCustomObject]@{
    id = "waveform"
    title = "SignalTap or oscilloscope waveform"
    directory = "05-waveform"
    patterns = @("*.png", "*.jpg", "*.jpeg", "*.webp", "*.csv", "*.vcd")
    minFiles = 1
  },
  [PSCustomObject]@{
    id = "cover-info"
    title = "cover information"
    directory = "06-cover-info"
    patterns = @("cover-info.md", "*.docx", "*.pdf")
    minFiles = 1
  }
)

$results = @()
foreach ($requirement in $requirements) {
  $dir = Join-Path $resolvedEvidenceDir $requirement.directory
  if (!(Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $files = Get-Files -Path $dir -Patterns $requirement.patterns
  $templateFiles = @($files | Where-Object { $_.Name -like "*-template.md" })
  $actualFiles = @($files | Where-Object { $_.Name -notlike "*-template.md" })
  $complete = $actualFiles.Count -ge $requirement.minFiles
  $results += [PSCustomObject]@{
    id = $requirement.id
    title = $requirement.title
    directory = $dir
    requiredFiles = $requirement.minFiles
    actualFiles = $actualFiles.Count
    templateFiles = $templateFiles.Count
    complete = $complete
    files = @($actualFiles | ForEach-Object { $_.FullName })
  }
}

$summary = [PSCustomObject]@{
  generatedAt = (Get-Date).ToString("o")
  evidenceDir = $resolvedEvidenceDir
  requireComplete = [bool]$RequireComplete
  complete = @($results | Where-Object { $_.complete }).Count
  total = $results.Count
  missing = @($results | Where-Object { -not $_.complete }).Count
  results = $results
}

$statusPath = Join-Path $resolvedEvidenceDir "field-evidence-status.json"
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statusPath -Encoding UTF8

Write-Host "Field evidence status written: $statusPath"
Write-Host "Complete: $($summary.complete)/$($summary.total); missing=$($summary.missing)"
foreach ($result in $results) {
  $state = if ($result.complete) { "OK" } else { "MISSING" }
  Write-Host "[$state] $($result.id): $($result.actualFiles)/$($result.requiredFiles) files - $($result.title)"
}

if ($RequireComplete -and $summary.missing -gt 0) {
  throw "Field evidence is incomplete. Fill field-evidence directories before final submission."
}
