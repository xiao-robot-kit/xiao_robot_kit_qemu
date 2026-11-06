# XIAO QEMU Board — ESP32-S3 Virtual Hardware

> Run XIAO Robot Kit firmware in QEMU **without a physical board**.
> Currently: **ESP-IDF** programs. Arduino support is on the [Roadmap](#roadmap).

## What This Provides

| Component | Purpose | Status |
| --- | --- | --- |
| `scripts/setup-qemu.ps1` | One-click: install QEMU + ESP-IDF toolchain | ✅ shipped |
| `scripts/run-idf.ps1` | Build & run any ESP-IDF project in QEMU | ✅ shipped |
| `scripts/serial-monitor.ps1` | Connect to virtual UART0 (console + telemetry frames) | ✅ shipped |
| `docs/protocol-spec.md` | Full serial frame protocol spec | ✅ shipped |
| `docs/faq.md` | Common issues & solutions | ✅ shipped |
| `scripts/run-arduino.ps1` | Compile Arduino sketch & run in QEMU | ⏳ roadmap |
| `configs/` | QEMU machine configs (flash layout, efuse, UART routing) | ⏳ roadmap |
| `examples/` | Minimal IDF + Arduino examples (blink, IMU, motor) | ⏳ roadmap |

## Quick Start (5 minutes, no hardware needed)

### 1. Setup (once)

```powershell
git clone https://github.com/xiao-robot-kit/xiao_robot_kit_qemu.git
cd xiao_robot_kit_qemu
.\scripts\setup-qemu.ps1
```

Installs QEMU (Espressif build) + configures ESP-IDF v6.1 toolchain paths.

### 2. Run an ESP-IDF project

```powershell
.\scripts\run-idf.ps1 -Project path\to\your\idf-project
```

Compiles with dual macro (`-DEXP_SIM=1 -DEXP_QEMU_UART=1`) → merges flash image → boots QEMU → opens serial monitor.

> Arduino sketches: planned — see [Roadmap](#roadmap).

## Virtual Board Specs (QEMU esp32s3)

| Feature | Status |
| --- | --- |
| CPU | ESP32-S3 (dual-core Xtensa LX7) ✓ |
| Flash | 2MB (merge-bin from build output) ✓ |
| UART0 | Console + telemetry frames (TCP socket) ✓ |
| USB-Serial-JTAG | ❌ (QEMU limitation — use UART0 instead) |
| I2C / SPI / GPIO | ❌ (not emulated — use EXP_SIM synthetic data) |
| USB-OTG | ❌ |

## Serial Frame Protocol

Firmware → host via UART0 (TCP socket `localhost:5555`):

```
┌─────┬─────┬──────┬─────┬──────────┬───────┐
│ SOF │ LEN │ TYPE │ SEQ │ PAYLOAD  │ CRC8  │
│ 0xA5│ 1B  │ 1B   │ 1B  │ LEN 字节 │ 1B    │
└─────┴─────┴──────┴─────┴──────────┴───────┘
```

Frame types: `0x01` IMU sample | `0x02` IMU calibrated | `0x03` Euler angles | `0x04` Quaternion | `0x05` Motor telemetry | `0x06` Scene marker | `0x7F` Text log

Full spec: [protocol-spec.md](docs/protocol-spec.md)

## Dual-Macro Build (QEMU vs Hardware)

| Macro | QEMU | Real board |
| --- | --- | --- |
| `EXP_SIM=1` | Synthetic IMU data (no I2C needed) | Real LSM6DS3 sensor |
| `EXP_QEMU_UART=1` | Frames via UART0 (QEMU has this) | Frames via USB-Serial-JTAG |

**Both macros together**: `idf.py -B build-qemu -DEXP_SIM=1 -DEXP_QEMU_UART=1 build`

## Directory Layout

```
xiao_robot_kit_qemu/
├── scripts/
│   ├── setup-qemu.ps1         ← One-click environment setup
│   ├── run-idf.ps1            ← Build + flash + run ESP-IDF project
│   ├── run-idf.ps1            ← Build + flash + run ESP-IDF project
│   └── serial-monitor.ps1     ← TCP socket → console/telemetry display
├── docs/
│   ├── protocol-spec.md       ← Full frame protocol specification
│   └── faq.md                 ← Common issues & solutions
├── LICENSE                    ← MIT
└── README.md
```

## Roadmap

- [ ] `run-arduino.ps1` — compile Arduino sketch via arduino-cli → run in QEMU
- [ ] `configs/` — machine configs (flash layout, efuse, UART routing)
- [ ] `examples/` — minimal IDF/Arduino examples (blink, IMU, motor)

## License

MIT — see [LICENSE](LICENSE)

## Related

- [xiao_robot_kit_idf](https://github.com/xiao-robot-kit/xiao_robot_kit_idf) / [xiao_robot_kit_arduino](https://github.com/xiao-robot-kit/xiao_robot_kit_arduino) — same C core, IDF and Arduino forms
- [xiao_robot_kit_vibe](https://github.com/xiao-robot-kit/xiao_robot_kit_vibe) — AI multi-agent development methodology
- [xiao_robot_kit_docs](https://github.com/xiao-robot-kit/xiao_robot_kit_docs) — hardware intro + tutorials
- [xiao_robot_kit_host](https://github.com/xiao-robot-kit/xiao_robot_kit_host) — host-side debug tooling & visual demos
