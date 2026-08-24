# 泡泡工具箱

泡泡工具箱是一款面向 Android 开发与测试的 Windows/macOS（Beta） 桌面工具箱，用来集中运行常用工具和个人脚本。

项目数据保存本地，主要支持功能如下：

- **预设功能**由应用提供的开箱即用功能；
- **客制功能**由用户创建，支持 PowerShell、Bash、BAT 和 Python 脚本；
- 脚本、参数与执行结果均在本机处理，不会作为工具内容上传。

应用仅在 Windows 下载安装可选 PowerShell 7 插件或检查软件更新时访问网络。

> 本文适用于当前 1.0.1 代码版本。

## 快速开始

1. 在 Windows 10/11 中运行安装版或便携版程序，或在 macOS 12 及以上版本解压并运行 `.app`。
2. 首次启动后阅读应用内引导。
3. 使用左侧的“客制”或“预设”进入工具列表。
4. 如果要使用 Android 功能，请先在设备上开启 USB 调试并授权电脑，然后从左下角设备选择器选择目标设备。
5. 点击窗口关闭按钮时，应用会隐藏到系统托盘；要完全退出，请使用托盘菜单中的“退出”。

## 界面入口

| 入口 | 用途 |
| --- | --- |
| 客制 | 创建、编辑、排序、搜索、删除和运行自己的脚本 |
| 预设 | 使用 Android 投屏与录制、JSON、时间戳和调色盘等内置工具 |
| 终端 | 可选的交互式 PowerShell 7 终端，支持最多 7 个独立标签页，并使用应用内置的 adb 和 Python 环境 |
| 时间 | 显示待机时钟 |
| 设置 | 调整主题、并发脚本数、终端开关，导入导出脚本并查看版本与更新提示 |

系统托盘提供预设工具和最近使用工具的快捷入口。有参数的工具会先打开参数窗口，无参数的工具可直接运行。

## 使用预设功能

当前预设功能包括：

- **记录案发现场**：录制 Android 设备画面、系统声音和麦克风，并同步保存 logcat 日志。需要 Android 11 或更高版本，设备还需支持 `VOICE_PERFORMANCE` 音源；部分应用可能禁止内部音频采集。
- **Android 设备投屏**：使用应用内置的 ADB 与 scrcpy 将当前设备画面嵌入主界面。
- **JSON 解析**：格式化、压缩和复制 JSON；格式错误时会显示位置。
- **时间戳转换**：在秒、毫秒时间戳与本地日期时间之间转换。
- **调色盘**：输入、预览和转换常用颜色值，并支持应用内色盘与系统取色器。

Android 设备列表会自动刷新并记住上次选择。启动投屏或录制前，请确认选择器显示的是目标设备。

## 创建客制脚本

1. 进入“客制”。
2. 点击工具列表标题右侧的“新建命令”。
3. 填写名称、说明并选择 `PowerShell`、`Bash`、`BAT 脚本` 或 `Python`。
4. 输入脚本内容并保存。
5. 从客制列表选择工具，填写参数后点击“运行命令”。

客制脚本保存在本机，可以编辑、删除、排序和重复运行。预设功能不能直接编辑；需要不同逻辑时，请新建客制脚本。

### 用占位符生成参数输入框

脚本中的占位符会自动转换为运行前的输入框。变量名可以使用中文、字母、数字和下划线。

使用 `${变量名}` 创建空输入框：

```powershell
adb shell settings put global auto_time ${自动设置时间}
adb shell settings put global auto_time_zone ${自动设置时区}
```

使用 `${变量名=默认值}` 提供可修改的默认值：

```powershell
adb shell cmd alarm set-time ${时间戳=1786356497528}
```

变量需要多次使用，或希望分开内部名称与显示名称时，可以在脚本开头使用 `pVal`：

```powershell
pVal timestampMs = ${时间戳=1786356497528}

Write-Host "即将设置 Android 设备时间"
adb shell cmd alarm set-time ${timestampMs}
adb shell date
```

- `timestampMs` 是脚本内部变量名；
- `时间戳` 是输入框名称；
- `1786356497528` 是默认值；
- `pVal` 声明行不会交给脚本解释器执行；
- 同时兼容 `pVal timestampMs: ${时间戳=...}` 写法。

Python 中的替换发生在执行前，字符串占位符需要加引号：

```python
keyword = "${搜索关键词=Android 工具}"
count = int("${数量=3}")
print(keyword, count * 2)
```

不要把不可信内容直接拼接进复杂 shell 命令。涉及路径、引号或特殊字符时，请使用对应语言的转义或参数数组。

## 使用 Python 脚本

### 直接编写源码

新建客制脚本并选择 `Python`，然后输入源码：

```python
import datetime

print("当前时间：", datetime.datetime.now().isoformat(timespec="seconds"))
```

### 运行已有 `.py` 文件

