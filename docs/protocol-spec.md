# 串口帧协议规范 v1

> XIAO Robot Kit 固件 ↔ 上位机通信协议（帧格式+帧类型全集+CRC8）。
> 本文档是唯一权威描述；C/Python 两侧实现向本文档对齐。

## 1. 帧格式（小端字节流）

```
┌─────┬─────┬──────┬─────┬──────────┬───────┐
│ SOF │ LEN │ TYPE │ SEQ │ PAYLOAD  │ CRC8  │
│ 0xA5│ 1B  │ 1B   │ 1B  │ LEN 字节 │ 1B    │
└─────┴─────┴──────┴─────┴──────────┴───────┘
```

- **CRC8**：多项式 `0x07`、初值 `0x00`，覆盖 `LEN..PAYLOAD`（不含 SOF 与 CRC 自身）
- **LEN**：`0..96`（`PROTOCOL_PAYLOAD_MAX`）
- **SEQ**：发送端自增（`0xFF` 回绕），接收端用于丢帧统计
- **传输载体**：实机 USB-Serial-JTAG；QEMU 仿真走 UART0（`-serial tcp:...` 第 1 槽）

## 2. 帧类型全集

| TYPE | 名称 | Payload | 用途 |
| --- | --- | --- | --- |
| 0x01 | IMU_SAMPLE | 6×float LE（ax,ay,az,gx,gy,gz；g/dps）= 24B | 六轴原始数据流 |
| 0x02 | IMU_CAL | 19×float LE = 76B | 调零温补后数据+零偏+温度 |
| 0x03 | EULER | 3×float LE（roll,pitch,yaw 弧度）= 12B | 欧拉角（万向节死锁教学对照） |
| 0x04 | QUAT | 4×float LE（w,x,y,z）= 16B | 四元数（3D 渲染主通道，\|q\|≡1） |
| 0x05 | MOTOR | 电机遥测（槽位×16B 记录） | 电机 duty/speed/温度 |
| 0x06 | SCEN | 场景标记 | 实验场景切换事件 |
| 0x7E | ACK | 1B 状态码 | 命令确认 |
| 0x7F | TEXT | ASCII 日志（无 NUL） | 调试日志流 |

## 3. 容错契约

接收端解码器必须满足：
- 坏 CRC / 超限 LEN → **逐字节重同步**（丢弃至下一个 SOF）
- 合法帧全收、坏帧全弃、**零静默污染**
- 半帧（流中断）→ 缓存等待续传

## 4. 一致性向量（双实现必须同结果）

```
v_empty  A5007E0074
v_hi     A5027F074F4B5C
crc_zero 00
crc_seq3 48
crc_ff3  0F
```

## 5. 实现锚

| 侧 | 文件 | 测试 |
| --- | --- | --- |
| 固件 C | `proto/frame.c` | `testing/frame_vector_main.c` |
| 上位机 Python | `backend/frame.py` | `tests/test_frame.py` |
| 注入回归 | — | `tests/test_proto_fuzz.py`（10 万帧 0.99% 坏帧零污染） |
