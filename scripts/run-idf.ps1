# run-idf.ps1 — Build ESP-IDF project + boot in QEMU (no hardware needed)
# Usage: .\scripts\run-idf.ps1 -Project path\to\idf-project [-Port 5555] [-Seconds 30]
param(
    [Parameter(Mandatory=$true)][string]$Project,
    [int]$Port = 5555,
    [int]$Seconds = 30,
    [switch]$NoBuild,       # Skip build (use existing build-qemu)
    [switch]$KeepRunning    # Don't auto-kill QEMU after N seconds
)

$ErrorActionPreference = "Stop"

# Paths
$QEMU = "D:\Espressif\tools\qemu-xtensa\qemu\bin\qemu-system-xtensa.exe"
if (-not (Test-Path $QEMU)) { $QEMU = "D:\Espressif\tools\qemu-xtensa\bin\qemu-system-xtensa.exe" }
$IDF = "D:\esp\v6.1\esp-idf"
$PYENV = "D:\Espressif\python_env\idf6.1_py3.11_env"

# Verify
if (-not (Test-Path $QEMU)) { Write-Host "[ERR] QEMU not found. Run setup-qemu.ps1 first." -ForegroundColor Red; exit 1 }
if (-not (Test-Path "$Project\CMakeLists.txt")) { Write-Host "[ERR] Not an IDF project (no CMakeLists.txt): $Project" -ForegroundColor Red; exit 1 }

$buildDir = Join-Path $Project "build-qemu"
$flashBin = Join-Path $buildDir "qemu_flash.bin"
$efuseBin = Join-Path $buildDir "qemu_efuse.bin"

# 1. Build (dual macro: EXP_SIM for synthetic data, EXP_QEMU_UART for UART0 output)
if (-not $NoBuild -or -not (Test-Path $flashBin)) {
    Write-Host "[1/3] Building (dual macro: EXP_SIM=1 + EXP_QEMU_UART=1)..." -ForegroundColor Cyan
    Push-Location $Project
    cmd /c "set MSYSTEM=&& set IDF_PATH=$IDF&& set IDF_PYTHON_ENV_PATH=$PYENV&& call $IDF\export.bat >NUL && idf.py -B build-qemu -DEXP_SIM=1 -DEXP_QEMU_UART=1 build"
    $buildOk = ($LASTEXITCODE -eq 0)
    Pop-Location
    if (-not $buildOk) { Write-Host "[ERR] Build failed (exit=$LASTEXITCODE)" -ForegroundColor Red; exit 1 }
    Write-Host "[OK] Build succeeded" -ForegroundColor Green
} else {
    Write-Host "[SKIP] Build (using existing $buildDir)" -ForegroundColor DarkGray
}

# 2. Prepare flash image (merge bootloader + partition + app into single .bin)
Write-Host "[2/3] Preparing flash image..." -ForegroundColor Cyan
$pyExe = Join-Path $PYENV "Scripts\python.exe"
$flashArgs = Join-Path $buildDir "flash_args"
if (Test-Path $flashArgs) {
    & $pyExe -m esptool --chip=esp32s3 merge-bin --output="$flashBin" --pad-to-size=2MB "@$flashArgs" 2>$null
    # Generate minimal efuse
    $efuseContent = [byte[]]::new(1024)
    [IO.File]::WriteAllBytes($efuseBin, $efuseContent)
    Write-Host "[OK] Flash image: $flashBin (2MB)" -ForegroundColor Green
} else {
    Write-Host "[ERR] flash_args not found in $buildDir" -ForegroundColor Red; exit 1
}

# 3. Boot QEMU + serial monitor
Write-Host "[3/3] Booting QEMU (UART0 on port $Port)..." -ForegroundColor Cyan
$qemuProc = Start-Process -FilePath $QEMU -ArgumentList @(
    "-M", "esp32s3",
    "-nographic",
    "-serial", "tcp:127.0.0.1:$Port,server,nowait",
    "-serial", "null",
    "-display", "none",
    "-drive", "file=$flashBin,if=mtd,format=raw"
) -PassThru -NoNewWindow

Start-Sleep -Seconds 2

if ($KeepRunning) {
    Write-Host "[OK] QEMU running (PID=$($qemuProc.Id)). Connect serial: tcp://127.0.0.1:$Port" -ForegroundColor Green
    Write-Host "Kill: taskkill /PID $($qemuProc.Id) /F"
} else {
    # Monitor for N seconds
    Write-Host "Monitoring for $Seconds seconds..." -ForegroundColor Cyan
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $client.Connect("127.0.0.1", $Port)
        $stream = $client.GetStream()
        $buffer = New-Object byte[] 4096
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
            if ($stream.DataAvailable) {
                $n = $stream.Read($buffer, 0, $buffer.Length)
                $text = [Text.Encoding]::ASCII.GetString($buffer, 0, $n)
                Write-Host -NoNewline $text
            }
            Start-Sleep -Milliseconds 100
        }
    } catch {
        Write-Host "[WARN] Serial connect: $($_.Exception.Message)" -ForegroundColor Yellow
    } finally {
        $client.Close()
        if (-not $qemuProc.HasExited) { Stop-Process -Id $qemuProc.Id -Force }
    }
    Write-Host "`n[OK] Done ($Seconds seconds). QEMU killed." -ForegroundColor Green
}
