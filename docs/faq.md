# 常见问题（FAQ）

## Q: QEMU 启动了但串口零帧输出？

**A**: 检查编译宏——ESP-IDF 项目必须**双宏**编译：

```
idf.py -B build-qemu -DEXP_SIM=1 -DEXP_QEMU_UART=1 build
```

缺 `EXP_SIM=1` → 固件在 QEMU 里等真 I2C 传感器（QEMU 无 I2C 外设，会挂死）。
缺 `EXP_QEMU_UART=1` → 帧走 USB-Serial-JTAG（QEMU esp32s3 无此设备 chardev）。

## Q: Windows 下 bat 脚本中文注释乱码？

**A**: bat 文件必须**纯 ASCII**。UTF-8 中文注释在 Windows cmd（GBK 解码）下会变成乱码命令（如 `'setup锛?' 不是内部或外部命令`）。

## Q: `cmd /c` 命令静默不执行？

**A**: Git Bash（MSYS）里 `cmd /c` 的 `/c` 会被路径转换成 `C:\`——用 `cmd //c`（双斜杠防转换），并在命令前 `set MSYSTEM=`。

## Q: 编译报 `unable to create file ... Filename too long`？

**A**: Windows 260 字符路径限制。缩短项目路径或启用 Windows 长路径支持（`git config --system core.longpaths true` + 注册表 `LongPathsEnabled=1`）。

## Q: 如何在 QEMU 里测试电机（PWM）？

**A**: QEMU esp32s3 不仿真 LEDC/PWM 外设。使用 `EXP_SIM=1` 时，电机库走合成编码器回灌路径，`motor_poll()` 的 duty/速度输出通过 0x05 帧经 UART0 发出——波形形状可在串口监视器中验证。

## Q: Arduino 程序怎么在 QEMU 里跑？

**A**: Arduino 需要编译为 ESP32 固件（arduino-cli），然后合并 flash 镜像进 QEMU。与 IDF 流程相同，但需额外一步 `esptool merge-bin`。参见 `scripts/run-arduino.ps1`。

## Q: 多个实验同时跑，端口冲突？

**A**: 每个实验用不同 TCP 端口（5555/5556/5557/5558…）。QEMU 的 `-serial tcp:127.0.0.1:<port>,server,nowait` 参数控制。

## Q: QEMU 进程残留？

**A**: 脚本会自动 `taskkill`；手动清理：`taskkill /F /IM qemu-system-xtensa.exe`
