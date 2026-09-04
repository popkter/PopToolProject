# 泡泡工具箱

泡泡工具箱 1.0.9 是一款面向 Android 开发与测试的 Windows/macOS 桌面工具箱，用于集中管理内置能力、个人脚本、Android 设备和交互式终端。

应用数据默认保存在本机。客制脚本、参数和执行输出不会作为工具内容上传；Jira 飞书推送、PowerShell 7 插件安装、Python 依赖安装和应用更新会在用户使用对应功能时访问相关服务。

> 本文适用于当前 1.0.9 代码版本。

## 主要功能

- **客制脚本**：创建、编辑、删除、搜索、排序和运行 PowerShell、Bash、BAT、Python 脚本。
- **运行参数**：从脚本占位符自动生成文本输入或选项控件，并可保存新的默认值。
- **脚本迁移**：通过剪贴板分享或导入单个脚本，也可通过目录批量导入、导出全部本地脚本。
- **预设功能**：Android 设备投屏、画面/音频/logcat 联合录制、调色盘、Jira 飞书推送。
- **Android 设备**：自动扫描和选择设备，预设与客制 ADB 命令共用当前设备。
- **Python 环境**：应用维护独立 Python 运行时和虚拟环境，并通过 Python Doctor 检查、安装脚本依赖。
- **内置终端**：可选 PowerShell 7 或 macOS Shell，最多 7 个独立会话，共用应用的 ADB 与 Python 环境。
- **主题系统**：支持跟随系统、浅色和深色模式；主题风格从 JSON 配置目录动态加载。
- **应用更新**：支持正式版和测试版渠道，在应用内展示 GitHub Release Notes、下载、校验并安装更新。
- **桌面集成**：单实例运行、系统托盘、预设工具与最近使用脚本快捷入口。

## 快速开始

1. 在 Windows 10/11 中运行安装版或便携版程序，或在 macOS 12 及以上版本解压并运行 `.app`。
2. 首次启动后阅读应用内引导。
3. 使用左侧“客制”或“预设”进入对应页面。
4. 使用 Android 功能前，在设备上开启 USB 调试并授权电脑，然后从左下角选择目标设备。
5. 窗口关闭后应用会留在系统托盘；需要完全退出时使用托盘菜单中的“退出”。

## 界面入口

| 入口 | 用途 |
| --- | --- |
| 客制 | 管理和运行个人脚本，支持搜索、排序、剪贴板导入与新建 |
| 预设 | 使用 Android 投屏、联合录制、调色盘和 Jira 飞书推送 |
| 终端 | 使用可选的多标签交互式 Shell；仅在设置中启用且运行环境就绪后显示 |
| 设置 | 管理主题、客制脚本并发数、终端、本地脚本迁移、版本与应用更新 |

系统托盘提供预设工具和最近使用客制脚本的快捷入口。有参数的工具会先显示参数弹窗，无参数的工具直接运行。

## 预设功能

### Android 设备投屏

使用随应用提供并经过清单校验的 ADB 与 scrcpy，将当前所选 Android 设备画面嵌入主界面。投屏使用独立运行名额，切换到其他页面时隐藏原生投屏窗口，停止功能或退出应用时回收相关进程。

### 记录日志与视频

同时录制 Android 设备画面、系统声音、麦克风，并将 logcat 保存为文本。开始录制前会清空设备 logcat 缓冲区；停止后选择保存目录，应用会生成日期时间命名的子目录并保存 `recording.mp4` 与 `logcat.txt`。

该功能需要 Android 11 或更高版本，设备还需支持 `VOICE_PERFORMANCE` 音源。部分应用可能禁止内部音频采集。

### 调色盘

支持输入和预览 `#RRGGBB`、`#AARRGGBB`，通过色相、饱和度、明度和透明度调整颜色，并可调用系统屏幕取色器获取颜色。

### Jira 飞书推送

按 JQL 查询 Jira Issue，按负责人组织内容并生成飞书互动卡片。功能支持：

- 创建、复制、选择和删除多套推送方案；
- Jira 地址、Token/PAT、JQL 与最大结果数配置；
- 飞书机器人 Webhook、关键词和签名校验；
- 使用飞书 App ID、App Secret 与邮箱域名解析负责人 `open_id`；
- Jira 连接测试、消息预览、立即推送和运行日志；
- 按分钟间隔或每日多个时刻调度。

每个方案分别保存 Jira、飞书、消息和调度设置。定时调度仅在泡泡工具箱进程运行期间生效，窗口隐藏到托盘后仍会继续，完全退出应用后停止。

## 客制脚本

### 创建与管理

