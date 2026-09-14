# UTerminal

UTerminal 是计划新建的 Windows 终端与自定义脚本应用，采用 **Qt 6 + C++ + QML**。它以 Windows 11 上 Windows Terminal 的日常终端体验为目标，增加固定导航栏、自定义脚本集合，以及应用内 Python、PowerShell 7 插件管理。

> 本文是 UTerminal 的产品需求与架构设计，不代表下述功能均已完成。C++ / QML 工程位于仓库根目录，当前实现与验证结果见 [IMPLEMENTATION.md](IMPLEMENTATION.md)；构建和安装包说明见仓库根目录的 [README.md](../../README.md)。验收以本文要求和实际运行证据为准。

## 1. 产品目标与范围

- 主程序使用 C++，界面使用 QML / Qt Quick，启动与业务不依赖 Python 或 PySide6。
- 提供 **自定义、终端、设置三个页面**。原描述中的“两页面”按实际列举的三个入口理解。
- 自定义页面保存、编辑、管理和运行 Python、PowerShell、CMD 脚本，继承当前项目自定义功能的主要使用方式。
- 终端提供交互式 Shell、多标签、可靠的文本显示和输入体验；右键固定显示菜单，支持将选区文本创建为自定义脚本。
- Python 和 PowerShell 7 都是用户主动安装的可选运行时插件；没有插件时仍可启动应用、进入设置和管理脚本。
- Python 脚本、依赖检查、pip 和终端中的托管 Python 命令使用同一套应用内环境。
- 设置支持主题颜色、应用更新策略、Python 版本、PowerShell 7 版本；PowerShell 7 必须能够升级。

首版以 Windows 11 x64 为开发和验收基线；架构字段预留 ARM64，只有完成对应构建和测试后才发布 ARM64 插件。当前范围不包含 Android、ADB、投屏、录屏、Jira、飞书、调色盘、功德计数、Bash 专用脚本类型等 PopToolProject 预设业务。

“接近 Windows Terminal”是可验证的体验目标，不是已经拥有其全部功能的声明。多标签、分屏、中文输入、颜色、滚动、选择、快捷键和交互程序兼容性属于目标；WSL 发行版发现、完整 Windows Terminal 配置兼容、任意扩展协议不作为首版承诺。不能用普通文本日志框代替真正的终端。

## 2. 页面与导航

固定左侧导航栏显示应用标识和三个入口的图标。主题随设置即时变化。建议初次启动进入“自定义”页面，避免首次启动自动下载插件。

| 页面 | 布局与职责 | 页面切换规则 |
| --- | --- | --- |
| 自定义 | 搜索与排序、脚本列表、详情/参数区、运行输出、新建与编辑弹窗 | 保留选中项、草稿、运行状态和输出 |
| 终端 | 标签栏、分屏终端区域、会话状态、右键菜单 | 离开页面不结束会话，不丢失缓冲区 |
| 设置 | 外观、更新、Python 插件、PowerShell 7 插件、数据与诊断 | 长耗时操作后台继续，随时可返回查看进度 |

页面生命周期与业务生命周期分离。销毁或重新创建 QML 页面不得导致任务停止、插件下载中断或终端进程重启。应用退出时检查运行任务和会话，让用户选择取消退出或结束进程后退出；不默认引入托盘后台驻留。

## 3. 自定义脚本

### 3.1 管理能力

- 新建、编辑、保存、删除脚本；支持名称、描述、图标、脚本类型和代码。
- 支持 Python、PowerShell 7、CMD/BAT 三种类型。界面里的 PowerShell 明确指应用插件 PowerShell 7，不回退到系统 Windows PowerShell 5.1。
- 搜索名称、描述和类型；按名称（含中文拼音）、添加时间、使用次数及自定义顺序排序；支持拖动排序、最近使用。
- 支持选中脚本的 JSON 剪贴板分享、导入和重复 ID 替换确认；支持本地脚本集合目录导入导出，导入前备份、合并保留无关脚本。
- 编辑器支持多行、缩进、等宽字体、撤销重做和基础语法高亮。标题栏明确当前语言，避免把终端文本误认为另一种语言。
- 尚未安装相应插件时仍允许编辑与保存，列表显示“需要安装 Python / PowerShell 7”。缺失插件不是数据保存失败。

### 3.2 参数化脚本

参数规则由 C++ 的 ParameterService 实现，QML 只呈现输入控件。保留当前项目的参数思想与兼容路径：

