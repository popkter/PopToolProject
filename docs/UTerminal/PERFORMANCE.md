# 终端性能验证

性能需求以 README.md 第 13 节为准。本页记录可重复的测量方法；单项结果不代表完整性能验收通过。

## 四窗格持续绘制

`tests/cpp/render_benchmark.cpp` 编译为 `uterminal_render_benchmark.exe`，属于测试目标，不进入安装包，也不自动加入普通 CTest。

该程序创建一个可见的 Qt Quick 窗口及四个生产代码中的 TerminalItem。每个窗格连接独立 ConPTY 子进程，子进程每批写入 10 行，批次之间 Sleep(10)，内容包含编号、中文、Emoji 和 ANSI 颜色。实际吞吐取决于系统调度，不能把 Sleep 间隔当作准确输出速率。

在仓库根目录运行（先完成 Release 构建）：

```powershell
$env:PATH="$PWD/build/qt-sdk/6.10.3/msvc2022_64/bin;$env:PATH"
& ./build/uterminal-clean-vs/Release/uterminal_render_benchmark.exe 600 "$PWD/build/render-benchmark-visible-600.json" --keep-visible
```

第一个参数为秒数（10–3600），第二个参数为结果文件，父目录必须存在。运行中每 5 秒原子更新 JSON；正常完成后 `status` 为 `finished`，保存同路径加 `.png` 的窗口截图，并关闭其四个子进程。不要隐藏、最小化或遮挡测试窗口来代替可见绘制验收。若提前关闭窗口，不能把最后一个 `running` 记录视为完成；仍需结合进程句柄确认运行状态。

`--keep-visible` 将测试窗口置顶，以减少被其他窗口遮挡的影响。每个样本记录窗口 visible/exposed 状态、区间帧数和各窗格的绘制次数。采样时窗口不可见或未暴露，或者持续输出期间任一窗格在完整采样区间没有绘制、窗口没有提交帧，都会增加 `stalledRenderIntervals`，使最终 `workloadComplete` 为 false、退出码为 1。该采样能发现整段停止绘制，不能证明每一帧都没有被遮挡。`--simulate-hidden-window` 仅供检查测量工具：第 7 秒隐藏，第 14 秒恢复，20 秒运行应报告未完成。

结果字段：

| 字段 | 含义 |
| --- | --- |
| `panes` | 各窗格接收字节数、绘制次数、最大单次 paint 时间及保留历史行数 |
| `frames` | Qt Quick 的 frameSwapped 通知数，不等于经相机确认的屏幕刷新次数 |
| `heartbeatDelayP95Ms` / `heartbeatDelayMaxMs` | 主线程 10ms 定时器超出目标间隔的延迟；包括初始化阶段 |
| `steadyHeartbeatDelay*` | 启动 5 秒后的同一指标；全程数据仍保留，不能因此忽略启动卡顿 |
| `memorySamples` | 宿主进程 Private Bytes、Working Set 和历史行数时间序列；不包含 ConPTY 子进程或其他应用 |
| `workloadComplete` | 无已报告错误或整段停止绘制，四窗格均接收数据、实际绘制并达到 10,000 行历史上限；不是全部性能门槛的判断 |

判断内存是否趋于稳定时，应检查达到历史上限后的时间序列和趋势，不能仅比较首次及末次样本。需要同时保留测试机信息、Qt 版本、窗口尺寸与 DPI；JSON 已记录其中的软件和窗口信息。不同机器、输出频率、窗口尺寸的结果不能直接对比。

此工具不覆盖应用页面导航、输入到显示的 p95、真实 PowerShell/Python 交互负载、IME、窗口缩放或 Windows Terminal 对照。上述项目仍须分别验证。单次 paint 或定时器延迟不能代替端到端输入测量。

## VT 解析与历史保留

已有 `uterminal_terminal_benchmark.exe 1000000 RESULT.json` 测量解析与历史保留，它没有真实终端窗口绘制。用于定位解析器和历史存储变化，不用于证明 UI 帧率或输入延迟。

## 输入事件到提交帧

给绘制测试增加 `--input-probes`：

```powershell
& ./build/uterminal-clean-vs/Release/uterminal_render_benchmark.exe 60 "$PWD/build/input-frame-60.json" --keep-visible --input-probes
```