Python 类型的脚本内容也可以只填写文件路径：

```text
C:\Users\Public\Scripts\device_report.py
```

路径包含空格时请加引号：

```text
"C:\Tools\Android Scripts\device_report.py"
```

应用会把脚本同目录模块视为本地模块，不会误判为需要安装的第三方依赖。

### Python 环境与依赖检查

应用自带 Python 运行时，并在用户数据目录维护专属虚拟环境。客制 Python、Python Doctor、内置终端中的 `python`/`pip` 和自动安装依赖都使用这一个环境，不依赖或修改系统 Python。

新建、编辑或运行 Python 脚本时，应用会分析 `import`。缺少常见第三方依赖时，确认提示即可自动安装；也可以点击“运行命令”左侧的依赖检查按钮手动检查。

常见的导入名与安装包名并不完全相同：

| 导入名 | pip 包名 |
| --- | --- |
| `PIL` | `Pillow` |
| `cv2` | `opencv-python` |
| `yaml` | `PyYAML` |
| `bs4` | `beautifulsoup4` |
| `dateutil` | `python-dateutil` |
| `lunar_python` | `lunar-python` |

自动建议不正确时，请按第三方库文档使用实际包名。

## 开启内置终端

终端默认关闭。Windows 首次开启时会请求下载并校验应用专用 PowerShell 7；macOS 直接使用用户的系统 Shell（通常为 zsh）。两端的终端都与客制 Python 共用应用专属环境。

开启后主界面会显示“终端”。Windows 使用 ConPTY/PowerShell 7，macOS 使用原生 PTY/系统 Shell，均支持常见的历史记录、补全和光标编辑。可以直接执行：

```text
python --version
pip list
pip install requests Pillow
pip install -r requirements.txt
```

Windows 终端会优先使用应用内置的 ADB，无需单独安装 ADB 或配置系统 `PATH`：

```text
adb devices
adb shell
```

终端页面最多可以开启 7 个标签页。每个标签页拥有独立的 Shell 会话、当前目录和输出记录；切换标签页或切换到其他页面不会结束已有会话。有多个标签页时，可以使用标签上的关闭按钮结束对应会话；页面始终至少保留一个标签页。“重启会话”只会为当前标签页创建干净的新会话，不影响其他标签页。

关闭终端功能会隐藏入口并停止所有终端会话，但保留已安装插件。完全退出应用时，终端进程与相关资源会一并回收。

## 导入和导出客制脚本

在“设置 → 客制脚本”中：

1. 点击“导出脚本”，应用会在“文档”目录生成带时间戳的导出目录。
2. 将该目录复制到另一台电脑。
3. 点击“导入脚本”并选择导出目录。

导入目录必须包含应用导出的 `tools` 和 `scripts` 子目录。导入会先备份现有脚本，再替换当前客制工具与脚本；主题、窗口、设备选择等设置不会被覆盖。单个 `.py` 文件请使用“运行已有 `.py` 文件”的方式，不要使用脚本导入功能。

## 数据位置与隐私

默认用户数据目录为：

```text
Windows: %LOCALAPPDATA%\PopTools
macOS:   ~/Library/Application Support/PopTools
```

其中保存配置、客制工具、脚本、备份、输出、日志、运行时、插件和更新缓存。卸载或切换版本前，如果要保留客制脚本，建议先从设置页导出。

工具执行、JSON、时间戳、颜色处理、Android 操作和脚本内容都在本机完成。网络只用于经用户确认的插件安装，以及发布版的软件更新检查与下载。

## 常见问题

- **找不到 Android 设备**：确认 USB 调试已开启并授权，尝试重新连接后刷新设备列表。
- **Bash 无法运行**：Windows 需要存在可用的 Bash 环境，例如 Git Bash；macOS 使用系统 `/bin/bash`。
- **Python 提示缺少依赖**：优先使用 Python Doctor 安装；需要自定义包名或版本时，在内置终端中执行 `pip install`。
- **依赖安装失败**：检查网络、代理和 pip 源配置。
- **终端入口不显示**：在设置中重新开启终端；Windows 还需确认 PowerShell 7 插件安装完成。
- **关闭窗口后程序仍在运行**：这是系统托盘行为，请从托盘菜单完全退出。
- **同时运行的任务达到上限**：应用会提示停止最早启动的普通任务；Android 投屏保留独立运行名额。

## 开发者文档

项目结构、架构边界、构建发布和重构说明统一见 [软件设计文档](docs/Software-Design.md)。第三方组件及许可见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

### macOS 开发构建

在 Apple Silicon 或 Intel Mac 上分别构建对应架构产物：

```bash
uv venv --python 3.11 .venv
./packaging/build.sh
```

脚本会校验测试和平台资源，生成 `dist/泡泡工具箱.app`、`dist/泡泡工具箱-macos-arm64.zip`（或 `x64`）及 SHA-256。