1. 进入“客制”。
2. 点击右上角“新增”。
3. 填写名称、说明，选择图标和 `PowerShell`、`Bash`、`BAT 脚本` 或 `Python`。
4. 输入脚本内容并保存。
5. 打开脚本详情，填写运行参数后点击“运行命令”。

脚本详情抽屉提供关闭、分享、删除和编辑操作。客制主页支持按添加时间、名称、使用频率或自定义顺序排列；自定义排序模式下可以拖动脚本。搜索会匹配脚本名称、说明和运行方式。

同一个脚本不能重复启动。达到客制脚本并发上限时，应用会提示是否停止最早启动的任务后运行新任务；并发数可在设置中调整为 1–5。

### 用占位符生成参数控件

使用 `${标题}` 创建空文本输入框：

```powershell
adb shell settings put global auto_time ${自动设置时间}
```

使用 `${标题:默认值}` 提供可修改的默认值：

```powershell
adb shell cmd alarm set-time ${时间戳:1786356497528}
```

使用 `${标题:选项文字=实际值|选项文字=实际值}` 创建选择框：

```powershell
adb shell settings put system show_touches ${触摸点显示:开启=1|关闭=0}
```

脚本需要多次使用同一参数，或需要分开内部变量名与界面标题时，可以在脚本开头声明 `pVal`：

```powershell
pVal timestampMs = ${时间戳:1786356497528}

Write-Host "即将设置 Android 设备时间"
adb shell cmd alarm set-time ${timestampMs}
```

`pVal` 声明行只用于参数元数据，不会交给脚本解释器执行。普通文本参数的当前输入不同于默认值时，可以通过“设为默认值”写回脚本模板。

Python 字符串中的占位符需要自行添加引号：

```python
keyword = "${搜索关键词:Android 工具}"
count = int("${数量:3}")
print(keyword, count * 2)
```

占位符是在执行前进行文本替换。处理不可信内容、路径、引号和特殊字符时，应使用对应脚本语言的安全转义方式。

### 分享、导入与导出

分享单个脚本时，在详情抽屉中点击“分享”，应用会将带格式标识和版本号的完整脚本 JSON 写入剪贴板。接收方点击客制主页的“导入”按钮即可读取：

- 脚本 ID 不存在时追加到当前列表；
- 相同客制脚本 ID 已存在时询问是否替换；
- 与内置功能 ID 冲突、格式无效或使用内部执行器的内容会被拒绝。

在“设置 → 客制”中可以批量迁移：

1. “导出脚本”在系统文档目录创建包含 `tools` 和 `scripts` 的时间戳目录。
2. “导入脚本”选择之前导出的目录。
3. 导入前自动备份现有脚本，再将导入内容合并；同路径文件使用导入版本，其他本地脚本保留。

批量迁移不覆盖主题、终端、设备选择、Jira 飞书方案等应用设置。

## Python 环境与依赖

应用准备独立 Python 运行时，并在用户数据目录维护专属虚拟环境。客制 Python 脚本、Python Doctor、依赖安装和终端中的 `python`/`pip` 使用同一环境，不修改系统 Python。

Python 脚本内容既可以是源码，也可以是 `.py` 文件路径。路径包含空格时使用引号：

```text
"C:\Tools\Android Scripts\device_report.py"
```

新建、编辑、运行或手动检查 Python 脚本时，Python Doctor 会分析 `import`，排除标准库和脚本目录中的本地模块，并提示缺失的第三方包。用户确认后，依赖会安装到应用专属环境。

常见导入名映射包括：

| 导入名 | pip 包名 |
| --- | --- |
| `PIL` | `Pillow` |
| `cv2` | `opencv-python` |
| `yaml` | `PyYAML` |
| `bs4` | `beautifulsoup4` |
| `dateutil` | `python-dateutil` |
| `lunar_python` | `lunar-python` |

## 内置终端

终端默认关闭。Windows 首次启用时会下载、校验并安装应用专用 PowerShell 7；macOS 使用用户系统 Shell。启用成功后，主界面显示“终端”入口。

终端最多支持 7 个标签页，每个标签页拥有独立 Shell 会话、当前目录和输出记录。切换页面不会结束会话；关闭标签页会停止对应会话，始终至少保留一个标签页。“重启会话”只重启当前标签页。

终端会把应用专属 Python、pip 和内置 ADB 加入环境，可直接执行：

```text
python --version
pip list
pip install requests
adb devices
```

快捷键和鼠标操作：

- `Ctrl+C`：存在选区时复制；没有选区时停止当前命令；
- `Ctrl+V`：粘贴剪贴板内容；
- `Ctrl+X`：存在选区时复制并清除选区；
- `Ctrl+L`：清屏；
- `Ctrl+Shift+C/V/X`、`Ctrl+Insert`、`Shift+Insert`：兼容复制、粘贴和剪切；
- 右键：打开主题化操作菜单；中键：粘贴。

