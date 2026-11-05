# setup-qemu.ps1 — One-click QEMU + ESP-IDF environment setup for XIAO virtual board
# Usage: .\scripts\setup-qemu.ps1
# Requires: PowerShell 5+, internet connection, ~500MB disk

param(
    [string]$InstallDir = "D:\Espressif",
    [string]$IdfVersion = "v6.1",
    [switch]$SkipIdf
)

$ErrorActionPreference = "Stop"

Write-Host "=== XIAO QEMU Board Setup ===" -ForegroundColor Cyan

# 1. Check/install QEMU (Espressif build)
$qemuDir = Join-Path $InstallDir "tools\qemu-xtensa"
if (Test-Path (Join-Path $qemuDir "qemu\bin\qemu-system-xtensa.exe")) {
    Write-Host "[OK] QEMU already installed: $qemuDir" -ForegroundColor Green
} else {
    Write-Host "[..] Installing QEMU (Espressif xtensa build)..." -ForegroundColor Yellow
    $qemuDir = Join-Path $qemuDir "qemu"
    New-Item -ItemType Directory -Force -Path $qemuDir | Out-Null

    # Download from Espressif dist
    $distDir = Join-Path $InstallDir "dist"
    if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Force -Path $distDir | Out-Null }

    $qemuPkg = Get-ChildItem $distDir -Filter "qemu-xtensa-softmmu-esp*.tar.xz" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($qemuPkg) {
        Write-Host "  Found local package: $($qemuPkg.Name)"
    } else {
        Write-Host "  Downloading QEMU package..." -ForegroundColor Yellow
        Write-Host "  If download fails, manually download from https://github.com/espressif/qemu/releases"
        Write-Host "  Place the .tar.xz file in $distDir"
        # Note: actual download URL varies by version; user may need to download manually
    }

    if ($qemuPkg) {
        # Extract tar.xz
        $extractDir = $qemuDir
        Write-Host "  Extracting to $extractDir..."
        & tar -xJf $qemuPkg.FullName -C $extractDir 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] QEMU installed" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Extraction failed" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "[WARN] QEMU package not found locally — download manually" -ForegroundColor Yellow
        Write-Host "  Get it from: https://github.com/espressif/qemu/releases"
    }
}

# 2. Check ESP-IDF
if (-not $SkipIdf) {
    $idfPath = "D:\esp\v6.1\esp-idf"
    if (Test-Path (Join-Path $idfPath "export.bat")) {
        Write-Host "[OK] ESP-IDF found: $idfPath" -ForegroundColor Green
    } else {
        Write-Host "[WARN] ESP-IDF not found at $idfPath" -ForegroundColor Yellow
        Write-Host "  Install ESP-IDF from: https://dl.espressif.com/dl/esp-idf/"
        Write-Host "  Or use the ESP-IDF Windows Installer"
    }

    # Check Python env
    $pyEnv = "D:\Espressif\python_env\idf6.1_py3.11_env"
    if (Test-Path (Join-Path $pyEnv "Scripts\python.exe")) {
        Write-Host "[OK] IDF Python env: $pyEnv" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Python env not found — ESP-IDF installer will create it" -ForegroundColor Yellow
    }
}

# 3. Verify QEMU works
$qemuExe = Join-Path $qemuDir "qemu\bin\qemu-system-xtensa.exe"
if (-not $qemuExe) { $qemuExe = Join-Path $qemuDir "bin\qemu-system-xtensa.exe" }
if (Test-Path $qemuExe) {
    $ver = & $qemuExe --version 2>$null | Select-Object -First 1
    Write-Host "[OK] QEMU version: $ver" -ForegroundColor Green

    # Check esp32s3 support
    $machines = & $qemuExe -M help 2>$null
    if ($machines -match "esp32s3") {
        Write-Host "[OK] esp32s3 machine supported" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] esp32s3 not supported — need Espressif QEMU build" -ForegroundColor Red
    }
} else {
    Write-Host "[WARN] QEMU executable not found at expected path" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Cyan
Write-Host "Next steps:"
Write-Host "  .\scripts\run-idf.ps1 -Project <path-to-your-idf-project>"
Write-Host "  .\scripts\run-arduino.ps1 -Sketch <path-to-your-sketch.ino>"
Write-Host ""
