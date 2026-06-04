# Serial demo for UART loopback test
param(
    [string]$Port = "COM4",
    [int]$BaudRate = 115200
)

$serial = New-Object System.IO.Ports.SerialPort
$serial.PortName = $Port
$serial.BaudRate = $BaudRate
$serial.DataBits = 8
$serial.Parity = [System.IO.Ports.Parity]::None
$serial.StopBits = [System.IO.Ports.StopBits]::One
$serial.ReadTimeout = 2000
$serial.Open()
Write-Host "Connected to $Port @ $BaudRate 8N1" -ForegroundColor Green
Write-Host ""
Write-Host "Commands: 0=Off  1=Red  2=Green  3=Blue  A/a=White  K1=U(0x55)"
Write-Host "Type 'q' to quit."
Write-Host ""

$reader = New-Object System.IO.Ports.SerialPort
# Only one SerialPort object needed — use timeout read

while ($true) {
    $key = [Console]::ReadKey($true)
    $ch = $key.KeyChar

    if ($ch -eq 'q') { break }

    # Write the character
    $serial.Write($ch.ToString())

    # Small delay then read echo
    Start-Sleep -Milliseconds 200
    try {
        $buf = New-Object byte[] 256
        $n = $serial.Read($buf, 0, $buf.Length)
        if ($n -gt 0) {
            $rxBytes = $buf[0..($n-1)]
            $rxHex = ($rxBytes | ForEach-Object { "0x{0:X2}" -f $_ }) -join " "
            $rxAscii = [System.Text.Encoding]::ASCII.GetString($rxBytes) -replace '[^\x20-\x7E]','.'
            Write-Host ("TX: '{0}'  =>  RX: {1}  [{2}]" -f $ch, $rxAscii, $rxHex) -ForegroundColor Cyan
        } else {
            Write-Host ("TX: '{0}'  =>  RX: (timeout)" -f $ch) -ForegroundColor Yellow
        }
    } catch {
        Write-Host ("TX: '{0}'  =>  RX: (error: {1})" -f $ch, $_.Exception.Message) -ForegroundColor Red
    }
}

$serial.Close()
$serial.Dispose()
Write-Host "Done." -ForegroundColor Green