| 语法/能力 | 行为 |
| --- | --- |
| `${参数名}` | 收集参数，运行时填写并替换 |
| `${参数名:默认值}` | 预填默认值，允许用户修改 |
| `${文件名@file}` | 文件选择和文件拖入 |
| `${模式:显示名A=值A|显示名B=值B}` | 显示名称与运行值分离的下拉选项 |
| `Var` / `pVal` 元数据声明 | 沿用当前项目解析语义，执行前去掉声明行 |
| 旧等号分隔语法 | 导入时兼容并规范化，不破坏旧脚本 |
| 参数默认值修改 | 更新参数定义与源码，保持二者一致 |

运行前统一验证必填项和参数定义；文件与目录参数支持中文、空格、引号和多行边界。参数快照属于一次执行，修改编辑器内容不改变已经启动的任务。

兼容旧模板的文本替换语义，不擅自改变已有脚本的引号含义。执行器负责正确引用进程路径与参数；模板中直接插入源码的参数需要由编辑器说明转义约定，秘密参数不写入普通运行日志。

### 3.3 运行与输出

- Python 使用应用内 Python 插件，PowerShell 使用应用内 `pwsh.exe`，CMD 使用系统 `cmd.exe`，均使用明确的可执行文件路径。
- 将代码保存到每次执行独立的临时脚本文件，按语言使用正确编码与换行，再启动子进程。不能把整段代码拼进未经处理的 shell 命令字符串。
- 继承现有运行能力：独立输出、退出码、错误、超时、停止、工作目录、环境变量、输出目录和运行前确认配置。
- 普通脚本并发上限可设为 1–5，默认建议 3；同一脚本不重复启动。名额不足时提示是否停止最早启动的任务，等待其退出后再启动新任务。终端会话不占该额度。
- 默认通过 ProcessRunner 捕获 stdout/stderr。需要 `input()`、交互控制台或 TUI 的脚本，可选择“在交互会话中运行”，使用 ConPTY；CMD/Python 专用脚本会话不应被普通终端页的 PowerShell 安装门槛阻断。
- 保留运行输出并限制内存中的历史大小。高频输出批量通知模型，不逐字符更新 QML 字符串。
- 停止普通脚本时先请求终止，超时后结束本应用拥有的进程树，不按进程名称结束其他应用。

### 3.4 插件缺失提示

当用户选择 Python 类型并开始输入代码时，编辑器显示安装提示及“安装 Python”按钮；首次明确进入该编辑流程可打开一次提示，不在每次按键时反复弹窗。PowerShell 脚本采用相同规则。

点击运行时必须再次检查插件健康状态。缺失、安装中或损坏时阻止启动，展示原因及安装/修复入口。打开安装弹窗前保存编辑草稿；取消安装或安装失败后，草稿和参数仍在。安装成功后更新可运行状态，用户再次点击运行，不自动执行编辑器中的代码。

## 4. 终端体验

### 4.1 基本能力

- 默认 Shell 为插件 PowerShell 7；保留 PSReadLine 的命令编辑、补全、历史等交互能力，程序负责终端输入输出和渲染。
- 多标签：创建、关闭、重命名、切换、关闭其他标签、关闭右侧标签；每个标签保存自己的工作目录与会话。
- 支持水平/垂直分屏，每个窗格独立会话，清晰标识当前焦点；标签和窗格不能共用错误的输入目标。
- 正确支持 VT/ANSI、16/256/真彩色、光标移动、备用屏幕、光标模式、滚动区域和交互程序需要的鼠标报告。
- 支持中文 IME 预编辑与候选框定位、宽字符、组合字符、Emoji、字体回退、高 DPI、缩放及窗口尺寸变化。
- 支持选区、双击选词、滚动回看、查找文本、复制粘贴、路径拖入和清空；保留真实换行，区分显示自动折行。
- 提供约定快捷键：有选中内容时Ctrl+C复制，Ctrl+V 粘贴、Ctrl+T 新标签、Ctrl+Tab 切换标签、Ctrl+F 查找；没有选中内容时Ctrl+C 默认传给前台程序作为中断，不以复制替代。分屏快捷键在设置/帮助中明确展示。
- 终端标题变化更新标签；大输出时保持输入、窗口拖动与切页可响应。

这些项目必须通过实际交互程序测试，不能仅凭支持 ConPTY 或 libvterm 就认定已经达到 Windows Terminal 的体验。

