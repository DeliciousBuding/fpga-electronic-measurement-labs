param(
    [switch]$Compile
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$Task2Root = Resolve-Path (Join-Path $Root '..')
$FsmDir = Join-Path $Task2Root 'task2-2-fsm-sim'
$ModelSim = 'C:\Program Files\ModelSim\win64'
$License = 'C:\Program Files\ModelSim\win64\LICENSE.TXT'
$Quartus = 'C:\altera_lite\25.1std\quartus\bin64'

function Assert-Contains {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Message
    )
    $hit = Select-String -LiteralPath $Path -Pattern $Pattern -SimpleMatch -Quiet
    if (-not $hit) {
        throw $Message
    }
}

function Run-ModelSim {
    param(
        [string]$WorkDir,
        [string[]]$Sources,
        [string]$Top,
        [string]$PassText
    )

    Push-Location $WorkDir
    $lib = "work_preflight_$Top"
    try {
        if (Test-Path $lib) { Remove-Item -Recurse -Force $lib }
        & "$ModelSim\vlib.exe" $lib | Out-Host
        & "$ModelSim\vlog.exe" -work $lib @Sources | Out-Host
        $log = & "$ModelSim\vsim.exe" -c "$lib.$Top" -do 'run -all; quit -f' 2>&1
        $log | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "ModelSim failed for $Top"
        }
        if (($log -join "`n") -notmatch [regex]::Escape($PassText)) {
            throw "Missing pass marker for $Top`: $PassText"
        }
    } finally {
        if (Test-Path $lib) { Remove-Item -Recurse -Force $lib -ErrorAction SilentlyContinue }
        Pop-Location
    }
}

Write-Host '== Task2 preflight =='

if (-not (Test-Path "$ModelSim\vsim.exe")) {
    throw "ModelSim SE not found: $ModelSim"
}
if (-not (Test-Path $License)) {
    throw "ModelSim license file not found: $License"
}

$env:LM_LICENSE_FILE = $License
Remove-Item Env:SALT_LICENSE_FILE -ErrorAction SilentlyContinue
Remove-Item Env:SALT_LICENSE_SERVER -ErrorAction SilentlyContinue

$qsf = Join-Path $Root 'task2-1.qsf'
Assert-Contains $qsf 'set_location_assignment PIN_B11 -to rx_din' 'QSF rx_din must be PIN_B11 for current PMOD insertion.'
Assert-Contains $qsf 'set_location_assignment PIN_D6 -to tx_dout' 'QSF tx_dout must be PIN_D6 for current PMOD insertion.'

Write-Host 'Pin check passed: rx_din=PIN_B11, tx_dout=PIN_D6'
Write-Host "ModelSim: $ModelSim"
Write-Host "LM_LICENSE_FILE: $env:LM_LICENSE_FILE"

Run-ModelSim `
    -WorkDir $FsmDir `
    -Sources @('dual_layer_fsm.v', 'tb_dual_layer_fsm.v') `
    -Top 'tb_dual_layer_fsm' `
    -PassText '=== ALL FSM TESTS PASSED ==='

Run-ModelSim `
    -WorkDir $Root `
    -Sources @('src/uart_loopback_top.v', 'sim/tb_uart_rx.v') `
    -Top 'tb_uart_rx' `
    -PassText '=== ALL TESTS PASSED ==='

if ($Compile) {
    if (-not (Test-Path "$Quartus\quartus_sh.exe")) {
        throw "Quartus not found: $Quartus"
    }
    Push-Location $Root
    try {
        & "$Quartus\quartus_sh.exe" --flow compile task2-1 | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw 'Quartus compile failed.'
        }
    } finally {
        Pop-Location
    }
}

Write-Host 'PRE_FLIGHT_OK'
