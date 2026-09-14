# 泡泡工具箱

泡泡工具箱 1.0.9 是一款面向 Android 开发与测试的 Windows/macOS 桌面工具箱，用于集中管理内置能力、个人脚本、Android 设备和交互式终端。

应用数据默认保存在本机。自定义脚本、参数和执行输出不会作为工具内容上传；Jira 飞书推送、PowerShell 7 插件安装、Python 依赖安装和应用更新会在用户使用对应功能时访问相关服务。

> 本文适用于当前 1.0.9 代码版本。

## 主要功能

- **自定义脚本**：在双栏工作区中创建、编辑、删除、搜索、筛选和运行 PowerShell、Bash、Batch、Python 脚本。
- **运行参数**：从脚本占位符自动生成文本、选项或文件选择控件，普通文本参数可写回新的默认值。
- **脚本迁移**：通过剪贴板分享或导入单个脚本，也可通过目录批量导入、导出全部本地脚本。
- **预设功能**：提供 41 个分类 Android 调试命令，以及设备投屏、画面/音频/logcat 联合录制、调色盘和 Jira 飞书推送。
- **Android 设备**：自动扫描和选择设备，预设与自定义 ADB 命令共用当前设备。
- **Python 环境**：应用维护独立 Python 运行时和虚拟环境，并通过 Python Doctor 检查、安装脚本依赖。
- **内置终端**：可选 PowerShell 7 或 macOS Shell，支持多个独立会话，共用应用的 ADB 与 Python 环境。
- **外观设置**：支持跟随系统、浅色和深色模式。
- **应用更新**：支持每天、每周或关闭自动检查，可选择正式版或 Beta 渠道，并在应用内下载、校验和安装更新。
- **桌面集成**：单实例运行、系统托盘、预设工具与最近使用脚本快捷入口。

## 快速开始

1. 在 Windows 10/11 中运行安装版或便携版程序，或在 macOS 12 及以上版本解压并运行 `.app`。
2. 首次启动后阅读应用内引导。
3. 使用左侧“自定义”或“预设”进入对应页面。
4. 使用 Android 功能前，在设备上开启 USB 调试并授权电脑，然后从左下角选择目标设备。
5. 窗口关闭后应用会留在系统托盘；需要完全退出时使用托盘菜单中的“退出”。

## 界面入口

| 入口 | 用途 |
| --- | --- |
| 自定义 | 左侧搜索、筛选和选择脚本，右侧配置参数、运行、编辑、分享或删除 |
| 预设 | 按分类使用 Android 调试命令，以及投屏、联合录制、调色盘和 Jira 飞书推送 |
| 终端 | 打开多标签交互式 Shell；Windows 首次进入时按提示准备 PowerShell 7 |
| 设置 | 切换明暗模式，打开或迁移脚本目录，查看运行环境并管理应用更新 |

系统托盘提供预设工具和最近使用自定义脚本的快捷入口。有参数的工具会先显示参数弹窗，无参数的工具直接运行。

## 预设功能

### Android 调试命令

预设页按“模拟相关、环境相关、硬件相关、跳转相关、其他设备操作、其他预设”组织工具，可搜索名称或说明，也可以通过分类右键菜单隐藏暂时不用的分类。新增的 41 个 Android 命令覆盖：

- 文本输入、系统按键和坐标点击；
- ADB/Fastboot 环境检查与设备关机、重启；
- 打开 URL、Activity、开发者选项和关于本机；
- APK 安装/卸载、应用数据与进程管理、冻结/解冻和权限操作；
- 全局代理、无线调试、设备文件、截图、录屏、APK/ANR 导出；
- 栈顶 Activity、屏幕参数、系统属性、序列号、CPU 架构和持续 Logcat。

需要设备的命令使用左下角当前选择的 Android 设备。持续运行的 Logcat 可再次点击运行按钮停止。

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

## 自定义脚本

### 创建与管理

1. 进入“自定义”。
2. 点击右上角“新建脚本”。
3. 填写名称、说明，选择图标和 `PowerShell`、`Bash`、`Batch 脚本` 或 `Python`。
4. 输入脚本内容并保存。
5. 在右侧详情区填写参数，然后点击“运行脚本”。

自定义页面采用脚本列表与详情区并排布局。列表可筛选 Batch、PowerShell 和 Python，并按添加时间、名称或使用频率排序；搜索会匹配脚本名称、说明和运行方式。详情区提供分享、编辑、删除、运行/停止以及可展开的控制台输出。

同一个脚本不能重复启动。达到运行容量上限时，应用会提示是否停止最早启动的任务后运行新任务。

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

使用 `${标题@file}` 创建带文件选择按钮的路径输入框，也可以通过
`${标题@file:默认路径}` 指定默认路径。点击文件按钮时，如果当前输入框中已有路径，
文件管理器会从该路径所在目录打开：

```powershell
adb install "${APK安装包@file:C:\Downloads\example.apk}"
```

文件路径仍按普通文本替换，路径可能包含空格时需按照脚本语言规则自行添加引号。

脚本需要多次使用同一参数，或需要分开内部变量名与界面标题时，可以在脚本开头声明 `Var`：

```powershell
Var timestampMs = ${时间戳:1786356497528}

Write-Host "即将设置 Android 设备时间"
adb shell cmd alarm set-time ${timestampMs}
```

