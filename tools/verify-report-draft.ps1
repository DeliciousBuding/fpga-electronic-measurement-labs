param(
  [string]$ReportDir = "",
  [string]$ReportMarkdown = ""
)

$ErrorActionPreference = "Stop"

function Assert-File {
  param(
    [string]$Path,
    [int64]$MinBytes = 1
  )

  if (!(Test-Path -LiteralPath $Path)) {
    throw "Required report artifact is missing: $Path"
  }
  $file = Get-Item -LiteralPath $Path
  if ($file.Length -lt $MinBytes) {
    throw "Report artifact is unexpectedly small: $Path ($($file.Length) bytes)"
  }
  return $file
}

function Assert-TextContains {
  param(
    [string]$Text,
    [string]$Pattern,
    [string]$Name
  )

  if ($Text -notmatch [Regex]::Escape($Pattern)) {
    throw "$Name does not contain required text: $Pattern"
  }
}

function Invoke-ExternalText {
  param(
    [string]$Tool,
    [string[]]$Arguments
  )

  $cmd = Get-Command $Tool -ErrorAction SilentlyContinue
  if (!$cmd) {
    throw "Required tool not found: $Tool"
  }
  $output = & $cmd.Source @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Tool $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
  }
  return ($output -join "`n")
}

function Find-ReportMarkdown {
  param([string]$Root)

  $candidates = Get-ChildItem -LiteralPath $Root -Recurse -Filter "*RGB*.md" -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Name -notlike "*check*" -and
      $_.Length -gt 15000 -and
      (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8) -match "WebVisualQA"
    } |
    Sort-Object Length -Descending

  if (!$candidates -or $candidates.Count -eq 0) {
    throw "Could not discover the RGB report Markdown under: $Root"
  }
  return $candidates[0].FullName
}

$searchRoot = Join-Path $env:USERPROFILE "Documents"
if ($ReportDir) {
  $searchRoot = (Resolve-Path -LiteralPath $ReportDir).Path
}

if (!$ReportMarkdown) {
  $ReportMarkdown = Find-ReportMarkdown -Root $searchRoot
}

$markdownPath = (Resolve-Path -LiteralPath $ReportMarkdown).Path
$resolvedReportDir = Split-Path -Parent $markdownPath
$reportBaseName = [IO.Path]::GetFileNameWithoutExtension($markdownPath)
$docxCandidates = Get-ChildItem -LiteralPath $resolvedReportDir -Filter "$reportBaseName*.docx" |
  Sort-Object LastWriteTime -Descending
if (!$docxCandidates -or $docxCandidates.Count -eq 0) {
  throw "Could not discover a DOCX draft beside the report."
}
$docxPath = $docxCandidates[0].FullName
$pdfCandidates = Get-ChildItem -LiteralPath $resolvedReportDir -Filter "$reportBaseName*.pdf" |
  Sort-Object LastWriteTime -Descending
if (!$pdfCandidates -or $pdfCandidates.Count -eq 0) {
  throw "Could not discover a PDF draft beside the report."
}
$pdfPath = $pdfCandidates[0].FullName
$checklistCandidates = Get-ChildItem -LiteralPath $resolvedReportDir -Filter "*RGB*.md" |
  Where-Object {
    $_.FullName -ne $markdownPath -and
    $_.Length -lt 8000 -and
    (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8) -match "DOCX" -and
    (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8) -match "PDF"
  } |
  Sort-Object Length
if (!$checklistCandidates -or $checklistCandidates.Count -eq 0) {
  throw "Could not discover the submission checklist beside the report."
}
$checklistPath = $checklistCandidates[0].FullName

$markdownFile = Assert-File -Path $markdownPath -MinBytes 10000
$docxFile = Assert-File -Path $docxPath -MinBytes 100000
$pdfFile = Assert-File -Path $pdfPath -MinBytes 100000
$checklistFile = Assert-File -Path $checklistPath -MinBytes 1000

