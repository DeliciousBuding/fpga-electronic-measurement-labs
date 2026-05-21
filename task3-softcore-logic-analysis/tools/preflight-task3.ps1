param(
    [switch]$Compile
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$ModelSim = 'C:\Program Files\ModelSim\win64'
$License = 'C:\Program Files\ModelSim\win64\LICENSE.TXT'
$Quartus = 'C:\altera_lite\25.1std\quartus\bin64'

Write-Host '== Task3 preflight =='

if (-not (Test-Path "$ModelSim\vsim.exe")) {
    throw "ModelSim SE not found: $ModelSim"
}
if (-not (Test-Path $License)) {
    throw "ModelSim license file not found: $License"
}

$env:LM_LICENSE_FILE = $License
Remove-Item Env:SALT_LICENSE_FILE -ErrorAction SilentlyContinue
Remove-Item Env:SALT_LICENSE_SERVER -ErrorAction SilentlyContinue

Push-Location $Root
try {
    if (Test-Path work_task3) { Remove-Item -Recurse -Force work_task3 -ErrorAction SilentlyContinue }
    & "$ModelSim\vlib.exe" work_task3 | Out-Host
    & "$ModelSim\vlog.exe" -work work_task3 `
        +define+SIM `
        src/async_fifo.v `
        src/task3_dcfifo_ip.v `
        src/task3_pll_ip.v `
        src/task3_soft_modules.v `
        src/sdfifo_ctl.v `
        src/task3_top.v `
        sim/tb_async_fifo.v `
        sim/tb_sdfifo_ctl.v | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw 'ModelSim Task3 compile failed.'
    }

    $log1 = & "$ModelSim\vsim.exe" -c work_task3.tb_async_fifo -do 'run -all; quit -f' 2>&1
    $log1 | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw 'ModelSim async FIFO simulation failed.'
    }

    Start-Sleep -Seconds 1
    $log2 = & "$ModelSim\vsim.exe" -c work_task3.tb_sdfifo_ctl -do 'run -all; quit -f' 2>&1
    $log2 | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw 'ModelSim SDFIFO CTL simulation failed.'
    }

    $joined = (($log1 + $log2) -join "`n")
    if ($joined -notmatch '=== ASYNC FIFO TESTS PASSED ===') {
        throw 'Missing async FIFO pass marker.'
    }
    if ($joined -notmatch '=== SDFIFO CTL TESTS PASSED ===') {
        throw 'Missing SDFIFO CTL pass marker.'
    }

    if ($Compile) {
        if (-not (Test-Path "$Quartus\quartus_sh.exe")) {
            throw "Quartus not found: $Quartus"
        }
        & "$Quartus\quartus_sh.exe" --flow compile task3 | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw 'Quartus Task3 compile failed.'
        }
    }
} finally {
    Pop-Location
}

Write-Host 'TASK3_PRE_FLIGHT_OK'
