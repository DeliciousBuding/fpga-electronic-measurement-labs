<#
.SYNOPSIS
    RGB BLE Controller - Field Evidence Completeness Check

.DESCRIPTION
    Checks whether all 6 categories of field evidence are present.
    Default: non-strict mode (lists missing items).
    -RequireComplete: strict mode (exit 1 if any item missing).

.PARAMETER RequireComplete
    Strict mode: exit code 1 if any evidence item is missing.

.PARAMETER EvidenceDir
    Root directory of field-evidence. Auto-detected if not provided.

.EXAMPLE
    .\verify-field-evidence.ps1
    .\verify-field-evidence.ps1 -RequireComplete
#>

param(
    [switch]$RequireComplete,
    [string]$EvidenceDir = ""
)

$ErrorActionPreference = "Stop"

# ---- auto-detect evidence dir ----
if (-not $EvidenceDir) {
    $candidates = @(
        "$PSScriptRoot\..\field-evidence"
    )
    # Also check the known course directory path
    $coursePath = Join-Path $env:USERPROFILE "Documents\personal\03-course\current\electronic-measurement\comprehensive-lab\field-evidence"
    # Try the actual path with Chinese characters via Resolve-Path wildcard
    $fallback = "$env:USERPROFILE\Documents\*\03*\当前学期\电子测量\综合实验\field-evidence"
    $candidates += $fallback

    foreach ($c in $candidates) {
        $resolved = Resolve-Path $c -ErrorAction SilentlyContinue
        if ($resolved -and (Test-Path $resolved)) {
            $EvidenceDir = $resolved.Path
            break
        }
    }
}

if (-not $EvidenceDir -or -not (Test-Path $EvidenceDir)) {
    Write-Host "ERROR: Cannot find field-evidence directory." -ForegroundColor Red
    Write-Host "Pass -EvidenceDir <path> or run from the Quartus project root." -ForegroundColor Yellow
    exit 2
}

Write-Host ""
Write-Host "=== Field Evidence Verifier ===" -ForegroundColor Cyan
Write-Host "Evidence dir: $EvidenceDir"
Write-Host ""

# ---- evidence definitions ----
$items = @(
    @{ Id = "ble-scan";    Title = "BLE scan screenshot";                  Dir = "01-ble-scan";    MinFiles = 1; Patterns = @("*.png", "*.jpg", "*.jpeg") },
    @{ Id = "ble-connect"; Title = "BLE connection screenshot";            Dir = "02-ble-connect"; MinFiles = 1; Patterns = @("*.png", "*.jpg", "*.jpeg") },
    @{ Id = "led-effects"; Title = "LED effect photos";                   Dir = "03-led-effects"; MinFiles = 3; Patterns = @("*.png", "*.jpg", "*.jpeg") },
    @{ Id = "serial-log";  Title = "Serial log";                          Dir = "04-serial-log";  MinFiles = 1; Patterns = @("*.md", "*.txt", "*.png", "*.jpg", "*.jpeg") },
    @{ Id = "waveform";    Title = "SignalTap / oscilloscope waveform";    Dir = "05-waveform";    MinFiles = 1; Patterns = @("*.png", "*.jpg", "*.jpeg", "*.stp") },
    @{ Id = "cover-info";  Title = "Cover information";                   Dir = "06-cover-info";  MinFiles = 1; Patterns = @("*.md", "*.txt") }
)

$total    = $items.Count
$complete = 0
$missing  = 0
$results  = @()

foreach ($item in $items) {
    $dirPath = Join-Path $EvidenceDir $item.Dir
    $exists  = Test-Path $dirPath
    $files   = @()
    $count   = 0

    if ($exists) {
        foreach ($pattern in $item.Patterns) {
            $found = Get-ChildItem -Path $dirPath -Filter $pattern -File -ErrorAction SilentlyContinue
            if ($found) { $files += $found }
        }
        $count = $files.Count
    }

    $ok = $count -ge $item.MinFiles
    if ($ok) { $complete++ } else { $missing++ }

    $status = if ($ok) { "PASS" } else { "MISS" }
    $fg     = if ($ok) { "Green" } else { "Red" }

    Write-Host ("[{0}] {1,-45} {2,4} files (min {3})" -f $status, $item.Title, $count, $item.MinFiles) -ForegroundColor $fg

    if (-not $ok -and $count -gt 0) {
        foreach ($f in $files) {
            Write-Host ("       -> {0}" -f $f.Name) -ForegroundColor Gray
        }
    }

    $results += @{
        id            = $item.Id
        title         = $item.Title
        directory     = $dirPath
        requiredFiles = $item.MinFiles
        actualFiles   = $count
        complete      = $ok
    }
}

# ---- summary ----
Write-Host ""
$summaryFg = if ($missing -eq 0) { "Green" } else { "Yellow" }
Write-Host ("Complete: {0}/{1}  Missing: {2}" -f $complete, $total, $missing) -ForegroundColor $summaryFg

if ($missing -eq 0) {
    Write-Host "All field evidence collected! PASS" -ForegroundColor Green
    exit 0
} else {
    Write-Host ""
    Write-Host "Missing evidence items:" -ForegroundColor Yellow
    foreach ($r in $results) {
        if (-not $r.complete) {
            Write-Host ("  - {0}: need at least {1} file(s) in {2}" -f $r.title, $r.requiredFiles, $r.directory) -ForegroundColor Yellow
        }
    }
    if ($RequireComplete) {
        Write-Host ""
        Write-Host "RequireComplete mode: FAIL (exit 1)" -ForegroundColor Red
        exit 1
    } else {
        Write-Host ""
        Write-Host "Run with -RequireComplete to enforce strict check." -ForegroundColor Gray
        exit 0
    }
}