if ($docxFile.LastWriteTime -lt $markdownFile.LastWriteTime) {
  throw "DOCX draft is older than the Markdown report. Re-export DOCX: $docxPath"
}
if ($pdfFile.LastWriteTime -lt $markdownFile.LastWriteTime) {
  throw "PDF draft is older than the Markdown report. Re-export PDF: $pdfPath"
}

$markdown = Get-Content -LiteralPath $markdownPath -Raw -Encoding UTF8
$checklist = Get-Content -LiteralPath $checklistPath -Raw -Encoding UTF8

$requiredMarkdownText = @(
  "61/61 PASS",
  "WebVisualQA",
  "App/Web",
  "CH9143 RGB Controller",
  "field-evidence",
  "RequireFieldEvidence",
  "SignalTap",
  "BLE",
  "ADB",
  "APK",
  "images/web-visual-qa"
)
foreach ($text in $requiredMarkdownText) {
  Assert-TextContains -Text $markdown -Pattern $text -Name "Markdown report"
}

$requiredChecklistText = @(
  "DOCX",
  "PDF",
  "WebVisualQA",
  "BLE",
  "SignalTap",
  "field-evidence",
  "61/61 PASS"
)
foreach ($text in $requiredChecklistText) {
  Assert-TextContains -Text $checklist -Pattern $text -Name "Submission checklist"
}

$imageMatches = @()
foreach ($line in Get-Content -LiteralPath $markdownPath -Encoding UTF8) {
  if ($line -match '!\[[^\]]*\]\((?<path>[^)]+\.png)\)') {
    $imageMatches += $Matches["path"]
  }
}
if ($imageMatches.Count -lt 6) {
  throw "Expected at least 6 PNG image references in Markdown report, found $($imageMatches.Count)."
}

$missingImages = @()
foreach ($imageMatch in $imageMatches) {
  $relativeImagePath = $imageMatch -replace '/', '\'
  $imagePath = Join-Path $resolvedReportDir $relativeImagePath
  if (!(Test-Path -LiteralPath $imagePath)) {
    $missingImages += $imagePath
  }
}
if ($missingImages.Count -gt 0) {
  throw "Markdown report references missing images:`n$($missingImages -join "`n")"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($docxPath)
try {
  $mediaEntries = @($zip.Entries | Where-Object { $_.FullName -like "word/media/*" })
  if ($mediaEntries.Count -lt 6) {
    throw "DOCX draft should embed at least 6 images, found $($mediaEntries.Count)."
  }
} finally {
  $zip.Dispose()
}

$docxText = Invoke-ExternalText -Tool "pandoc" -Arguments @($docxPath, "-t", "plain")
foreach ($text in @("App/Web", "61/61", "20260608", "CH9143 RGB Controller", "field-evidence")) {
  Assert-TextContains -Text $docxText -Pattern $text -Name "DOCX draft"
}

$pdfInfo = Invoke-ExternalText -Tool "pdfinfo" -Arguments @($pdfPath)
$pagesMatch = [Regex]::Match($pdfInfo, 'Pages:\s+(?<pages>\d+)')
if (!$pagesMatch.Success) {
  throw "Could not read PDF page count from pdfinfo output."
}
$pages = [int]$pagesMatch.Groups["pages"].Value
if ($pages -lt 8) {
  throw "PDF draft has too few pages: $pages"
}

$pdfText = Invoke-ExternalText -Tool "pdftotext" -Arguments @($pdfPath, "-")
foreach ($text in @("App/Web", "61/61", "20260608", "CH9143 RGB Controller", "field-evidence")) {
  Assert-TextContains -Text $pdfText -Pattern $text -Name "PDF draft"
}

Write-Host "Report draft verification passed."
Write-Host "Markdown: $markdownPath"
Write-Host "Checklist: $($checklistFile.FullName)"
Write-Host "DOCX: $docxPath ($($docxFile.Length) bytes, embedded images >= 6)"
Write-Host "PDF: $pdfPath ($($pdfFile.Length) bytes, pages=$pages)"
Write-Host "Image references checked: $($imageMatches.Count)"
