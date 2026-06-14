<#
.SYNOPSIS
    C301 RGB 彩灯蓝牙控制器 — 现场证据完整性校验

.DESCRIPTION
    检查 field-evidence/ 下 6 类现场证据是否齐全。
    默认非严格模式（列出缺失项），-RequireComplete 严格模式（缺一项则 exit 1）。

.PARAMETER RequireComplete
    严格模式：任何一项缺失则退出码 1。

.PARAMETER EvidenceDir
    现场证据根目录，默认自动检测。

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
        "$PSScriptRoot\..\field-evidence",
        "$env:USERPROFILE\Documents\个人文件\03 课程资料\当前学期\电子测量\综合实验\field-evidence"
    )
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

Write-Host "`n=== C301 Field Evidence Verifier ===" -ForegroundColor Cyan
Write-Host "Evidence dir: $EvidenceDir`n"

# ---- evidence definitions ----
$items = @(
    @{
        Id       = "ble-scan"
        Title    = "BLE scan screenshot"
        Dir      = "01-ble-scan"
        MinFiles = 1
        Patterns = @("*.png", "*.jpg", "*.jpeg")
    },
    @{
        Id       = "ble-connect"
        Title    = "BLE connection screenshot"
        Dir      = "02-ble-connect"
        MinFiles = 1
        Patterns = @("*.png", "*.jpg", "*.jpeg")
    },
    @{
        Id       = "led-effects"
        Title    = "LED effect photos"
        Dir      = "03-led-effects"
        MinFiles = 3
        Patterns = @("*.png", "*.jpg", "*.jpeg")
    },
    @{
        Id       = "serial-log"
        Title    = "Serial log"
        Dir      = "04-serial-log"
        MinFiles = 1
        Patterns = @("*.md", "*.txt", "*.png", "*.jpg", "*.jpeg")
    },
    @{
        Id       = "waveform"
        Title    = "SignalTap / oscilloscope waveform"
        Dir      = "05-waveform"
        MinFiles = 1
        Patterns = @("*.png", "*.jpg", "*.jpeg", "*.stp")
    },
    @{
        Id       = "cover-info"
        Title    = "Cover information"
        Dir      = "06-cover-info"
        MinFiles = 1
        Patterns = @("*.md", "*.txt")
    }
)

$total   = $items.Count
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
    $color  = if ($ok) { "Green" } else { "Red" }

    Write-Host ("[{0}] {1,-45} {2,4} files (min {3})" -f $status, $item.Title, $count, $item.MinFiles) -ForegroundColor $color

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
Write-Host ("Complete: {0}/{1}  Missing: {2}" -f $complete, $total, $missing) -ForegroundColor $(if ($missing -eq 0) { "Green" } else { "Yellow" })

if ($missing -eq 0) {
    Write-Host "All field evidence collected! ✅" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nMissing evidence items:" -ForegroundColor Yellow
    foreach ($r in $results) {
        if (-not $r.complete) {
            Write-Host ("  - {0}: need at least {1} file(s) in {2}" -f $r.title, $r.requiredFiles, $r.directory) -ForegroundColor Yellow
        }
    }
    if ($RequireComplete) {
        Write-Host "`nRequireComplete mode: exiting with code 1" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "`nRun with -RequireComplete to enforce strict check." -ForegroundColor Gray
        exit 0
    }
}