`Var` 声明行只用于参数元数据，不会交给脚本解释器执行。普通文本参数的当前输入不同于默认值时，可以通过“设为默认值”写回脚本模板。旧版脚本中的 `pVal` 声明仍可继续使用，但新脚本统一推荐使用 `Var`。

Python 字符串中的占位符需要自行添加引号：

```python
keyword = "${搜索关键词:Android 工具}"
count = int("${数量:3}")
print(keyword, count * 2)
```

占位符是在执行前进行文本替换。处理不可信内容、路径、引号和特殊字符时，应使用对应脚本语言的安全转义方式。

### 分享、导入与导出

分享单个脚本时，在右侧详情区点击“分享”，应用会将带格式标识和版本号的完整脚本 JSON 写入剪贴板。接收方点击自定义页面的“导入”按钮即可读取：

- 脚本 ID 不存在时追加到当前列表；
- 相同自定义脚本 ID 已存在时询问是否替换；
- 与内置功能 ID 冲突、格式无效或使用内部执行器的内容会被拒绝。

在“设置 → 脚本目录”中可以批量迁移：

1. “导出脚本”在系统文档目录创建包含 `tools` 和 `scripts` 的时间戳目录。
2. “导入脚本”选择之前导出的目录。
3. 导入前自动备份现有脚本，再将导入内容合并；同路径文件使用导入版本，其他本地脚本保留。

批量迁移只处理脚本相关文件，不覆盖外观、更新、设备选择、Jira 飞书方案等应用设置。

## Python 环境与依赖

应用准备独立 Python 运行时，并在用户数据目录维护专属虚拟环境。自定义 Python 脚本、Python Doctor、依赖安装和终端中的 `python`/`pip` 使用同一环境，不修改系统 Python。

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

“终端”入口始终显示。Windows 首次进入时会提示下载、校验并安装应用专用 PowerShell 7；macOS 使用用户系统 Shell。环境准备完成后会直接进入终端页面。

终端支持多个标签页，每个标签页拥有独立 Shell 会话、当前目录和输出记录。切换页面不会结束会话；关闭标签页会停止对应会话，始终至少保留一个标签页。“重启会话”只重启当前标签页。

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

退出应用时会停止全部终端会话并回收相关进程与资源。

## 外观

进入“设置 → 外观”可以选择跟随系统、浅色或深色模式，修改会立即生效并在下次启动时保留，不会影响脚本、设备或推送方案。

## 应用更新

发布版启动后按设置的频率异步检查 GitHub Release，也可以在“设置 → 关于”手动检查。每天模式在每个本地自然日最多自动检查一次；每周模式在每个周一开始的自然周最多自动检查一次；选择“从不”会关闭自动检查。无论检查成功或失败，同一周期内都不会重复自动请求。

- 正式渠道读取 GitHub 最新正式 Release；
- 开启“接收测试版本”后，从最近 5 个正式版或 prerelease 中按版本号选择最高版本；
- 发现更新时在弹窗中直接显示该 Release 的 Markdown Release Notes；
- 弹窗高度随说明内容调整，最长内容使用滚动区域；
- 可以下次提醒、跳过当前版本、立即下载、取消下载、稍后安装或安装并重启；选择“稍后安装”后，下次启动会先校验并自动应用已下载的更新；
- 下载文件会校验大小以及 GitHub digest 或配套 SHA-256。

Windows 仅发布 `PopTools-Setup.exe`。安装器会一次性释放应用、Qt、独立 Python 和 scrcpy，后续启动直接使用安装目录中的文件；应用内更新同样下载并静默运行该安装器。macOS 根据架构使用 `PopTools-macos-arm64.zip` 或 `PopTools-macos-x64.zip`。

## 数据位置与隐私

默认用户数据目录：

```text
Windows: %LOCALAPPDATA%\PopTools
macOS:   ~/Library/Application Support/PopTools
```

目录中保存应用设置、自定义工具、脚本、备份、输出、日志、Jira 飞书方案、Python 环境、插件和更新缓存。卸载或迁移前，可先使用设置中的“导出脚本”。

Jira Token、飞书 Webhook、签名 Secret 和飞书应用凭据保存在本机用户数据目录。自定义脚本是否访问网络由脚本内容决定。

## 常见问题

- **找不到 Android 设备**：确认 USB 调试已开启并授权，重新连接后等待设备列表刷新。
- **Bash 无法运行**：Windows 需要可用的 Bash 环境，例如 Git Bash；macOS 使用 `/bin/bash`。
- **Python 提示缺少依赖**：使用 Python Doctor 安装，或在内置终端中执行 `pip install`。
- **终端无法进入**：Windows 首次使用需要完成 PowerShell 7 插件安装；安装失败时检查网络后重试。
- **Jira 或飞书操作失败**：检查地址、凭据、JQL、机器人安全设置和当前网络。
- **定时推送没有执行**：确认方案启用定时、调度器已经启动，并保持应用进程运行。
- **关闭窗口后程序仍在运行**：应用已隐藏到系统托盘，可从托盘菜单完全退出。
- **运行任务达到上限**：根据提示停止最早启动的普通任务后再运行新任务。
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