### 4.2 未安装 PowerShell 7 时

用户点击“终端”导航：进入终端页的安装引导状态，同时提醒“终端需要安装 PowerShell 7 插件”，提供安装、前往设置、暂不安装。

- 不创建失败会话，不启动系统 PowerShell 5.1，不自动下载。
- 暂不安装后留在可操作的引导页面，自定义和设置仍可使用。
- 安装过程中展示统一插件任务的进度；再次点击安装不得重复下载。
- 成功后提供“打开终端”，由用户明确开始会话。Python 没安装不影响 PowerShell 终端启动。

### 4.3 右键菜单

右键总是打开 UTerminal 菜单，不采用右键直接粘贴。启用应用鼠标报告的 TUI 也保持该规则：右键事件由宿主拦截，不同时发送给子进程；左键和滚轮按终端模式处理。

| 菜单项 | 可用条件 | 行为 |
| --- | --- | --- |
| 复制 | 选区包含文本 | 将选区纯文本复制到剪贴板 |
| 粘贴 | 会话运行且剪贴板包含文本 | 写入当前窗格，支持程序启用的 bracketed paste；多行内容给出确认 |
| 清空 | 存在会话缓冲区 | 清除当前窗格显示及滚动历史，不发送 Ctrl+C，不结束进程，不承诺删除 Shell 自身的命令历史 |
| 停止 | 会话运行 | 向当前会话发送中断；若程序不响应，另行提供明确的“结束会话”，避免把中断和杀死 Shell 混为一谈 |
| 添加为自定义脚本 | 选区包含非空文本 | 创建草稿并打开新建脚本弹窗，不执行文本 |

### 4.4 从选区创建脚本

1. 打开右键菜单时记录来源会话 ID 和选区快照，防止后续输出滚动或焦点切换改变内容。
2. 点击“添加为自定义脚本”，从终端缓冲区直接读取选区文本，不借助复制/读取系统剪贴板来绕转。
3. 过滤终端控制信息，保留 Unicode、缩进和逻辑换行；不自动删除提示符、输出行，不把可能的程序输出猜成命令。
4. 弹出与自定义页面共用的新建弹窗，代码字段预填选区，名称待填写；类型默认参考来源 Shell，用户可改为 Python、PowerShell 或 CMD。
5. 保存前允许编辑；若改为 Python 且缺少插件，立即提示安装，同时仍允许保存。
6. 保存后脚本进入集合，可选择前往查看；原终端继续运行。取消弹窗不创建脚本，不改变终端，不执行选区。

## 5. 设置

| 分组 | 配置项与交互 |
| --- | --- |
| 外观 | 跟随系统/浅色/深色、主题强调色、终端配色、字体和字号；即时预览并保存 |
| 应用更新 | 当前版本、稳定/预发布通道、手动检查、关闭自动检查/启动检查/每日/每周、下载状态、稍后安装或退出后安装 |
| Python | 未安装/当前版本/可选版本/活动版本、安装、修复、切换版本、依赖环境与包列表、依赖安装日志 |
| PowerShell 7 | 未安装/当前版本/可选版本/活动版本、安装、检查升级、升级、版本切换与回退 |
| 插件更新策略 | 手动检查或定期检查并通知；安装和活动版本切换由用户触发，独立于主程序升级 |
| 数据与诊断 | 脚本导入导出、打开数据/输出/日志目录、运行并发上限、错误信息复制 |

主题配置由 ThemeService 管理并通过属性通知 QML 与终端渲染器。更换主题不得重建运行会话。自动检查更新不等于自动安装；活动脚本和终端会话不得被更新程序静默中断。

## 6. Python 插件与依赖策略

### 6.1 沿用当前项目的原则

Python 是用户脚本运行时，不是 UTerminal 的宿主语言。每个活动 Python 版本对应应用私有运行时和依赖环境；同一版本的自定义脚本共用该依赖环境，首版不默认每个脚本建一个 venv。

