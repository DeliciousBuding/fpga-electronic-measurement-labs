# C301 RGB 彩灯蓝牙控制器 — 上板测试逐步骤手册

> 日期：2026-06-15 | 配合 `field-evidence/` 现场证据采集使用

---

## 准备清单

- [ ] Cyclone IV E 开发板（已下载 SOF：`final-rgb-controller/output_files/final-rgb-controller.sof`）
- [ ] CH9143 BLE PMOD 子板（插在 PMOD 口）
- [ ] 8 颗 WS2812 LED 灯带/板（Din 接 PIN_T2，GND 共地）
- [ ] 手机（Android，安装最新 APK：`final-rgb-controller/app-release.apk`）
- [ ] USB Blaster 下载线
- [ ] 串口线（如需独立串口验证）
- [ ] 示波器 / SignalTap（波形采集用）

---

## 步骤 1：上电与下载

1. 开发板接电源，USB Blaster 连电脑
2. 打开 Quartus Programmer，下载 `final-rgb-controller.sof`
3. 确认下载成功（Progress 100%，Configuration succeeded）
4. LED 灯带应全部熄灭（复位状态：RGB=(0,0,0)）

**截图/拍照**：Programmer 成功界面

---

## 步骤 2：安装 APK 并连接 BLE

1. 手机安装 `app-release.apk`
2. 打开 App → 进入 Scanner 页 → 点击扫描
3. 应看到 CH9143 设备（名称含 "CH9143" 或类似）
4. 点击设备连接 → 应跳转到主界面，显示 "已连接"
5. 连接成功后会自动 QueryStatus，状态栏显示当前模式/颜色

**截图**：
- `field-evidence/01-ble-scan/ble-scan-latest-apk.png` — BLE 扫描列表含 CH9143
- `field-evidence/02-ble-connect/ble-connect-ch9143.png` — 连接成功状态页

---

## 步骤 3：颜色与亮度验证

| 操作 | App 操作 | 预期 LED 效果 | 串口验证 |
|------|----------|:------------:|----------|
| 红色 | Color tab → 选红色 | 8 颗红灯全亮 | `10 FF 00 00` → `AA` |
| 绿色 | Color tab → 选绿色 | 8 颗绿灯全亮 | `10 00 FF 00` → `AA` |
| 蓝色 | Color tab → 选蓝色 | 8 颗蓝灯全亮 | `10 00 00 FF` → `AA` |
| 亮度 | 拖亮度条到 50% | LED 变暗一半 | `11 80` → `AA` |

**拍照**：
- `field-evidence/03-led-effects/led-static-red.jpg`
- `field-evidence/03-led-effects/led-static-green.jpg`
- `field-evidence/03-led-effects/led-static-blue.jpg`

---

## 步骤 4：灯效验证

| 模式 | App 操作 | 预期 LED 效果 |
|------|----------|:------------:|
| 呼吸 | Effect tab → 呼吸 | 8 颗灯同步呼吸渐变（亮→暗→亮） |
| 流水 | Effect tab → 流水 | 单颗灯依次点亮，循环流动 |
| 渐变 | Effect tab → 渐变 | 8 颗灯彩虹色渐变 |

**拍照**：
- `field-evidence/03-led-effects/led-breath.jpg`
- `field-evidence/03-led-effects/led-flow.jpg`
- `field-evidence/03-led-effects/led-gradient.jpg`

---

## 步骤 5：音乐联动验证 ⭐

1. Effect tab → 点击 "音乐" chip
2. 系统弹出麦克风权限请求 → 点击 "允许"
3. 对着手机麦克风说话 / 播放音乐
4. 观察效果：
   - App 界面：电平条跳动，数值 0-255 变化
   - LED：亮灯数随音量变化（音量越大亮的颗数越多）

**拍照**：
- `field-evidence/03-led-effects/led-music-low.jpg` — 安静时（0-2 颗亮）
- `field-evidence/03-led-effects/led-music-high.jpg` — 大声时（6-8 颗亮）

---

## 步骤 6：情景保存/加载

| 操作 | 步骤 | 验证 |
|------|------|------|
| 保存 | 设红色 → Scene tab → 保存到 slot 1 | 提示成功 |
| 验证 | 设蓝色 → Scene tab → 加载 slot 1 | LED 恢复红色 |

---

## 步骤 7：串口记录

用串口助手（115200 8N1）连接 FPGA UART：

1. 发 `FF` → 收到 5 字节状态帧
2. 发 `10 FF 00 00` → 收到 `AA`（设置红色）
3. 发 `AB` → 收到 `EE`（非法命令）
4. 发 `FF` → 收到 5 字节状态帧（确认恢复）

**截图/记录**：
- `field-evidence/04-serial-log/serial-log.md` — 按模板填写实际收发
- `field-evidence/04-serial-log/serial-log.png` — 串口助手截图

---

## 步骤 8：波形采集（SignalTap 或示波器）

### 方案 A：SignalTap
1. 打开 `final-rgb-controller/stp/` 下的 STP 配置
2. 抓取信号：`led_din` (PIN_T2)、`tx_dout` (PIN_D6)、`rx_din` (PIN_B11)
3. 触发条件：UART RX 下降沿
4. 在 App 上发一条 SetColor 命令，观察波形

### 方案 B：示波器
1. 探头接 PIN_T2 (led_din)，地夹接开发板 GND
2. 触发：下降沿，1V/div，2us/div
3. 应看到 WS2812 的 24-bit GRB 编码波形（T0H≈0.35us, T1H≈0.7us）

**截图**：
- `field-evidence/05-waveform/waveform-ws2812-pin-t2.png`
- 或 `field-evidence/05-waveform/waveform-uart-rx-tx.png`

---

## 步骤 9：证据校验

全部证据采集完毕后，在 Quartus 工程目录运行：

```powershell
cd D:\Code\Quartus\final-rgb-controller
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\verify-field-evidence.ps1 -RequireComplete
```

期望输出：`6/6 complete ✅`

---

## 步骤 10：提交

1. 报告 PDF 单独上传（不压缩）
2. 附件包：Quartus 工程 + Flutter 工程 + SOF + APK + 现场证据
3. 检查 PDF 6 页完整显示
4. APK 文件名确认未被平台改坏