启动 5 秒后，每 500ms 轮换一个窗格，给予焦点并向 QQuickWindow 发送一个 Qt 按键事件。生产 TerminalItem 生成输入，经生产 ConPty 写入子进程；子进程使用 ReadConsoleInputW 读取按键，将保留的底部状态行交替涂成两种唯一颜色。持续输出使用上方滚动区域，仍保留正常历史。

测量结束点需要满足两个条件：TerminalItem 的实际 QImage 绘制结果中出现本次目标颜色；随后窗口触发 frameSwapped。仅收到输出字节、调用 update 或按键事件被接受都不会记为完成。同一窗格交替颜色，避免把上次回显计为本次结果；GUI 和渲染线程的探针状态使用互斥保护。2 秒内未完成则记录超时，最终测试失败。初始布局调整行数时，子进程会重新确定状态行，避免在旧尺寸之外绘制。

反向校验使用 `--drop-probe-input`，只丢弃探针按键而保留终端协议回复。20 秒验证产生 18 次超时、0 个成功样本，绘制停滞数为 0，退出码 1（build/input-frame-disconnected.json）。这说明该测试不会将普通持续输出计为按键回显。

2026-09-14 同机一分钟结果：60.227 秒，退出码 0，四窗格分别取得 27 / 26 / 26 / 26 个样本，共 105 个；p95 **43.04ms**、最大 **55.51ms**，无超时、无未完成探针、无绘制停滞。截图已检查四个状态色块及中文/Emoji 输出；测试进程已全部退出。原始数据与截图位于 `build/input-frame-60.json` 及同名 `.json.png`。

该指标是合成 Qt 按键事件到回显像素提交帧，未包含物理键盘、操作系统硬件输入分发、显示器扫描输出，也没有完整应用 QML、真实 Shell 编辑器或 Windows Terminal 对照。测试使用独立组件窗口，不能用这一分钟数据直接宣称完整应用的十分钟输入性能验收通过。

## 2026-09-14 四窗格置顶运行结果

运行 600.251 秒，退出码 0。120 个采样点均 visible/exposed，无停止绘制区间；四窗格均保留 10,000 行历史，各接收约 24.8 MB 输出，分别绘制 35,486 / 36,529 / 35,790 / 36,519 次。截图已检查中文、Emoji 与 ANSI 颜色；结束后宿主和四个生产负载子进程均已退出，原有 UTerminal Debug 实例保持运行。

测试机：AMD Ryzen 9 9950X（16 核 / 32 线程），Windows 11 x64 build 26200，Qt 6.10.3，逻辑窗口 1200×800，DPI 比例 1.75。枚举到 RTX 4080、AMD 集成显卡及 ToDesk 虚拟显示适配器；没有据此推断实际使用的渲染设备。完整机器记录位于 `build/render-benchmark-machine.json`。

| 指标 | 结果与限制 |
| --- | --- |
| 全程心跳延迟最大值 | 332.05ms；启动峰值尚待定位，不能删除此数据后宣称始终低于 200ms |
| 启动 5 秒后心跳延迟 | p95 3.98ms，最大 10.69ms；不是键盘输入到显示延迟 |
| 30 秒后宿主私有内存 | 301.26–303.88 MiB |
| 最后 120 秒宿主私有内存 | 303.46–303.88 MiB，线性拟合约 +0.18 MiB/分钟；属于小幅增长，尚未证明长期完全平稳或没有泄漏 |
| 单次 paint 最大值 | 首窗格 216.30ms，其他窗格 3.45–4.35ms；首窗格峰值原因需进一步测量 |

内存包含持续积累的测试统计数据，不能直接将小幅增量归因于终端，也不能据此排除泄漏。应继续分离测量工具开销，并验证输入、应用导航、resize 和同机 Windows Terminal 对照。

原始结果：`build/render-benchmark-visible-600.json`（SHA-256 `4975F1E988EFC0837BDA3A830142753945CA6163D37DD78F77EAD112853D1F3E`）；计算摘要：`build/render-benchmark-visible-600-audit.json`；截图：原始 JSON 路径加 `.png`。测试二进制 SHA-256 为 `B22158FCA45E4D029925D11541CCC7F069FF69F9FB1E999B0712311A533E5F36`。

早先 `render-benchmark-600.json` 的运行后段帧计数停滞，已在独立 audit 文件中判定为不满足持续绘制验证；不得用其旧 `workloadComplete=true` 覆盖本次检查标准。