| 环节 | 规定 |
| --- | --- |
| 脚本执行 | 启动插件中真实 CPython 可执行文件 |
| 依赖安装 | 使用该版本受管 venv 的 Python 执行 `-m pip`，不调用系统 pip |
| 依赖诊断 | 语法/import 分析由插件中的 Python helper 执行并返回结构化结果；C++ 管理流程和结果 |
| 执行依赖 | 使用受控 bootstrap 加载配套 venv 的 site-packages，保证实际脚本、诊断与 pip 指向同一环境 |
| 终端命令 | PowerShell profile 中的 `python` / `pip` 定向到所绑定的受管环境 |
| 插件缺失 | `python` / `pip` 包装命令提示安装，不悄悄命中系统 Python；PowerShell 本身继续可用 |

当前 PopToolProject 区分“真正执行脚本的基础解释器”和“安装依赖的 venv 解释器”，以避免 Windows venv 启动重定向影响部分依赖进程身份的控制台自动化工具。UTerminal 保留这一行为，通过受控 `sitecustomize` 或等效 bootstrap 接入私有 site-packages，并测试 sys.prefix、入口脚本、子进程与 pip 的一致性。

Python helper 和 profile 可以作为插件资源存在；这不意味着 C++ 主应用依赖 Python。未安装插件时不得启动 helper，主程序依然完整可用。

子进程环境移除继承的 Python 专用污染项，例如不受控的 PYTHONHOME/PYTHONPATH，并关闭用户 site-packages，避免安装在系统或用户目录的包被误当作应用依赖；不修改系统 PATH、注册表 Python 关联或系统安装。用户手工显式执行外部解释器路径属于独立命令，不归托管环境保证范围。

### 6.2 安装、切换与升级

