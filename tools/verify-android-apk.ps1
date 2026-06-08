param(
  [string]$Apk = "$PSScriptRoot\..\app\build\app\outputs\flutter-apk\app-release.apk",
  [string]$Pubspec = "$PSScriptRoot\..\app\pubspec.yaml",
  [string]$TargetAbi = "arm64-v8a",
  [int]$MaxReleaseApkMb = 35
)

$ErrorActionPreference = "Stop"

function Resolve-Aapt {
  $cmd = Get-Command aapt -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  $sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
  $candidate = Get-ChildItem -LiteralPath (Join-Path $sdk "build-tools") `
    -Recurse `
    -Filter "aapt.exe" `
    -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending |
    Select-Object -First 1
  if ($candidate) { return $candidate.FullName }
  throw "aapt not found. Install Android SDK build-tools or add aapt to PATH."
}

function Get-PubspecVersion {
  param([string]$Path)

  $text = [IO.File]::ReadAllText(
    (Resolve-Path -LiteralPath $Path),
    [Text.UTF8Encoding]::new($false)
  )
  $match = [Regex]::Match($text, "(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+(\d+)\s*$")
  if (!$match.Success) {
    throw "Could not parse version from pubspec: $Path"
  }
  return [PSCustomObject]@{
    Name = $match.Groups[1].Value
    Code = [int64]$match.Groups[2].Value
    Raw = "$($match.Groups[1].Value)+$($match.Groups[2].Value)"
  }
}

function Assert-NoZipEntry {
  param(
    [object[]]$Entries,
    [string]$Pattern,
    [string]$Reason
  )

  $matches = @($Entries | Where-Object { $_.FullName -like $Pattern })
  if ($matches.Count -gt 0) {
    $names = ($matches | Select-Object -First 10 -ExpandProperty FullName) -join ", "
    throw "$Reason Found: $names"
  }
}

function Test-EntryContainsAscii {
  param(
    [System.IO.Compression.ZipArchiveEntry]$Entry,
    [string[]]$Needles
  )

  $stream = $Entry.Open()
  try {
    $memory = [IO.MemoryStream]::new()
    try {
      $stream.CopyTo($memory)
      $text = [Text.Encoding]::GetEncoding(28591).GetString($memory.ToArray())
      foreach ($needle in $Needles) {
        if ($text.Contains($needle)) {
          return $needle
        }
      }
      return $null
    } finally {
      $memory.Dispose()
    }
  } finally {
    $stream.Dispose()
  }
}

$apkFile = Get-Item -LiteralPath $Apk
if (!$apkFile) {
  throw "APK not found: $Apk"
}
if ($apkFile.Length -lt 10000000) {
  throw "APK is unexpectedly small: $($apkFile.FullName) ($($apkFile.Length) bytes)"
}
$maxBytes = [int64]$MaxReleaseApkMb * 1024 * 1024
if ($apkFile.Length -gt $maxBytes) {
  throw "APK exceeds release size budget: $($apkFile.Length) bytes > $maxBytes bytes ($MaxReleaseApkMb MB)"
}

$pubspecVersion = Get-PubspecVersion -Path $Pubspec
$aapt = Resolve-Aapt
$badging = & $aapt dump badging $apkFile.FullName
if ($LASTEXITCODE -ne 0) {
  throw "aapt dump badging failed with exit code $LASTEXITCODE"
}
$packageLine = ($badging | Select-String -Pattern "^package:" | Select-Object -First 1).Line
if (!$packageLine) {
  throw "aapt badging output did not include package line."
}
$versionCodeMatch = [Regex]::Match($packageLine, "versionCode='(\d+)'")
$versionNameMatch = [Regex]::Match($packageLine, "versionName='([^']+)'")
if (!$versionCodeMatch.Success -or !$versionNameMatch.Success) {
  throw "Could not parse versionCode/versionName from package line: $packageLine"
}
$apkVersionCode = [int64]$versionCodeMatch.Groups[1].Value
$apkVersionName = $versionNameMatch.Groups[1].Value
if ($apkVersionCode -ne $pubspecVersion.Code) {
  throw "APK versionCode $apkVersionCode does not match pubspec $($pubspecVersion.Code). Rebuild release APK."
}
if ($apkVersionName -ne $pubspecVersion.Name) {
  throw "APK versionName $apkVersionName does not match pubspec $($pubspecVersion.Name). Rebuild release APK."
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($apkFile.FullName)
try {
  $entries = @($zip.Entries)
  Assert-NoZipEntry -Entries $entries -Pattern "assets/flutter_assets/kernel_blob.bin" -Reason "Release APK contains debug Dart kernel blob."
  Assert-NoZipEntry -Entries $entries -Pattern "assets/flutter_assets/vm_snapshot_data" -Reason "Release APK contains debug VM snapshot data."
  Assert-NoZipEntry -Entries $entries -Pattern "assets/flutter_assets/isolate_snapshot_data" -Reason "Release APK contains debug isolate snapshot data."

  $libApp = @($entries | Where-Object { $_.FullName -like "lib/*/libapp.so" })
  $libFlutter = @($entries | Where-Object { $_.FullName -like "lib/*/libflutter.so" })
  if ($libApp.Count -ne 1 -or $libApp[0].FullName -ne "lib/$TargetAbi/libapp.so") {
    throw "Expected libapp.so only under lib/$TargetAbi, found: $(($libApp.FullName) -join ', ')"
  }
  if ($libFlutter.Count -ne 1 -or $libFlutter[0].FullName -ne "lib/$TargetAbi/libflutter.so") {
    throw "Expected libflutter.so only under lib/$TargetAbi, found: $(($libFlutter.FullName) -join ', ')"
  }

  $requiredEntries = @(
    "classes.dex",
    "lib/$TargetAbi/libapp.so",
    "lib/$TargetAbi/libflutter.so",
    "assets/flutter_assets/FontManifest.json",
    "assets/flutter_assets/AssetManifest.bin"
  )
  foreach ($entryName in $requiredEntries) {
    if (!$zip.GetEntry($entryName)) {
      throw "Release APK is missing required entry: $entryName"
    }
  }

  $forbiddenStrings = @(
    "CH9143 RGB Controller",
    "UART-FFF0-LED",
    "Debug sample only",
    "Load debug samples"
  )
  $scanEntries = @($entries | Where-Object {
      $_.Length -gt 0 -and
      $_.Length -lt 30000000 -and
      ($_.FullName -like "lib/*/libapp.so" -or $_.FullName -like "assets/flutter_assets/*")
    })
  foreach ($entry in $scanEntries) {
    $needle = Test-EntryContainsAscii -Entry $entry -Needles $forbiddenStrings
    if ($needle) {
      throw "Release APK contains forbidden debug/sample string '$needle' in $($entry.FullName)."
    }
  }
} finally {
  $zip.Dispose()
}

$sizeMb = [Math]::Round($apkFile.Length / 1MB, 2)
Write-Host "Android APK quality verification passed."
Write-Host "APK: $($apkFile.FullName)"
Write-Host "Size: $sizeMb MB / budget ${MaxReleaseApkMb} MB"
Write-Host "Version: $apkVersionName+$apkVersionCode"
Write-Host "Target ABI for Flutter native libs: $TargetAbi"
