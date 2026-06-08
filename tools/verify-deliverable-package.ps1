param(
  [string]$Package = "",
  [string]$ExpectedSha256 = ""
)

$ErrorActionPreference = "Stop"

function Assert-File {
  param(
    [string]$Path,
    [int64]$MinBytes
  )

  if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Required deliverable file is missing: $Path"
  }
  $file = Get-Item -LiteralPath $Path
  if ($file.Length -lt $MinBytes) {
    throw "Deliverable file is too small: $Path ($($file.Length) bytes, expected >= $MinBytes)"
  }
  return $file
}

function Assert-Text {
  param(
    [string]$Text,
    [string]$Pattern,
    [string]$Name
  )

  if ($Text -notmatch [Regex]::Escape($Pattern)) {
    throw "$Name should contain '$Pattern'."
  }
}

function Get-RequiredByPattern {
  param(
    [string]$Directory,
    [string]$Pattern,
    [int64]$MinBytes
  )

  $matches = @(Get-ChildItem -LiteralPath $Directory -File -Filter $Pattern | Sort-Object Name)
  if ($matches.Count -ne 1) {
    throw "Expected exactly one file matching '$Pattern' in $Directory, found $($matches.Count)."
  }
  return Assert-File -Path $matches[0].FullName -MinBytes $MinBytes
}

function Get-SingleCandidate {
  param(
    [System.IO.FileInfo[]]$Files,
    [string]$Description
  )

  if ($Files.Count -ne 1) {
    throw "Expected exactly one $Description, found $($Files.Count)."
  }
  return $Files[0]
}

$repoRoot = Resolve-Path "$PSScriptRoot\.."
$deliverablesRoot = Join-Path $repoRoot "deliverables"
$pubspecPath = Join-Path $repoRoot "app\pubspec.yaml"
$pubspecVersionMatch = Select-String -LiteralPath $pubspecPath -Pattern '^version:\s*(?<version>\S+)' | Select-Object -First 1
if (!$pubspecVersionMatch) {
  throw "Could not read app version from $pubspecPath"
}
$expectedAppVersion = $pubspecVersionMatch.Matches[0].Groups["version"].Value

if (!$Package) {
  $latest = Get-ChildItem -LiteralPath $deliverablesRoot -File -Filter "*.zip" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if (!$latest) {
    throw "No deliverable package zip found under $deliverablesRoot"
  }
  $Package = $latest.FullName
}

$zipFile = Assert-File -Path $Package -MinBytes 1000000
$zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipFile.FullName).Hash.ToLowerInvariant()

if ($ExpectedSha256 -and ($zipHash -ne $ExpectedSha256.ToLowerInvariant())) {
  throw "Deliverable zip SHA256 mismatch. actual=$zipHash expected=$($ExpectedSha256.ToLowerInvariant())"
}

$handoffPath = Join-Path $repoRoot "docs\HANDOFF_2026-06-06.md"
if (Test-Path -LiteralPath $handoffPath) {
  $handoff = Get-Content -LiteralPath $handoffPath -Raw -Encoding UTF8
  $hashMatches = [Regex]::Matches($handoff, 'Release 附件 SHA256 为 `(?<hash>[0-9a-f]{64})`')
  if ($hashMatches.Count -gt 0) {
    $documentedHash = $hashMatches[$hashMatches.Count - 1].Groups["hash"].Value
    if ($documentedHash -ne $zipHash) {
      throw "Handoff release SHA256 does not match package. documented=$documentedHash actual=$zipHash"
    }
  }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("quartus-deliverable-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

try {
  Expand-Archive -LiteralPath $zipFile.FullName -DestinationPath $tempRoot -Force
  $roots = @(Get-ChildItem -LiteralPath $tempRoot -Directory)
  if ($roots.Count -ne 1) {
    throw "Deliverable zip should contain one top-level directory, found $($roots.Count)."
  }

  $packageRoot = $roots[0].FullName
  $readmeFile = Assert-File -Path (Join-Path $packageRoot "README.md") -MinBytes 500
  $shaFile = Assert-File -Path (Join-Path $packageRoot "SHA256SUMS.txt") -MinBytes 300
  $filesDir = Join-Path $packageRoot "files"
  if (!(Test-Path -LiteralPath $filesDir -PathType Container)) {
    throw "Deliverable zip is missing files directory: $filesDir"
  }

  $readmeBytes = [System.IO.File]::ReadAllBytes($readmeFile.FullName)
  $badControlBytes = @($readmeBytes | Where-Object { $_ -lt 32 -and $_ -notin @(9, 10, 13) })
  if ($badControlBytes.Count -gt 0) {
    throw "README.md contains unexpected control bytes."
  }

  $readme = Get-Content -LiteralPath $readmeFile.FullName -Raw -Encoding UTF8
  Assert-Text -Text $readme -Pattern "GitHub Release" -Name "README"
  Assert-Text -Text $readme -Pattern $expectedAppVersion -Name "README"
  Assert-Text -Text $readme -Pattern "No ADB" -Name "README"
  Assert-Text -Text $readme -Pattern "Field evidence is still 0/6 complete" -Name "README"

  $sof = Get-RequiredByPattern -Directory $filesDir -Pattern "*.sof" -MinBytes 100000
  $apk = Get-RequiredByPattern -Directory $filesDir -Pattern "*.apk" -MinBytes 10000000
  $pdf = Get-RequiredByPattern -Directory $filesDir -Pattern "*.pdf" -MinBytes 100000
  $docx = Get-RequiredByPattern -Directory $filesDir -Pattern "*.docx" -MinBytes 100000
  $markdownFiles = @(Get-ChildItem -LiteralPath $filesDir -File -Filter "*.md" | Where-Object { $_.Name -ne "local-evidence-manifest.md" })
  $reportMd = Get-SingleCandidate -Files @($markdownFiles | Where-Object { $_.Length -ge 10000 }) -Description "large Markdown report"
  $checklist = Get-SingleCandidate -Files @($markdownFiles | Where-Object { $_.Length -ge 1000 -and $_.Length -lt 10000 }) -Description "submission checklist Markdown"
  $manifestJson = Assert-File -Path (Join-Path $filesDir "local-evidence-manifest.json") -MinBytes 1000
  $manifestMd = Assert-File -Path (Join-Path $filesDir "local-evidence-manifest.md") -MinBytes 1000

  $shaLines = @(Get-Content -LiteralPath $shaFile.FullName -Encoding UTF8 | Where-Object { $_.Trim() })
  $files = @($sof, $apk, $pdf, $docx, $reportMd, $checklist, $manifestJson, $manifestMd)
  foreach ($file in $files) {
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
    $expectedLine = $null
    foreach ($line in $shaLines) {
      $parts = $line -split '\s+', 3
      if ($parts.Count -eq 3 -and $parts[0] -eq $actualHash -and [int64]$parts[1] -eq $file.Length -and $parts[2] -eq $file.Name) {
        $expectedLine = $line
        break
      }
    }
    if (!$expectedLine) {
      throw "SHA256SUMS does not match $($file.Name)."
    }
  }

  $manifest = Get-Content -LiteralPath $manifestJson.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($manifest.noDeviceEvidence -ne $true) {
    throw "Manifest should mark noDeviceEvidence=true."
  }
} finally {
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}

Write-Host "Deliverable package verification passed."
Write-Host "Package: $($zipFile.FullName)"
Write-Host "SHA256: $zipHash"