- 版本来自应用维护的兼容插件目录；“可选择版本”不表示任意 Python 包都可以装。
- 包必须支持所需的 venv、pip 和标准库。不能未经处理直接将不具备完整工作流的精简发行包标为可用。
- 首次安装创建该版本的私有依赖环境，验证解释器、pip 和简单导入后标记 Ready。
- 切换 Python 版本时创建新环境，导出旧环境依赖清单，经用户确认后尝试在新环境重新安装，展示不兼容或失败的包；不复制旧 site-packages 到不同 Python 版本。
- 不直接移动已经创建的 venv；环境在最终版本目录创建，失败时仅清理该次新环境，活动指针保持旧值。Python 官方说明 venv 通常不可移动，应在目标位置重建：[venv 文档](https://docs.python.org/3/library/venv.html)。
- 新环境完成必要验证后才能切换；旧运行任务持有旧环境引用，直到结束。活动会话可继续旧环境，新会话用新版本，界面清晰标记版本。
- 共享环境的 pip 修改使用写入锁，与依赖该环境的新任务启动互斥；已有任务运行时将依赖变更排队至空闲，避免运行中包文件被替换。
- AST 依赖检测只是辅助，不能完整识别动态 import；提供运行错误、手工包名输入、安装日志和重试。

## 7. PowerShell 7 插件升级

PowerShell 插件以官方适配架构的发行包为基础，按版本独立安装，不覆盖系统 PowerShell，不要求 Python 插件存在。

1. 检查可信插件目录，比较当前版本、架构、支持的主程序版本，显示可用升级。
2. 用户选择目标版本后下载至独立临时目录；支持进度、取消和失败重试。
3. 验证包大小、摘要和可信元数据，检查解压路径；在新版本目录安装，不覆盖旧目录。
4. 使用新 `pwsh.exe` 检查版本、启动和 profile 接入；失败时保留旧活动版本并展示错误。
5. 用户确认应用新版本，原子更新活动版本记录。新建会话和新脚本任务使用新版本。
6. 已打开的会话继续旧 `pwsh.exe`，不强杀、不替换被占用的文件。允许用户主动重启会话应用升级。
7. 提供回退到保留旧版本的入口；没有会话/任务引用的旧版本才可卸载。

Python 和 PowerShell 都由统一 PluginManager 管理；插件安装不是任意第三方代码扩展机制，首版只有这两个受支持的运行时类型。

插件生命周期建议：`NotInstalled → Downloading → Verifying → Installing → Ready`，另有 `Failed / RepairRequired`。已有版本 Ready 时升级任务独立记录，新版本失败不能把旧版本改成不可用。活动版本、安装任务和运行引用三个状态分别存储。

离线时保留已安装能力；取消安装不丢草稿；下载中退出可取消并清理临时包；安装提交阶段需要完成或回滚后退出。摘要本身不能证明来源可信，目录元数据须从受信渠道获取并验证；发布时落实元数据签名、校验和完整性流程。

## 8. 架构设计

采用进程内分层架构，不为桌面界面额外启动 HTTP 服务。

```text
QML 页面 / 公共组件 / 主题
          │ 属性、命令、信号
C++ Presentation：ViewModel、ListModel、TerminalView
          │ 用例调用
C++ Application：脚本、会话、插件、更新、设置服务
          │ 接口
Domain：脚本定义、参数、运行配置、版本与状态规则
          ▲
Infrastructure：JSON、ConPTY、QProcess、下载、安装、Windows 集成

交互数据路径：
Shell ↔ ConPTY ↔ TerminalSession / VT 模拟器 ↔ TerminalView
```

### 8.1 层次和依赖约束

| 层 | 推荐组件 | 约束 |
| --- | --- | --- |
| QML | AppShell、CustomPage、TerminalPage、SettingsPage、ScriptEditorDialog、PluginInstallDialog | 布局、动画、绑定与薄事件连接；不解析脚本、不访问磁盘、不编排升级 |
| Presentation | NavigationViewModel、ScriptViewModel、TerminalViewModel、SettingsViewModel、PluginViewModel | QObject 属性、槽/可调用方法、信号；列表用 QAbstractListModel |
| Application | ScriptService、ParameterService、ExecutionService、SessionManager、PluginManager、PythonEnvironmentService、ThemeService、UpdateService | 用例、状态机与协调；不持有 QQuickItem 或页面 ID |
| Domain | ScriptDefinition、ParameterDefinition、ExecutionRequest、PluginVersion、EnvironmentBinding | 无 QML/窗口/网络依赖；可使用 Qt Core 值类型 |
| Infrastructure | JsonScriptRepository、SettingsStore、ConPtySession、ProcessRunner、PluginCatalogClient、ArchiveInstaller、WindowsProcessTree | 实现仓储/进程/下载接口；可替换和单独测试 |
| Native terminal | TerminalBuffer、TerminalParser、TerminalSelection、TerminalView | 会话与渲染分开；可见性不决定进程存活 |

依赖在 `main.cpp` / CompositionRoot 集中组装。页面接收类型化 ViewModel，避免一个全局 AppController 承担所有职责；页面路由使用明确枚举，不拿脚本执行命令字符串决定页面。

Qt 原生支持 QML 与 C++ 对象交互，可通过元对象系统暴露属性和方法；相关基础见 [Qt QML/C++ 集成](https://doc.qt.io/qt-6/qtqml-cppintegration-overview.html)。QML 列表采用 C++ 模型并定义稳定角色名，参见 [QAbstractListModel](https://doc.qt.io/qt-6/qabstractlistmodel.html)。

### 8.2 边界接口示意

以下是设计契约，不是已存在的可编译实现：

| 接口 | 输入/输出与职责 |
| --- | --- |
| ScriptRepository | list/load/save/remove/import/export；原子保存、版本迁移 |
| ScriptViewModel | selectedScript、draft、parameterModel、validationErrors；saveDraft、requestRun |
| ExecutionService | start(ExecutionRequest) → executionId；输出、状态、退出码；stop(executionId) |
| SessionManager | create/resize/write/interrupt/close；稳定 sessionId；绑定具体运行时版本 |
| TerminalSelection | snapshot(sessionId) → 纯文本及选区来源；不访问剪贴板 |
| ScriptService | createDraftFromSelection(snapshot, language) → draftId；不执行文本 |
| PluginManager | availableVersions、installedVersions、activeVersion、installTask；install/activate/repair/rollback |
| PythonEnvironmentService | resolveBinding、probeDependencies、installPackages；返回真实解释器、venv 和环境快照 |
| NavigationViewModel | requestPage(Terminal) 检查 PowerShell 状态，返回终端或引导状态 |

用 `Q_PROPERTY` 提供可观察状态，用 signal 通知变化，用 `Q_INVOKABLE` 或 slot 接收命令。耗时操作返回任务 ID，通过进度/结果信号完成，不阻塞 QML 等待。输出和插件错误使用结构化错误码加用户可读消息。

### 8.3 终端实现策略

Windows 使用 ConPTY 承载交互进程，宿主负责显示、输入与生命周期。ConPTY 不是现成的终端 UI，也不提供完整选区/查找/渲染组件：[Microsoft Pseudoconsoles](https://learn.microsoft.com/en-us/windows/console/pseudoconsoles)。

- 参考现有 C++ `TerminalItem` 与 libvterm 处理 VT、屏幕状态和选区；抽离当前组件内部的会话缓冲区，使其由 SessionManager 长期持有。
- 参考现有 NativeConPty 的伪控制台、管道和进程创建逻辑，改为 C++ RAII 管理句柄，并用独立读写任务防止管道阻塞 UI。
- 为选区增加明确的只读文本快照接口；现有组件有内部 selectedText 实现，但不能只依赖 copySelection 来实现新建脚本。
- 现有 QQuickPaintedItem 可用于建立功能基线；其绘制方式不构成高性能保证。根据性能门槛决定是否改用 QQuickItem/Scene Graph、字形缓存和脏区域绘制。
- 输入、终端状态解析、缓冲区修改与渲染之间明确线程所有权；通过消息/快照传递，禁止渲染线程直接操作进程或无锁读取可变缓冲区。
- resize 同时更新终端行列和 ConPTY 尺寸；关闭时先协调读写任务退出再释放相关资源，覆盖阻塞读和异常退出情形。

### 8.4 线程与资源

- GUI 线程：QML、ViewModel、列表模型变更、用户交互；模型通知仅在所属线程发出。
- 工作线程/异步事件循环：下载、解压、摘要计算、依赖安装、进程管道和终端解析；避免同步 waitForFinished 或大文件读取阻塞 GUI。
- 使用有界队列与批量输出通知，限额控制滚动缓冲，不能为每个字节创建一个 QML 事件。
- 每个任务捕获插件版本和环境绑定；PluginManager 维护引用计数或租约，防止卸载正在使用的版本。
- 异常退出、取消、升级与正常退出遵循同一资源释放路径；仅操作归本应用所有的进程和目录。

## 9. 数据模型与存储

首版使用版本化 JSON 与独立脚本源码文件，避免引入不必要的数据库。仓储接口允许未来迁移存储实现。

脚本元数据包含：`schemaVersion`、`id`、`revision`、`title`、`description`、`icon`、`language`、`sourcePath`、`parameters`、`workingDirectory`、`environment`、`timeoutSeconds`、`confirmBeforeRun`、`executionMode`、创建/修改时间；使用次数、最近使用和排序保存在独立用户状态中。

脚本 language 为 `python | powershell | cmd`；旧 PopTools `batch` 映射为 `cmd`。共享包内嵌代码和元数据，不能只传本机绝对 sourcePath。数据导入验证版本、路径和语言，不自动执行脚本。

建议使用 Windows 当前用户本地应用数据目录，以下为逻辑布局：

```text
UTerminal/
├─ settings.json
├─ state.json
├─ scripts/<id>/definition.json + source.py|source.ps1|source.cmd
├─ themes/
├─ plugins/
│  ├─ catalog-cache.json
│  ├─ active.json
│  ├─ python/<version>-<arch>/runtime/ + env/ + installed.json
│  └─ powershell/<version>-<arch>/runtime/ + installed.json
├─ staging/                 下载与解包临时文件
├─ outputs/<execution-id>/
├─ backups/
├─ updates/
└─ logs/
```

设置、脚本和活动版本记录原子写入；替换前保留可恢复备份。源码和元数据需要一致提交或恢复日志，不能出现元数据指向未保存源码。损坏文件隔离并提示，不阻止所有脚本加载。

脚本集合导出只包含脚本和必要元数据，不混入解释器、环境包、终端历史和更新缓存。未来若提供全量备份，使用独立命名和范围说明。

## 10. 更新、安装与构建规划

- 主应用更新与运行时插件升级是两个独立流程；主应用可以离线启动，不必等待更新检查。
- 首次安装不附带或强制安装 Python/PowerShell 7；Qt、终端核心和必要资源必须随主应用可用。
- 计划使用 C++20、Qt 6、CMake、MSVC 工具链；Qt 的具体版本、最低 CMake 版本及架构组合在建仓时锁定并写入 CMakePresets/CI，不把某个“最新版本”作为浮动依赖。
- Qt 模块规划：Core、Gui、Qml、Quick、QuickControls2、Network；测试使用 Qt Test，归档解压采用经评估的库并锁定版本。
- 使用 Qt QML 模块注册和资源打包，C++ 原生终端随应用编译/部署，不再经 Python ctypes 动态注册。
- 安装包包含主程序、Qt 运行库、QML 模块、终端依赖和许可证说明；不会因机器没有 Python 或 PowerShell 7 而启动失败。
- 发布源、插件目录服务地址、签名机制、Windows 安装器和更新替换方案在实现前确定；不得在文档中虚构已可用的下载链接或安装命令。
- 对 Qt、libvterm 和其他依赖保留授权及第三方声明，发布前核对所采用发行方式的要求。

建议新仓库结构（尚未创建）：

```text
UTerminal/
├─ CMakeLists.txt
├─ CMakePresets.json
├─ README.md
├─ src/
│  ├─ main.cpp
│  ├─ application/
│  ├─ domain/
│  ├─ presentation/
│  ├─ infrastructure/
│  └─ terminal/
├─ qml/
│  ├─ App.qml
│  ├─ pages/
│  ├─ components/
│  └─ theme/
├─ resources/
│  ├─ plugin-bootstrap/    Python helper 与 PowerShell profile
│  ├─ themes/
│  └─ icons/
├─ tests/                 单元、集成、UI、终端兼容、性能
├─ third_party/
├─ packaging/
└─ docs/
```

## 11. 从 PopToolProject 继承什么

本节路径为旧项目中的定位标识，表示参考实现，不表示直接依赖旧 Python 应用。

| 旧实现 | UTerminal 的处理 |
| --- | --- |
| `domain/models.py`、`parameter_templates.py` | 将工具数据、参数规则与兼容测试迁移到 C++；仅保留目标脚本类型 |
| `tool_registry.py`、`json_tool_repository.py`、`custom_tool_transfer.py` | 重写为脚本服务/仓储；保留管理、分享和导入行为 |
| `app_controller.py`、`tool_list_model.py` | 拆成脚本 ViewModel、执行服务、参数服务和列表模型 |
| `execution_manager.py`、`execution_coordinator.py` | 迁移运行、并发、超时和输出逻辑；移除投屏专用名额与分支 |
| `python_environment.py`、`python_doctor.py`、`resources/python/sitecustomize.py` | 保留真实解释器执行 + 私有依赖环境的一致性；新增按需安装、多版本和迁移 |
| `powershell_plugin.py` | 借鉴版本目录、下载、SHA-256、解压校验；新增目录发现、活动版本、升级、租约和回退，旧实现不等于完整升级系统 |
| `developer_console_controller.py`、`conpty.py`、`native_conpty.py` | 将会话与插件编排迁移 C++，解除“PowerShell 终端必须先有 Python”的旧依赖 |
| `native/terminalitem.*`、libvterm | 评估复用并重构；增加选区快照、视图与缓冲区分离、分屏和兼容性验证 |
| `powershell-terminal-profile.ps1` | 保留受管 Python/pip 路由与 PSReadLine 接入；去掉 ADB，Python 缺失时提供友好提示 |
| `config_store.py`、`theme_catalog.py`、`app_updater.py` | 迁移需要的配置、主题和更新规则，缩小数据范围 |
| QML 自定义与编辑组件 | 参考交互和表单，不复制全局窗口耦合；将非视觉 JavaScript 逻辑迁到 C++ |

可导入旧版 `poptools.custom-script` 分享格式和本地脚本集合：映射语言、参数和图标，读取随包附带的源码，备份与显示转换结果。旧数据中 Bash、普通 process、URL、internal 或 Android 专用参数属于不支持项，应逐条报告并保留原文件，不静默改成另一种脚本。未选择迁移的旧用户数据保持原样。

## 12. 实施顺序

1. **工程与接口**：建立独立 CMake 工程、三页导航、主题、设置仓储、模型接口；证明无 Python/PySide6 可启动。
2. **运行时插件**：实现目录、版本记录、安装、校验、取消、修复、PowerShell 升级/回退、Python 私有环境。
3. **终端基础**：ConPTY、VT 核心、多标签、输入输出、选择、滚动、尺寸同步，完成真实 Shell 验证。
4. **脚本集合**：编辑保存、参数、分享导入、搜索排序、执行并发、缺插件提示、依赖诊断与安装。
5. **选区工作流与终端完善**：完整右键菜单、选区转草稿、分屏、查找、中文/Emoji/TUI、快捷键和性能。
6. **交付**：主题与更新策略、安装包、升级迁移、旧脚本兼容及完整验收。

这是分阶段交付顺序，不是缩减目标；完成前述早期阶段不能称为已达到完整产品范围。

## 13. 验收清单

所有勾选项均为待实现、待验证。自动测试和人工验收需同时记录系统版本、架构、Qt 版本及插件版本。

- [ ] 机器没有 Python、PySide6、PowerShell 7 时，应用可以启动，三个导航入口可访问。
- [ ] 点击终端且未安装 PowerShell 7 时出现安装提醒；取消不启动系统 Shell，不反复弹窗或丢失其他页面状态。
- [ ] 仅安装 PowerShell 7 后终端可用；未安装 Python 不阻止 Shell 启动。
- [ ] 选择 Python 类型并输入代码时提示安装；取消后代码可保存；运行时重新校验并阻止缺插件执行。
- [ ] Python、PowerShell、CMD 脚本创建、编辑、删除、参数输入、图标、搜索、四种排序、最近使用、分享、集合导入导出工作正常。
- [ ] 同一脚本重复启动、并发满额、确认替换、超时、异常退出和停止进程树行为正确；输出不会串到其他脚本。
- [ ] 右键五项菜单完整；无选区时复制和添加脚本禁用；菜单关闭前后选区快照稳定。
- [ ] 选区创建弹窗完整预填中文、多行、缩进与长行文本；不污染剪贴板；默认语言可改；保存/取消均不执行代码。
- [ ] 清空不终止命令；停止首先中断；强制结束仅影响指定会话；其他标签/窗格继续运行。
- [ ] 多标签、分屏、查找、键盘焦点、中文 IME、宽字符/Emoji、字体回退、DPI 切换与 resize 正常。
- [ ] PSReadLine 补全/历史、Python REPL、一个全屏 TUI、ANSI/备用屏幕、交互输入和鼠标报告通过测试；右键始终为宿主菜单。
- [ ] 运行中切换导航、主题或重新创建终端视图，不丢会话和输出。
- [ ] 插件下载取消、断网、校验失败、磁盘不足、损坏包、错误架构不会破坏现有 Ready 版本。
- [ ] PowerShell 升级后新会话使用新版本、旧会话继续旧版本；新版本失败可回退，使用中的版本无法卸载。
- [ ] Python 脚本、Doctor、pip、终端 python/pip 对应同一个受管环境；系统 Python 与系统包不影响结果。
- [ ] Python 切换版本重建环境并重新安装依赖，失败可保留旧环境；运行中任务不被覆盖，环境变更有互斥控制。
- [ ] 应用检查更新遵循设置，安装不会静默中断会话，插件策略与应用更新策略独立。
- [ ] 旧版脚本导入支持语言和参数映射，不支持项有明确报告，旧文件与导入前数据可恢复。
- [ ] 退出、进程崩溃、安装中断及配置损坏后可恢复，没有孤儿进程、泄漏句柄或永久锁定的安装任务。
- [ ] 发布安装包在干净 Windows 环境验证 Qt/QML/原生终端依赖完整，第三方声明齐全。

性能验收需在固定测试机上与同机 Windows Terminal 对照记录，不先宣称“原生性能相同”。建议门槛：4 个活动窗格持续输出测试持续 10 分钟，输入到显示 p95 不超过 100ms，页面交互没有超过 200ms 的持续主线程停顿，达到配置的滚动历史上限后内存趋于稳定；另做启动时间、百万行输出、窗口缩放、中文选区和长会话测试。测试负载与测量工具在实现阶段固化，未达标时优化渲染/队列，不删减交互能力冒充达标。

## 14. 架构决策摘要

新增验收要求（2026-09-13，2026-09-14 更新）：在 Windows 11 资源管理器优先提供一级右键菜单“在 UTerminal 中打开”；无可信签名或注册失败时，允许自动降级到“显示更多选项”中的旧式菜单。点击后进入应用终端界面；有效文件夹使用该目录，文件使用所在目录，无效路径或非文件系统位置使用用户主目录。安装和卸载负责注册、清理两种菜单；一级菜单注册成功后移除旧式入口以免重复。

**QML 负责界面表达，C++ 负责状态、业务、系统接口与终端核心。Python 和 PowerShell 7 是可选、受管、可切换的外部运行时；应用本身始终不依赖它们启动。**

保留简单 QML 绑定和点击调用，不追求删除每一个 JavaScript 表达式；复杂循环、参数解析、依赖诊断编排、文件操作和升级状态机集中到服务层。终端选区通过显式数据接口进入共用脚本编辑器，页面不直接控制运行时文件、进程句柄或插件目录。