关闭终端功能会隐藏入口并停止全部终端会话，但保留已经安装的 PowerShell 插件。退出应用时会回收终端进程与资源。

## 主题

进入“设置 → 外观”可以选择跟随系统、浅色或深色模式。主题风格由 `src/poptools/ui/qml/theme/configs/*.json` 动态提供，当前随应用包含：

- Material 3
- Windows XP
- Mario

应用会同时扫描内置主题目录和用户数据目录下的 `themes` 目录。在 Windows 上，默认用户主题目录为 `%LOCALAPPDATA%\PopTools\themes`；设置 `POPTOOLS_DATA_DIR` 时则使用该目录下的 `themes`。用户主题可覆盖同 ID 的内置主题。

应用启动时扫描一次主题目录，每次打开设置弹窗时重新扫描。有效主题必须同时提供浅色颜色、深色颜色和圆角配置；无效文件不会进入列表，已保存主题不可用时回退到 Material 3。主题切换立即作用于主界面、弹窗、菜单、颜色和圆角，不会修改业务数据。

## 应用更新

发布版冷启动后异步检查 GitHub Release；成功检查后的 24 小时内不重复自动请求，也可以在“设置 → 应用更新”手动检查。

- 正式渠道读取 GitHub 最新正式 Release；
- 开启“接收测试版本”后，从最近 5 个正式版或 prerelease 中按版本号选择最高版本；
- 发现更新时在弹窗中直接显示该 Release 的 Markdown Release Notes；
- 弹窗高度随说明内容调整，最长内容使用滚动区域；
- 可以下次提醒、跳过当前版本、立即下载、取消下载、稍后安装或安装并重启；
- 下载文件会校验大小以及 GitHub digest 或配套 SHA-256。

Windows 更新资产为 `PopTools.exe`，macOS 根据架构使用 `PopTools-macos-arm64.zip` 或 `PopTools-macos-x64.zip`。

## 数据位置与隐私

默认用户数据目录：

```text
Windows: %LOCALAPPDATA%\PopTools
macOS:   ~/Library/Application Support/PopTools
```

目录中保存应用设置、客制工具、脚本、备份、输出、日志、Jira 飞书方案、Python 环境、插件和更新缓存。卸载或迁移前，可先使用设置中的“导出脚本”。

Jira Token、飞书 Webhook、签名 Secret 和飞书应用凭据保存在本机用户数据目录。客制脚本是否访问网络由脚本内容决定。

## 常见问题

- **找不到 Android 设备**：确认 USB 调试已开启并授权，重新连接后等待设备列表刷新。
- **Bash 无法运行**：Windows 需要可用的 Bash 环境，例如 Git Bash；macOS 使用 `/bin/bash`。
- **Python 提示缺少依赖**：使用 Python Doctor 安装，或在内置终端中执行 `pip install`。
- **终端入口不显示**：在设置中启用终端；Windows 还需完成 PowerShell 7 插件安装。
- **Jira 或飞书操作失败**：检查地址、凭据、JQL、机器人安全设置和当前网络。
- **定时推送没有执行**：确认方案启用定时、调度器已经启动，并保持应用进程运行。
- **关闭窗口后程序仍在运行**：应用已隐藏到系统托盘，可从托盘菜单完全退出。
- **运行任务达到上限**：选择是否停止最早启动的普通任务，或在设置中调整客制脚本并发数。
- **检查不到 prerelease**：开启“接收测试版本”后重新检查。

## 开发与构建

项目使用 Python 3.11 开发，依赖 PySide6、Pydantic、Requests、platformdirs、psutil 和 pypinyin。创建开发环境：

```powershell
uv venv --python 3.11 .venv
.\.venv\Scripts\python.exe -m pip install --no-build-isolation -e ".[dev]"
.\.venv\Scripts\python.exe -m poptools
```

运行测试与静态检查：

```powershell
.\.venv\Scripts\python.exe -m pytest
.\.venv\Scripts\ruff.exe check src tests
```

Windows 构建：

```powershell
.\packaging\build.ps1
```

macOS 构建：

```bash
uv venv --python 3.11 .venv
./packaging/build.sh
```

版本以 `pyproject.toml` 为来源。GitHub Release 使用 `vYYYY-MM-DD_x.x.x` 标签，并构建 Windows x64、macOS arm64 和 macOS x64 资产。

## 相关文档

- [软件设计文档](docs/Software-Design.md)
- [第三方组件与许可](THIRD_PARTY_NOTICES.md)
