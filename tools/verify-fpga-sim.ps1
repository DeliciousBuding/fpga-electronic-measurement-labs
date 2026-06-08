param(
  [string]$OutDir = "$PSScriptRoot\..\artifacts\fpga-sim"
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
  throw "$Name not found. Add ModelSim/Questa win64 directory to PATH."
}

$repoRoot = Resolve-Path "$PSScriptRoot\.."
$projectRoot = Join-Path $repoRoot "final-rgb-controller"
if (!(Test-Path -LiteralPath $projectRoot)) {
  throw "FPGA project directory not found: $projectRoot"
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runDir = Join-Path $OutDir $stamp
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$resolvedRunDir = (Resolve-Path -LiteralPath $runDir).Path
$transcript = Join-Path $resolvedRunDir "modelsim-transcript.log"
$doFile = Join-Path $resolvedRunDir "run-headless.do"

$vlog = Resolve-Tool "vlog" @("C:\Program Files\ModelSim\win64\vlog.exe")
$vsim = Resolve-Tool "vsim" @("C:\Program Files\ModelSim\win64\vsim.exe")

$doLines = @(
  "transcript file ""$($transcript -replace '\\', '/')""",
  "if {[file exists work]} { vdel -lib work -all }",
  "vlib work",
  "vlog src/uart_tx_byte.v",
  "vlog src/uart_rx_byte.v",
  "vlog src/cmd_parser.v",
  "vlog src/breath_engine.v",
  "vlog src/flow_engine.v",
  "vlog src/gradient_engine.v",
  "vlog src/scene_store.v",
  "vlog src/ws2812_driver.v",
  "vlog src/rgb_controller_top.v",
  "vlog sim/tb_rgb_controller.v",
  "vlog sim/tb_ws2812_driver.v",
  "vsim -c -voptargs=""+acc"" work.tb_rgb_controller",
  "onfinish stop",
  "run -all",
  "quit -sim",
  "vsim -c -voptargs=""+acc"" work.tb_ws2812_driver",
  "onfinish stop",
  "run -all",
  "quit -sim",
  "quit -f"
)
$doLines | Set-Content -Encoding ASCII -Path $doFile

Push-Location $projectRoot
try {
  & $vsim -c -do $doFile
  if ($LASTEXITCODE -ne 0) {
    throw "ModelSim failed with exit code $LASTEXITCODE. Transcript: $transcript"
  }
} finally {
  Pop-Location
}

if (!(Test-Path -LiteralPath $transcript)) {
  throw "ModelSim transcript not found: $transcript"
}

$text = Get-Content -LiteralPath $transcript -Raw
if ($text -notmatch "ALL\s+18\s+TESTS\s+PASSED") {
  throw "FPGA simulation did not report ALL 18 TESTS PASSED. Transcript: $transcript"
}
if ($text -notmatch "WS2812\s+TIMING\s+TEST\s+PASSED") {
  throw "FPGA simulation did not report WS2812 TIMING TEST PASSED. Transcript: $transcript"
}
if ($text -match "\[ERROR\]") {
  throw "FPGA simulation transcript contains [ERROR]. Transcript: $transcript"
}

Write-Host "FPGA simulation passed: ALL 18 TESTS PASSED + WS2812 TIMING TEST PASSED"
Write-Host "Transcript: $transcript"
