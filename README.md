# 泡泡工具箱

泡泡工具箱是面向 Android 开发与测试的 Windows 桌面工具箱。应用使用 Python、PySide6 与 Qt Quick/QML 构建，采用 Material 3 风格，并可打包为不依赖用户系统 Python 的自包含程序。

## 当前实现

- 双栏 Material 3 主界面：客制与预设。
- 启动时加载预置功能与用户客制脚本；二者都只在本机工作，不存在 online/local 运行模式。
- 客制命令使用统一的创建、编辑和删除流程；预置功能由应用提供且不可编辑。
- 新增和编辑命令使用同一套 Material 3 编辑器；只保留可水平、垂直滚动的脚本内容区域。
- 预设包含 scrcpy、JSON、时间戳转换和调色盘；客制支持新建、编辑和删除 PowerShell、Bash、BAT 或 Python 脚本，脚本配置保存在 `%LOCALAPPDATA%\PopTools`。
- 命令中的 `${参数名}` 会自动生成普通文本输入框；`${参数名=默认值}` 会预填默认值，运行时仍可修改。也可在脚本前用 `pVal vin = ${显示名称=默认值}` 声明变量，并在后续命令中多次使用 `${vin}`；声明行不会被执行，同时兼容 `pVal vin: ...` 冒号写法。
- 运行按钮固定在标题操作区，参数表单过长时无需滚动到底部。
- 内置 scrcpy 4.0 与所需 Android platform-tools 运行组件（ADB），无需配置 ADB 或 scrcpy 环境即可在应用内投屏。
- 窗口最小尺寸为 960×720，第三栏保留至少 480×480 的可用区域；宽度不足时依次收起一级导航和工具列表文字，紧凑图标保留完整名称悬浮提示。
- 全局 Android 设备选择器每 5 秒刷新并记住选择，所有 ADB 执行器统一使用当前设备。
- 支持 Process、Python、PowerShell、Bash 与 Batch 执行，输出实时显示并可停止。并发总配额默认为 3：scrcpy 独占 1 个保留名额，普通任务共享其余 2 个名额。
- 用户 Python 脚本统一运行在 PopTools 管理的用户专属 Python 环境中；Python Doctor、应用内 pip 安装和脚本执行始终使用同一个环境。
- 提供基于 Windows ConPTY 的可选内置终端，功能默认关闭。用户在“设置”中开启终端时，如果尚未安装应用专用的 PowerShell 7，应用会请求确认并下载经过 SHA-256 校验的官方插件；拒绝或取消安装会保持关闭，安装成功后主界面才显示“终端”Tab。终端可直接运行 `python --version`、`pip list`、`pip install` 等命令，并支持 PSReadLine 历史预测、Tab 补全、方向键历史和 `Ctrl+R` 搜索。插件只写入用户应用数据目录，不修改或依赖系统 PowerShell，终端中的 Python 与 pip 均绑定到应用专属环境。用户从设置关闭终端后，Tab 会隐藏且当前会话会停止，但插件会保留以便再次开启。
- 新建、编辑或运行 Python 脚本时会检查导入依赖；常见导入名会映射为正确的 pip 包名，用户确认后由应用自动安装并重新检查。
- 设置页支持本地脚本导入导出；导入只替换 `tools` 与 `scripts`，不会覆盖外观和设备等应用偏好。
- 点击窗口关闭按钮时隐藏到系统托盘；托盘右键可显示主界面或退出。
- 高风险工具运行前要求二次确认。
- 已集成 JSON 格式化与复制、时间戳和本地时间双向转换以及系统取色器。

## 开发环境

所有 Python 依赖必须安装在项目的 `.venv` 中，不要使用全局 `python`、`pip` 或 `py`。

```powershell
.\.venv\Scripts\python.exe -m pip install --no-build-isolation -e ".[dev]"
.\.venv\Scripts\python.exe -m pytest
.\.venv\Scripts\python.exe -m poptools
```

## 构建自包含程序

```powershell
.\packaging\build.ps1
```

构建结果包括便携版 `dist\泡泡工具箱.exe` 和安装版 `dist\泡泡工具箱-Setup.exe`。安装版默认安装到 `%LOCALAPPDATA%\Programs\泡泡工具箱`，不需要管理员权限；使用 `-SkipInstaller` 可只构建便携版。两个版本均已包含应用管理的 Python 运行时、Qt/QML、ADB、scrcpy、应用脚本和依赖；用户脚本依赖安装到应用管理的用户专属 venv。

## 关键文档

- [用户引导](docs/User-Guide.md)
- [软件架构设计](docs/PopTools-Software-Architecture.md)
- [架构重构说明](docs/ADR-010-Application-Composition-Root.md)
- [视觉实现基线](docs/assets/poptools-material3-reference.png)
- [设计验收记录](design-qa.md)
- [ADR-009：工具存储仓库接口](docs/ADR-009-Tool-Repository.md)

## 测试

```powershell
.\.venv\Scripts\python.exe -m pytest
.\.venv\Scripts\python.exe -m ruff check src\poptools\domain src\poptools\infrastructure src\poptools\runners src\poptools\viewmodels src\poptools\main.py src\poptools\paths.py tests --ignore E501,B008
```
