param(
  [string]$ReportDir = "",
  [string]$TexFile = ""
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

function Invoke-ExternalText {
  param(
    [string]$Tool,
    [string[]]$Arguments,
    [string]$WorkingDirectory = ""
  )

  $cmd = Get-Command $Tool -ErrorAction SilentlyContinue
  if (!$cmd) {
    throw "Required tool not found: $Tool"
  }

  if ($WorkingDirectory) {
    Push-Location $WorkingDirectory
  }
  try {
    $output = & $cmd.Source @Arguments
    if ($LASTEXITCODE -ne 0) {
      throw "$Tool $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
    return ($output -join "`n")
  } finally {
    if ($WorkingDirectory) {
      Pop-Location
    }
  }
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

function Assert-TextNotMatches {
  param(
    [string]$Text,
    [string]$Pattern,
    [string]$Name
  )

  $match = [Regex]::Match($Text, $Pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if ($match.Success) {
    throw "$Name contains forbidden text: $($match.Value)"
  }
}

function Resolve-ReportImage {
  param(
    [string]$ReportRoot,
    [string]$ImageName
  )

  $candidates = @(
    (Join-Path $ReportRoot $ImageName),
    (Join-Path $ReportRoot (Join-Path "images" $ImageName))
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }
  $imagesRoot = Join-Path $ReportRoot "images"
  if (Test-Path -LiteralPath $imagesRoot) {
    $recursive = Get-ChildItem -LiteralPath $imagesRoot -Recurse -File -Filter (Split-Path -Leaf $ImageName) -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
    if ($recursive) {
      return $recursive.FullName
    }
  }
  throw "Report image reference is missing: $ImageName"
}

function Assert-PortraitImage {
  param([string]$Path)

  Add-Type -AssemblyName System.Drawing
  $image = [System.Drawing.Image]::FromFile($Path)
  try {
    if ($image.Height -le $image.Width) {
      throw "Expected portrait/mobile screenshot, got $($image.Width)x$($image.Height): $Path"
    }
    if ($image.Width -lt 250 -or $image.Height -lt 500) {
      throw "Mobile screenshot is too small: $($image.Width)x$($image.Height): $Path"
    }
  } finally {
    $image.Dispose()
  }
}

if (!$TexFile) {
  $searchRoot = if ($ReportDir) {
    (Resolve-Path -LiteralPath $ReportDir).Path
  } else {
    Join-Path $env:USERPROFILE "Documents"
  }
  $texCandidates = Get-ChildItem -LiteralPath $searchRoot -Recurse -Filter "*RGB*TeX*.tex" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "*TeX*" } |
    Sort-Object LastWriteTime -Descending
  if (!$texCandidates -or $texCandidates.Count -eq 0) {
    throw "Could not discover the TeX report under: $searchRoot"
  }
  $TexFile = $texCandidates[0].FullName
} elseif ($ReportDir) {
  $ReportDir = (Resolve-Path -LiteralPath $ReportDir).Path
}

$texPath = (Resolve-Path -LiteralPath $TexFile).Path
$texFile = Assert-File -Path $texPath -MinBytes 10000
$reportRoot = Split-Path -Parent $texPath
$texBaseName = [IO.Path]::GetFileNameWithoutExtension($texPath)
$pdfPath = Join-Path $reportRoot "$texBaseName.pdf"

Invoke-ExternalText -Tool "xelatex" `
  -Arguments @("-interaction=nonstopmode", "-halt-on-error", (Split-Path -Leaf $texPath)) `
  -WorkingDirectory $reportRoot | Out-Null

$pdfFile = Assert-File -Path $pdfPath -MinBytes 100000
if ($pdfFile.LastWriteTime -lt $texFile.LastWriteTime) {
  throw "PDF is older than the TeX source after compilation: $pdfPath"
}

$tex = Get-Content -LiteralPath $texPath -Raw -Encoding UTF8
foreach ($required in @(
    "hardware-photo-overview-v4.png",
    "hardware-photo-ledmap-v4.png",
    "mobile-led.png",
    "mobile-effect.png",
    "mobile-scene.png",
    "mobile-settings.png",
    "C301",
    "CH9143",
    "WS2812",
    "Flutter",
    "ModelSim",
    "Quartus",
    "APK",
    "SOF"
  )) {
  Assert-TextContains -Text $tex -Pattern $required -Name "TeX report"
}

$imageRefs = [Regex]::Matches($tex, '\\includegraphics(?:\[[^\]]*\])?\{(?<path>[^}]+)\}') |
  ForEach-Object { $_.Groups["path"].Value }
if ($imageRefs.Count -lt 6) {
  throw "Expected at least 6 included graphics in TeX report, found $($imageRefs.Count)."
}
foreach ($imageRef in $imageRefs) {
  [void](Resolve-ReportImage -ReportRoot $reportRoot -ImageName $imageRef)
}
foreach ($mobileImage in @("mobile-led.png", "mobile-effect.png", "mobile-scene.png", "mobile-settings.png")) {
  Assert-PortraitImage -Path (Resolve-ReportImage -ReportRoot $reportRoot -ImageName $mobileImage)
}

$pdfInfo = Invoke-ExternalText -Tool "pdfinfo" -Arguments @($pdfPath)
$pagesMatch = [Regex]::Match($pdfInfo, 'Pages:\s+(?<pages>\d+)')
if (!$pagesMatch.Success) {
  throw "Could not read PDF page count from pdfinfo output."
}
$pages = [int]$pagesMatch.Groups["pages"].Value
if ($pages -lt 1 -or $pages -gt 6) {
  throw "PDF page count must be 1-6 pages for this assignment, got $pages"
}

$pdfText = Invoke-ExternalText -Tool "pdftotext" -Arguments @($pdfPath, "-")
foreach ($required in @("C301", "CH9143", "WS2812", "Flutter", "ModelSim", "Quartus", "APK", "SOF")) {
  Assert-TextContains -Text $pdfText -Pattern $required -Name "PDF report"
}

$forbiddenTerms = @(
  "D:/Code",
  "D:\",
  "C:/Users",
  "C:\Users",
  "adb",
  "jtag",
  "field-evidence",
  "mobile-effect-music",
  ([string]([char[]](0x5b66, 0x751f, 0x59d3, 0x540d))), # student name
  ([string]([char[]](0x5b66, 0x53f7))), # student id
  ([string]([char[]](0x672a, 0x5b9e, 0x73b0))), # not implemented
  ([string]([char[]](0x5f85, 0x8865, 0x5145))), # pending fill
  ([string]([char[]](0x706f, 0x5e26))), # LED strip
  ([string]([char[]](0x7ea2, 0x7ea2))), # red red
  ([string]([char[]](0x5b89, 0x88c5, 0x5931, 0x8d25))), # install failed
  ([string]([char[]](0x4ece, 0x4e0b, 0x5f80, 0x4e0a))) # bottom-up
)
$forbiddenPattern = ($forbiddenTerms | ForEach-Object { [Regex]::Escape($_) }) -join "|"
Assert-TextNotMatches -Text $pdfText -Pattern $forbiddenPattern -Name "PDF report"

Write-Host "Report draft verification passed."
Write-Host "TeX: $texPath"
Write-Host "PDF: $pdfPath ($($pdfFile.Length) bytes, pages=$pages)"
Write-Host "Image references checked: $($imageRefs.Count)"
