# serial-monitor.ps1 — Connect to QEMU UART0 TCP socket, display console + telemetry
# Usage: .\scripts\serial-monitor.ps1 [-Port 5555]
param(
    [int]$Port = 5555,
    [switch]$Decode     # Try to decode frame protocol
)

$ErrorActionPreference = "Stop"

Write-Host "=== XIAO Serial Monitor (tcp://127.0.0.1:$Port) ===" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop`n" -ForegroundColor DarkGray

$client = New-Object System.Net.Sockets.TcpClient
try {
    $client.Connect("127.0.0.1", $Port)
    Write-Host "[OK] Connected" -ForegroundColor Green

    $stream = $client.GetStream()
    $buffer = New-Object byte[] 4096
    $total = 0

    # Frame decoder state (if -Decode)
    $frameBuf = New-Object System.Collections.Generic.List[byte]

    while ($true) {
        if ($stream.DataAvailable) {
            $n = $stream.Read($buffer, 0, $buffer.Length)
            $total += $n

            if ($Decode) {
                # Add to frame buffer, try to extract frames
                for ($i = 0; $i -lt $n; $i++) { $frameBuf.Add($buffer[$i]) }
                # Look for SOF (0xA5)
                while ($frameBuf.Count -ge 6) {
                    if ($frameBuf[0] -eq 0xA5) {
                        $len = $frameBuf[1]
                        $type = $frameBuf[2]
                        $total_frame = 4 + $len + 1
                        if ($frameBuf.Count -ge $total_frame) {
                            # Extract frame
                            $payload = $frameBuf.GetRange(4, $len).ToArray()
                            # Display based on type
                            switch ($type) {
                                0x01 { Write-Host "[IMU ] $($payload.Length)B" -ForegroundColor Cyan }
                                0x03 { Write-Host "[EUL ] $($payload.Length)B" -ForegroundColor Green }
                                0x04 { Write-Host "[QUAT] $($payload.Length)B" -ForegroundColor Yellow }
                                0x05 { Write-Host "[MOT ] $($payload.Length)B" -ForegroundColor Magenta }
                                0x7F { Write-Host "[TXT ] $([Text.Encoding]::ASCII.GetString($payload))" -ForegroundColor White }
                                default { Write-Host "[0x{0:X2}] {1}B" -f $type, $len }
                            }
                            $frameBuf.RemoveRange(0, $total_frame)
                        } else { break }
                    } else {
                        $frameBuf.RemoveAt(0)
                    }
                }
            } else {
                # Raw text mode
                $text = [Text.Encoding]::ASCII.GetString($buffer, 0, $n)
                Write-Host -NoNewline $text
            }
        }
        Start-Sleep -Milliseconds 50
    }
} catch [System.Management.Automation.PipelineStoppedException] {
    # Ctrl+C
} catch {
    Write-Host "`n[ERR] $($_.Exception.Message)" -ForegroundColor Red
} finally {
    $client.Close()
    Write-Host "`n[OK] Disconnected ($total bytes received)" -ForegroundColor Green
}
