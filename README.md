# UTerminal

UTerminal 是面向 Windows 11 x64 的终端与自定义脚本应用，当前 `u_terminal` 分支正在将原 PopTools 主程序重写为 C++20、Qt 6 和 QML。当前版本为 0.1.1 开发版，尚未完成全部需求验收。

主应用不依赖 Python 启动。Python 和 PowerShell 7 是用户按需安装的受管运行时；Qt、QML 模块、MSVC 运行库和终端核心随安装包部署，在安装时展开到本地，应用没有启动时自解压流程。

## 当前范围

- 自定义页：PowerShell、CMD、Python 脚本的编辑、参数、收藏、搜索、排序、导入导出和运行输出。
- 终端页：Windows ConPTY 与 libvterm、多标签、分屏、选区、复制粘贴、查找、路径拖入、配色及会话状态。
- 设置页：主题、字体、并发限制、受管运行时与依赖、应用更新。
- Windows 11 右键菜单优先注册原生一级菜单；无可信签名或注册失败时，自动降级到“显示更多选项”中的“在 UTerminal 中打开”。

设计要求和验收清单见 [UTerminal 设计](docs/UTerminal/README.md)，已验证内容和剩余工作见 [实现记录](docs/UTerminal/IMPLEMENTATION.md)。界面以本机 Figma APP 中的 PopTools 设计为参考，目前仍在逐页对齐。

## 开发环境

- Windows 11 x64。
- Visual Studio 2022 或 2026，安装“使用 C++ 的桌面开发”、Windows SDK 和 CMake 工具。
- Qt 6.10 系列的 MSVC 2022 x64 SDK；本机验证版本为 6.10.3，包含 Quick、Quick Controls、Network、Widgets 和 Test。
- 生成安装包另外需要 Inno Setup 6。

Qt 默认从 `build/qt-sdk/6.10.3/msvc2022_64` 查找，也可通过 `QT_ROOT` 或脚本的 `-QtRoot` 参数指定。不要把 Qt SDK 当作应用用户的安装前提。

## 构建、测试和运行

在项目根目录的 PowerShell 中执行：

```powershell
./scripts/build-uterminal.ps1 -Configuration Debug -Test
./build/uterminal-vs/Debug/UTerminal.exe
```

构建脚本自动选择本机 Visual Studio 生成器，构建主程序、终端库、Explorer 扩展和更新助手，再运行 archive-validation、core、runtime 测试。当前 VS 2026 验证环境生成 `build/uterminal-vs/UTerminal.slnx`；VS 2022 使用相应生成器产生的解决方案。打开生成的解决方案，将 UTerminal 设为启动项目即可调试。

也可在 Visual Studio 中直接“打开文件夹”选择本项目，使用 `CMakePresets.json` 的 `windows-msvc` 或 `windows-release` 配置。此方式需要在启动 Visual Studio 前设置 `QT_ROOT`；其 Ninja 构建目录与脚本生成的 VS 解决方案目录不同。

真实 Python/PowerShell 插件集成测试需要显式指定测试数据及资源目录，部分测试会下载运行时或依赖，不包含在普通 core/runtime 回归中。不要将测试数据目录指向个人正式数据。

`.github/workflows/uterminal-ci.yml` 配置 Windows Debug/Release 构建及归档、core、runtime 测试，并保存测试日志。工作流已写入本地，尚未提交推送或获得 GitHub 运行结果；它不发布安装包。

## 生成安装包

```powershell
./scripts/package-uterminal.ps1
```

该命令进行 Release 构建及测试，将运行库和资源部署到 `build/uterminal-package`，再生成：

`build/installer/UTerminal-0.1.1-win-x64-setup.exe`

可使用 `-InnoCompiler` 指定 ISCC.exe。正式 Explorer 集成的签名参数和注册方式见 [Shell 集成说明](resources/shell/README.md)。当前包是开发快照，并非全部验收完成的正式发布版本。

构建与打包脚本都支持 `-BuildDirectory`。要在全新目录验证并打包，可执行 `./scripts/package-uterminal.ps1 -BuildDirectory ./build/uterminal-clean-vs`；脚本会从该目录的 Release 输出取主程序、更新助手和 Explorer 扩展。默认仍使用 `build/uterminal-vs`。

应用版本以 `CMakeLists.txt` 的 `project(... VERSION ...)` 为准。CMake 同步生成编译版本、Windows 文件版本资源和 `version.json`；打包脚本验证二进制版本后，将同一版本传给 Inno Setup 和菜单身份包，并生成安装器 SHA-256 文件。修改版本后必须重新构建，不能将旧二进制与新版本元数据混合打包。

GitHub 手动工作流 [UTerminal Windows installer](.github/workflows/uterminal-package.yml) 使用相同脚本构建、测试和打包，保存安装器、SHA-256、依赖记录及测试日志作为 14 天有效的 Actions 工件。该工作流生成未签名开发包，不创建 GitHub Release；签名和正式发布流程尚未完成。旧 Python/PyInstaller 与 macOS 打包脚本及旧发布工作流已移除。新工作流仍需推送后执行远程验收。

安装器默认按用户安装到 `%LOCALAPPDATA%/Programs/UTerminal`。在本机测试目录已验证实际安装文件与部署目录一致、不依赖开发 SDK 路径的启动，以及卸载测试副本后独立数据目录中的脚本和用户文件保持原哈希。跨版本升级、默认用户目录及干净 Windows 环境验收仍待完成。

## 代码结构

| 目录 | 内容 |
| --- | --- |
| `src/uterminal/domain` | 参数解析等领域逻辑 |
| `src/uterminal/application` | 执行、插件、依赖、更新服务 |
| `src/uterminal/infrastructure` | 存储、普通进程、ConPTY、更新包校验 |
| `src/uterminal/presentation` | QML 模型、会话、终端绘制和编辑器支持 |
| `resources/qml` | 页面、对话框和界面组件 |
| `resources/plugin-bootstrap` | 可选 Python 运行时的引导代码 |
| `resources/shell` | Explorer 身份清单及注册脚本 |
| `native/third_party/libvterm` | 静态链接的终端解析核心及本地补丁说明 |
| `tests/cpp` | C++ 单元、运行时与插件集成测试 |
| `scripts`、`installer` | 构建、部署和 Inno 安装脚本 |

QML 通过 Qt 属性、信号和显式 C++ 方法使用后端。保留简单绑定和事件表达式；文件、进程、参数解析与运行时管理位于 C++ 层。

## 数据与迁移

应用数据位置采用 Qt 的 AppLocalDataLocation，可在设置页查看和打开。开发验证可使用 `UTERMINAL_DATA_DIR` 指定隔离目录。脚本、配置和可选运行时位于数据目录，独立于安装目录。

旧 Python/PySide 主程序、预设业务、Python 依赖清单、旧原生终端包装层与旧测试已从当前工作树移除。可选 Python 运行时的引导脚本仍位于 `resources/plugin-bootstrap`，不参与主程序启动。旧版参考实现可从原始提交 `64c63663c6d25b338c714c9efc265eedf2fa2ecc` 读取，例如 `git show 64c63663c6d25b338c714c9efc265eedf2fa2ecc:src/poptools/domain/parameter_templates.py`。代码清理不代表迁移和全部功能验收已经完成。

旧版说明保存在 [PopTools 1.0.9 文档](docs/legacy/PopTools-1.0.9.md)，其中 Android、投屏、飞书、macOS 和托盘等说明不适用于 UTerminal；历史构建路径只供回顾旧版本。当前第三方说明见 [运行依赖声明](resources/licenses/THIRD-PARTY.md)。
