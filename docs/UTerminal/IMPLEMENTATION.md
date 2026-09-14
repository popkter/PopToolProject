# UTerminal 实现与验收记录

本文件记录当前分支的真实进度；需求以同目录 README.md 为准。当前仍在开发，不能把已有安装包视为全部功能已验收。

## 已建立

- 2026-09-14 Explorer 传统菜单修复：实际界面对照确认 Directory/Background 上的 MultiSelectModel=Single 会隐藏空白处入口，移除后带图标菜单立即显示；重启 Explorer 单独不能解决。安装器直接注册 HKCU 四类静态菜单并通知关联刷新，覆盖安装删除旧版空白处 Single 属性；手动注册脚本同步修正。隔离安装身份用于注册/卸载验证，测试结束恢复实际用户安装目录的菜单。

- 2026-09-14 标签栏溢出定位：ListView.currentIndex 绑定 Sessions.currentIndex，在索引、数量、宽度及内容宽度变化后通过 Qt.callLater 合并定位，forceLayout 后用 ListView.Contain 仅滚动所需距离；空列表跳过。保留现有标签宽度与横向滚动，后端会话逻辑不变。Debug 定向用例覆盖最小窗口连续新增 9 个标签（含第 7 个）、首尾切换、nextTab 快捷键入口、关闭末尾、窗口放大缩小、已可见项不移动及空列表；同时真实鼠标关闭回归通过。记录 build/tab-visibility-tests.txt 与 tab-visibility-resize-tests.txt；Debug 构建已更新，未执行完整回归或重新打包。

- 2026-09-14 终端关闭崩溃与工具按钮：用户使用的 build/uterminal-debug/UTerminal.exe 在关闭 PowerShell 标签时复现退出码 0xC0000374。根因为 Ninja 的 MSVC /showIncludes 前缀编码错误，sessions.cpp 的依赖记录为 0；terminalitem.h 于 07:09 更新，而 sessions.cpp.obj 仍为 00:23 的旧对象。反汇编证实旧 Pane 构造函数按 0x258（600）字节分配 TerminalItem，新布局需要 0x2A8（680）字节，混合链接造成堆损坏，在关闭释放时触发。CMake 现用原始字节探测实际编译器前缀并固定语言环境，不依赖本机缺失的英文语言包；配置无法探测时直接报错。重建污染的 Ninja 产物后，依赖为 299 项并包含 terminalitem.h；原路径 Debug 程序已更新，原 PowerShell 复现退出 0。新增真实 QML 鼠标关闭回归，覆盖后台、当前及最后一个标签，与最后窗格关闭用例共 4 项通过（含初始化/清理），结果 build/tab-close-fixed-tests.txt；依赖证据 tab-close-fixed-dependencies.txt、旧/新对象反汇编 tab-close-old-sessions.asm 和 tab-close-new-sessions.asm。未改动关闭业务逻辑。新增 IconActionButton，三个工具按钮共用 7px 圆角、主题按压色、悬停和焦点边框；实际 Debug 预览的按压态截图 terminal-toolbar-pressed.png 已检查，无 QML 错误。本轮仅重建受影响的 Debug 程序与定向测试，没有重打安装包。

- 2026-09-14 Figma 弹层与标签栏统一：通过本机 Figma APP 查看自定义页旁的确认弹窗、终端菜单与标签、设置页展开的下拉列表，未使用 Figma MCP。新增 AppDialog、AppMenu、AppMenuItem、AppMenuSeparator、PopupSurface，共用圆角、细边框、轻阴影、主题颜色和蓝底白字高亮；各应用内 Dialog 接入统一标题与按钮区，删除/退出采用红色操作与蓝色取消。SelectField 补齐展开列表样式。终端标签改为圆角、文字居中、上下各 8px 留白；移除被 ListView 接管的 delegate y 偏移，同时约束工具按钮高度，实测标签视口 y=8、height=32（栏高 48），关闭按钮采用透明圆形背景。使用已有 Release 程序加载 QML，在隔离预览资源中打开真实组件；浅色下拉、深色确认、编辑器与双标签菜单截图已检查，无新增 QML 错误，编辑器定向 smoke 退出 0。最终终端截图 build/figma-terminal-styled.png 在清空显示后捕获，仅证明布局；较早终端预览的 PSReadLine 历史路径受沙箱限制，不作为终端兼容性验收。本轮没有完整重编译或打包；已同步两个本地构建目录的 QML，正在运行的用户实例未重启。新增 QtQuick.Effects 由现有 windeployqt --qmldir 在下次打包时收集，安装包仍是旧快照。

- 2026-09-14 脚本备份失败保护：检查执行环境后确认 CMD/PowerShell 同样继承托管 Python 路径，保留依赖维护锁以避免运行期间环境被改写。本轮修复 Scripts::persist 忽略 backupFile 失败的问题：现有定义必须先成功备份，再写入新源码和提交定义；失败时报告原因，保留原文件和待保存草稿。新增故障注入回归，将隔离数据中的 backups 路径占为普通文件，验证编辑及覆盖导入均失败、原定义字节与目录文件列表不变、重新加载仍为旧源码；移除测试障碍后保存成功，备份定义对应的旧源码仍可读取。Release 三组回归通过（7.87 秒，build/backup-preservation-build.log），现有 Debug 实例未关闭。此验证覆盖备份目录不可用，不等于已模拟全部磁盘不足、断电或多进程写入情形；当前安装器仍为上一轮页面修复快照，尚未包含本次改动。

- 2026-09-14 详情布局安装包刷新：最新 `build/installer/UTerminal-0.1.1-win-x64-setup.exe` 为 28,244,776 字节，SHA-256 `37bc42ad45ce5a4ed3433339471519df081bf1b5004fe101bb69a4a0c50e8eb0`，已包含空目录迁移和长说明/参数布局修复。展开部署包移除源码/Qt/QML 环境变量、仅系统 PATH 启动并完成第 12 参数滚轮检查，退出 0，无新增应用日志；主程序和 ScriptsPage.qml 哈希与当前构建/源码一致，压力测试程序未打包（build/details-package-results.json）。此轮验证为展开部署启动，未重复实际安装、升级或卸载；不代替干净 Windows 环境验收。

- 2026-09-14 本机 Figma 与详情布局：通过 computer-use 读取本机 Figma 的 PopTools / Screen 自定义（1362×1024）页面，核对左列表、右详情及底部深色输出结构，未调用 Figma MCP。复现最小窗口长说明将运行按钮和输出区推出窗口的问题（build/long-details-before.png）；说明改为三行纯文本预览，可打开完整说明弹窗滚动阅读，分享操作顶部对齐。进一步复现 12 参数场景中的固定高度溢出，参数区改为可收缩、有可见滚动条的区域并显示总数，限制滚动边界，保留运行按钮及至少 160px 输出面板。Qt 窗口滚轮事件检查已确认第 12 项完整可见；说明弹窗检查全文一致、可达末尾；深浅色三组冒烟均退出 0，新增日志 0 字节（build/details-layout-results.json），截图已检查。Release 三组回归通过 7.91 秒（build/details-layout-build.log），后续仅调整 QML 边界及冒烟诊断并重新验证。安装包暂未包含本次页面和此前空目录改动；完整界面/交互验收仍在继续。

- 2026-09-14 输入到帧测量：独立四窗格测试新增 `--input-probes`，Qt 按键经生产 TerminalItem/ConPty 到真实子进程，只有回显颜色实际进入绘制像素并随后 frameSwapped 才结束计时。修复测试负载初始尺寸调整后状态行失效问题，探针跨 GUI/渲染线程状态有互斥保护。断开按键传输反向校验得到 18 次超时、0 成功样本、无绘制停滞并退出 1；正常一分钟运行 60.227 秒退出 0，共 105 个样本、p95 43.0412ms、最大 55.5097ms，无超时或待完成探针，四窗格均有样本。截图状态色块、中文与 Emoji 已检查，所有测试进程已退出。方法与范围详见 PERFORMANCE.md，结果 build/input-frame-60.json；不含物理键盘/显示器、完整应用页面和真实 Shell/Windows Terminal 对照，不能代替完整十分钟输入验收。此轮只改测试目标与记录，未修改主程序或重新生成安装器。

- 2026-09-14 四窗格可见重测完成：会话 29203 运行 600.251 秒后退出 0；宿主 PID 53724 及四个测试子进程均已退出，原 Debug PID 62256 保留。120 次采样均 visible/exposed，stalledRenderIntervals=0；各窗格接收约 24.8 MB，保持 10,000 行历史，截图中文/Emoji/颜色已检查。启动 5 秒后心跳 p95 3.9781ms、最大 10.6937ms，全程最大仍为 332.0451ms。30 秒后私有内存 301.26–303.88 MiB，末两分钟 303.46–303.88 MiB、拟合约 +0.18 MiB/分钟；统计工具本身保留采样，不能据此证明完全无泄漏。证据与机器信息、范围和遗留问题已整理至 PERFORMANCE.md，原始结果 build/render-benchmark-visible-600.json，独立摘要同名 -audit.json。该结果仅完成四窗格持续输出/绘制负载验证，不代表输入延迟、应用交互、Windows Terminal 对照或完整性能验收已通过。启动/首轮绘制峰值与小幅内存增长仍需定位。

- 2026-09-14 持续绘制测量纠错：原十分钟会话 15886 已正常结束，600.253 秒、四路各约 24.86 MB 输出、历史均为 10,000 行。但在 440 秒至结束的观察中帧计数始终为 33,390，因此不能把该轮的旧 `workloadComplete=true` 当作持续绘制通过。保留原始数据并另存 build/render-benchmark-600-audit.json；启动后心跳 p95 6.2596ms / 最大 82.6748ms、末两分钟私有内存 315.43–316.41 MiB 仅描述本次混合可见/后台输出过程。测试工具现新增每区间帧数、各窗格 paint 次数、visible/exposed 检查和 `stalledRenderIntervals`，提供 `--keep-visible`。实际隐藏窗口校验结束后 complete=false、stalled=1、退出 1；置顶可见校验 complete=true、stalled=0、退出 0（build/render-benchmark-hidden-check.json / render-benchmark-visible-check.json）。正在以修正工具重测 600 秒，结果路径 build/render-benchmark-visible-600.json；需继续核实运行句柄并取得最终证据，尚未通过完整性能验收。测试机信息已保存 build/render-benchmark-machine.json。

- 2026-09-14 可见终端压力测试：新增不进入安装包的 `uterminal_render_benchmark`，四个真实 ConPTY 输出进程连接四个生产 TerminalItem 控件，记录绘制次数/耗时、主线程心跳延迟、宿主内存与历史行数；方法和范围见 PERFORMANCE.md。20 秒 UTF-8 预检完成且退出 0，四窗格达到 10,000 行历史；截图确认中文、Emoji、ANSI 颜色正常。全程主线程延迟最大 298.088ms，启动 5 秒后 p95 3.4561ms / 最大 4.6115ms（build/render-benchmark-utf8-pilot.json）；启动峰值仍保留，不据此宣称通过全部性能门槛。十分钟测试已于本机 07:53:23 启动，工具会话 15886，宿主 PID 48332，结果 build/render-benchmark-600.json；最后核实 75 秒时会话与五个测试进程仍在运行，无报告错误。此为进行中的测试，必须重新核实进程/会话并取得最终结果后才能报告完成，不因结果暂未更新而重启。尚不覆盖输入到显示、应用导航及 Windows Terminal 对照；正式性能验收继续进行。

- 2026-09-14 附件目录完整性：新增可选 `bundledDirectories`，保存并还原嵌套空目录；旧的仅文件附件格式继续有效。导入与执行前验证目录数组、相对路径、大小写重复及主文件/附件文件冲突，最多 1024 个目录；无效映射在创建目标目录之前拒绝。实际托管 Python 测试在集合导出再导入、移除原始空目录后，断言迁移后的 `cache/empty` 存在且为空，同时验证模块导入和中文资源读取，3 passed / 167 ms（build/attachment-directories-python.txt）。Release 三组回归通过，7.85 秒（build/attachment-directories-build.log）。详情显示文件数和目录数，最小窗口截图 build/attachment-directories-ui.png 已检查。此项解决此前记录的空目录遗漏；当前安装器仍为上一轮发布快照，本次改动已在 Release 工程验证但尚未重新打包。

- 2026-09-14 附件支持发布验证：上述迁移改动已纳入最新安装器 `build/installer/UTerminal-0.1.1-win-x64-setup.exe`，28,239,828 字节，SHA-256 `df541326212774fb5564f2b7340b4d25d5a2bf217aa31174d8250b971d4dbafb`。更新已核实的工作区测试副本 build/uterminal-upgrade-smoke，安装退出 0；未关闭已有 Debug 实例 PID 62256。实际安装版移除源码资源和 Qt/QML 环境变量、仅用系统 PATH 启动成功，二进制与本次 Release 一致，1,406 个安装文件在启动前后路径、大小和修改时间均不变（build/attachments-installed-result.json）。安装版附件详情截图 build/attachments-installed-ui.png 已检查。此项替代下条“安装器尚未包含”的时间状态；不代表干净 Windows、真实 Explorer 点击或完整终端验收已经完成。

- 2026-09-14 脚本附件迁移：旧集合中的 Python/BAT 文件型脚本现在保存主文件名及源码目录下的相邻文件（含子目录），分享和集合导出携带附件，运行时还原到本次独立脚本目录。实际 CMD 测试在分享再导入、删除原资源后仍通过 `%~dp0` 读取附件；实际托管 Python 测试在集合导出再导入、删除原模块和资源后仍能 `import helper` 并通过 `__file__` 读取中文及 Emoji 文本（build/python-attachments-results.txt，3 passed，165 ms）。拒绝越界路径、主文件覆盖、大小写冲突和无效 Base64；每个脚本限制 1024 个附件、64 MiB，不导入符号链接或目录联接。语言切换同步主文件扩展名，保存时拒绝与附件重名，回归验证原持久化脚本不受失败保存影响。Release 三组回归通过（7.91 秒，build/attachments-language-build.log）。最小窗口详情附件数量提示已检查，build/attachments-ui.png，无应用日志错误。当前捕获源码目录内全部文件，不分析实际引用，也尚未保留空目录；这些边界须继续审查。安装器尚未包含本条及前两项迁移改动。

- 2026-09-14 旧默认工作目录迁移：从 develop 的 execution_manager.py 确认旧默认 cwd 为本次输出目录，而新脚本默认为用户目录。旧 executor.cwd 为空的导入条目现在记录 useOutputDirectoryAsWorkingDirectory，执行时先建立本次输出目录再将其作为 cwd；显式工作目录优先，原生新建脚本默认不变。编辑器提供明确复选项和对应占位文字，可自行修改此行为。实际 CMD 回归验证默认 cwd 等于 POPTOOLS_OUTPUT_DIR，编辑为显式目录后按其运行；重新加载保留配置。Release 三组回归通过（7.66 秒，build/legacy-working-directory-build.log）。最小展开编辑器的键盘/边界冒烟通过，截图 build/legacy-cwd-editor.png 已检查，QML 日志为空。附带资源文件与旧源码位置相关的迁移仍未完成；安装器未更新。

- 2026-09-14 旧外部运行要求迁移：核对 develop 中 ExecutorDefinition 和 _tool_uses_adb/_tool_requires_android_device，确认 requirements 是外部运行条件而非 pip 包。导入时映射为 externalRequirements 并严格检查字符串数组；编辑、重载和分享保持原值，详情以纯文本提示运行条件，不自动安装。对依赖旧 android_device 设备选择机制的条目明确拒绝并报告原因；单独 adb 外部工具声明可保留，不恢复内置设备业务。新增迁移回归通过，Release 三组通过（7.29 秒，build/legacy-requirements-build.log）。最小窗口详情截图 build/legacy-requirements-ui.png 已检查，无 QML 错误；样例仅显示，不执行命令。附带资源文件、相对工作目录等迁移范围仍待继续审查。安装器未更新。

- 2026-09-14 真实 PowerShell 升级与部署：从官方发布元数据取得 7.6.2 的归档摘要，在独立目录实际安装 7.6.2/7.6.3，分别校验 116,913,144 / 116,931,488 字节归档。安装新版本后活动版本保持 7.6.2；明确使用 7.6.3 后，两个真实 ConPTY 会话通过 $PSVersionTable 分别返回 7.6.2 和 7.6.3；阻止卸载使用中的旧版本，回退活动版本不结束新版本会话，关闭全部会话后两版租约释放。测试 27.907 秒通过（build/powershell-real-upgrade.txt）。安装包已包含输入法、设置页样式和版本选择改动：28,237,031 字节，SHA-256 `3d919e530a87868fa2e97f98a8442d623e52ce8705e291e31b9daf7068a1cebb`。实际更新既有 build/uterminal-upgrade-smoke 测试安装目录成功、无需系统重启，未关闭正在运行的 Debug 应用。安装版与 Release 主程序哈希一致；仅系统 PATH、无源码资源路径下启动退出码 0，日志为空，安装目录 1,406 文件的路径/大小/修改时间在启动前后完全一致（build/latest-installed-launch-result.json），设置页截图 build/latest-installed-settings.png 已检查。本次验证不等于干净 Windows VM 验收，也未重复卸载或实际 Explorer 菜单点击。

- 2026-09-14 PowerShell 升级应用时机：按 README 7 节要求，已有可用活动 PowerShell 时，安装其他版本只完成安装并提示点击“使用此版本”，不立即修改活动记录；用户明确使用已安装版本时才切换。首次安装/修复当前版本仍按原路径启用，Python 保留依赖迁移确认流程。新增状态流回归以可控网络和轻量进程夹具完成下载→解压→验证→提交链路，断言安装后内存/磁盘仍指向旧版本、旧租约保留，显式使用后切换且不重复下载；此夹具不代表真实 PowerShell 升级兼容性验收。Release 三组回归通过（7.34 秒，build/powershell-upgrade-selection-build.log）。安装器未更新，真实多版本升级及完整 UI 点击链仍待验证。

- 2026-09-14 设置页 Figma 对照：通过本机 Figma APP 读取 Screen / 设置画板（1362×1024，73%），未调用 Figma MCP。按画板的带图标主题选项与边框下拉样式，为浅色/深色/系统选项补图标和选中强调，三项等宽；终端配色、应用更新策略、插件更新策略统一使用 SelectField，保留现有设置绑定和事件。独立测试数据下浅色/深色最小窗口渲染无 QML 错误；截图 build/settings-figma-light.png、settings-figma-dark.png，等宽调整后的最终深色图 build/settings-figma-final.png。没有恢复设计稿中已经排除的 Android 等功能。本轮不新增业务测试，不据此声明整页逐像素一致；下拉展开与选择操作、完整长页滚动尚待验收。安装器暂未更新，不含这次样式与上一轮输入法改动。

- 2026-09-14 输入法预编辑：改用 QTextLayout 统一测量与绘制预编辑，支持输入法 TextFormat 与 Cursor 属性（包含光标隐藏/颜色），不再按 UTF-16 字符数量估算中文/Emoji 宽度；候选光标使用同一布局坐标，长预编辑在右边缘保持光标可见。聚焦终端的光标/字体/网格改变时通知 QInputMethod 更新坐标，并避免相同坐标重复通知；失焦清除本窗格预编辑，预编辑输入回到滚动底部。新增测试验证预编辑不提前发送、提交中文 Emoji 完整、格式背景确实绘制、右边缘位置、失焦及字号变化。Release 三组回归通过（7.13 秒，build/terminal-ime-build.log）。依据 Qt 的 QInputMethod/QInputMethodEvent 文档实现；这些是 Qt 事件与绘制验证，尚未完成 Windows 拼音候选框、真实 IME 切换或跨屏 DPI 的人工验收。本轮未更新安装器。

- 2026-09-14 安装中断恢复：解压前原子写入 installing.json，存在该记录时插件不得判为 Ready；验证成功写入 installed.json 后必须成功清除未完成记录才能激活。修复旧 installed.json 残留、修复途中可执行文件重新出现时误判 Ready 的漏洞。运行时测试模拟此残缺状态，失败后重新创建管理器仍阻止激活，Release 三组回归通过（7.03 秒）。在独立空目录 build/plugin-commit-verification 实际安装官方 Python 3.13.14 并验证 Unicode 输入，8.836 秒通过；随后写入中断记录、删除该测试运行时的 Lib/colorsys.py，正式重试恢复同一文件 SHA-256、清除未完成记录并重新验证输入，5.540 秒通过（build/plugin-repair-integration.txt）。此检查不等于已经覆盖任意安装阶段强杀、磁盘不足或多进程并发修复。安装器已包含本次修复及版本刷新状态隔离：28,237,066 字节，SHA-256 `c7951278befc5a36a60c2f2c8b9d2145d1770c3c2ea011ec4acc7d9ac5b17737`。本轮未重复验证应用安装/升级/卸载链路。

- 2026-09-14 插件刷新状态隔离：修复先刷新版本再开始安装时，迟到的网络响应覆盖安装/取消文字的问题。C++ 新增独立 catalogStatus/catalogRefreshing，合并重复刷新请求，拒绝无效 JSON/非数组响应并报告缓存写入失败；管理对象销毁时结束自身刷新请求。插件弹窗与设置页分别呈现版本刷新结果和安装状态。通过注入可控网络响应验证新增版本确实进入列表、下载中的状态保持、取消后迟到的无效响应/超时不覆盖安装结果、重复刷新只发起一次、退出取消请求。Release 三组回归通过（7.11 秒，build/plugin-refresh-final-build.log）。最小窗口两页加载无 QML 错误，截图 build/plugin-refresh-dialog.png、plugin-refresh-settings.png 已检查；截图为无刷新任务的初始状态，长错误文字与并发下载的实际视觉布局尚未覆盖。本轮未重新生成安装器，上条安装器不含此修复。

- 2026-09-14 REPL Unicode 修复：直接启动与经 PowerShell 启动 Python 3.13.14 均复现 Emoji 丢失。测试专用原始键事件记录确认，本机 ConPTY 将两个代理码元放在 VK_MENU 键释放事件中；原 CPython REPL 忽略释放事件。新增 plugin-bootstrap/repl_unicode.py，仅在托管 Windows Python 3.13 的交互入口启用，识别 Alt 释放字符、合并代理对、保留普通键释放语义及非阻塞读取，不禁用原 REPL。临时事件记录代码已移除。六项 Python 边界测试通过；最终真实集成结果 build/terminal-repl-final.txt：两条 REPL 路径、原始 Unicode 输入、普通脚本参数、关闭分屏隔离全部通过（含初始化/清理 7 项，1.846 秒）。Release 三组常规测试通过（7.05 秒）。安装器更新为 28,226,267 字节，SHA-256 `3b5c9b7725803e42815d74c9e9e932aea65a0ebb5124b3222d8a972ca135be3c`，包含历史队列优化；部署目录内两个 bootstrap 文件哈希与源码一致。此修复涉及 CPython 私有 REPL API，未来 Python 版本需单独验证；本轮未重复执行安装/升级/卸载，也不能据此认定真实 IME 或全部交互程序验收完成。

- 2026-09-14 真实交互诊断：新增 pythonConsoleUnicodeInput，使用已安装 Python 经 ConPTY 读取标准输入，中文与 Emoji 的代码点 0x4e2d、0x6587、0x1f642 全部完整到达，Release 实测通过（build/terminal-unicode-input.txt）。powerShellCompletionAndPythonRepl 中 PSReadLine Tab 补全与进入 Python 提示符通过，但输入 print('中文' + '🙂-repl') 后，原始输出显示输入回显和结果均丢失 Emoji；该测试仍明确失败，未降低断言。诊断日志 build/terminal-repl-diagnostic.txt。当前证据将范围缩小到交互 REPL 链路，不能宣称全部 Unicode 交互验收通过；CPython 官方类似问题 https://github.com/python/cpython/issues/136595 仅作定位线索，尚未证明与本例根因相同。下一步需对比直接启动 REPL 与 PowerShell 包装入口，并验证兼容修复；本轮未更新安装包。

- 2026-09-14 终端历史性能：滚动历史满一万行后，原 vector 每行 erase(begin) 会移动整个历史数组；改用 deque/pop_front 保持索引访问与双向回填。新增独立 uterminal_terminal_benchmark（不纳入常规 CTest），固定 900×600 终端、每批 100 行、带真彩色与中文 Emoji，校验一万行上限、最旧内容淘汰和最新文本保留。Release 同机十万行单次对比 875.24 → 214.56 毫秒，批次 p95 1.061 → 0.319 毫秒；百万行 2007.12 毫秒、p95 0.215 毫秒，保留检查通过。三组回归通过（6.95 秒）。这些是 VT 解析和历史维护数据，不包含真实绘制输入延迟，也不能替代四窗格十分钟和 Windows Terminal 对照验收。结果文件 build/terminal-history-before.json、after.json、million.json（后两者共用 terminal-history- 前缀）。

- 插件弹窗最终部署验证：仅系统 PATH、无源码资源回退的浅色最小窗口运行成功，无 QML 错误；包内 PluginDialog.qml 哈希与源码一致，截图 build/plugin-dialog-release.png 已检查。安装器 28,229,477 字节，SHA-256 `e9c3f5c59232dd8f5c5a009ff1d9b7ce5ece542df93d4abcf21b12e341d12a4e`。本轮没有重复运行实际安装/升级/卸载。

- 2026-09-14 插件弹窗：统一圆角、图标、标题及 SelectField，明确当前活动版本、所选版本是否已安装，区分安装与切换操作并禁止重复应用当前健康版本。C++ 暴露当前任务类型/版本与取消请求状态；打开其他插件弹窗时仍能辨认共用任务，取消后显示正在取消且禁止重复请求。状态文本按纯文本滚动显示，操作栏保持固定。使用空数据和已有真实 PowerShell 7.6.3 测试数据的最小窗口截图检查通过，未触发安装或切换。Debug 三组测试通过（7.91 秒），Release 三组通过（7.11 秒）；新增取消测试在网络事件循环开始前终止请求，验证任务元数据、取消通知及临时归档清理，不下载运行时。完整长日志滚动、安装中切换弹窗和版本切换点击链仍待 UI 验收。

- 编辑器滚动条补充：实际浅色截图发现替换 ScrollBar 实例导致定位为左上角圆点，已改为配置 ScrollView 内置滚动条；修复后的 editor-layout-scrollbars.png 显示右侧正常竖向滚动条。最小展开状态的 Qt 交互与边界检查再次通过，日志无错误；使用已验证 Release 二进制重新打包 QML，包内 ScriptEditor.qml 哈希与源码一致。最终安装器摘要以 build/installer/SHA256SUMS.txt 为准，下方数字是该修复前的历史快照。

- 2026-09-14 编辑弹窗布局：沿用已读取的 Figma 页面色彩、圆角与表单风格，统一语言显示名称和 SelectField；代码区增加边框与焦点状态。运行目录、超时、环境等配置改为可展开滚动区域，保存栏固定在外层。实际最小 1000×700 窗口曾出现展开配置后保存栏超出弹窗底边，现通过限制配置区高度修复；验收入口同时检查代码区最小高度及保存按钮在弹窗内容区内。常规、最小、展开状态的 Tab/Shift+Tab/Ctrl+Z/Ctrl+Y、草稿同步、缺插件提示不重复均通过；深浅色截图已检查，无 QML 错误。Debug 三组测试通过（7.57 秒），Release 三组通过（6.87 秒）。安装包更新为 28,235,906 字节，SHA-256 `0dc7be5d265b0d72d349554862a8d60021f726aba79de9941794451b6600b83c`；部署版仅系统 PATH 的最小展开浅色编辑器验证通过，截图 build/editor-layout-release-light.png。当前 Figma 已读取的是主页面参考，不能将本次适配称为单独编辑弹窗设计稿的逐像素验收；真实滚轮与完整表单操作、其他插件弹窗仍需继续检查。

- 2026-09-14 详情页 Release 验证：三组测试通过（6.99 秒）；安装包已包含本轮 C++ outcome 接口、详情页和 SelectField 组件，大小 28,225,277 字节，SHA-256 `6d95d16d062d2d1550e71a4eed9e47a995be7c3e8241e8b1f0f9aadd0c29aafa`。部署 QML 哈希与源码一致，仅系统 PATH、无源码资源回退的详情页启动通过，日志无错误。本轮未重复实际安装，完整 UI 交互和其余验收仍未完成。

- 2026-09-14 Figma 详情页对齐：通过本机 Figma APP 重新读取 Screen / 自定义（97:75，1362×1024），补齐脚本详情图标底色、语言标签、参数说明、必填/可选标识，以及输出区底部的退出码/耗时。C++ 提供独立 outcome 状态，输出标题显示运行中/已完成/未成功，避免把非零退出显示为成功。下拉框新增 SelectField 统一边框与箭头；修复 choice 在模型初始化前执行 indexOfValue 导致首次默认显示为空的问题（绑定显式依赖 count）。Debug 三组测试通过（7.63 秒），真实 CMD 成功和交互非零退出/超时状态回归通过；浅色、深色及修复后参数页截图已检查，无 QML 错误。最终浅色截图 build/figma-detail-final.png。本次没有使用 Figma MCP；编辑弹窗、插件弹窗及完整点击交互还需继续验收。

- 2026-09-14 00:24 Release 快照：三组回归通过（6.97 秒），安装包已包含助手缓存回收和未签名菜单降级。UTerminal-0.1.1-win-x64-setup.exe 为 28,227,753 字节，SHA-256 `1fd91dc936f8a66638779c194d4a103f66989d3a6f8bd2b545881314aea5b86f`。部署目录仅用系统 PATH、隔离数据启动成功，日志无错误；设置页截图 helper-cache-package-ui.png 已检查，三个应用二进制哈希与 Release 构建一致。此轮验证是展开部署启动，没有重新执行安装/升级/卸载。

- 2026-09-14 更新缓存生命周期：暂存助手目录带创建时间、创建进程和格式标记；暂存及助手运行持有目录锁。应用启动仅回收超过一小时、创建进程已退出、无活动助手的直属 helper-UUID 缓存；陌生文件、未标记目录和重解析点保留。助手崩溃留下的锁可在后续启动恢复，清理失败保留标记供重试。真实助手等待进程、强制结束、残留锁文件恢复、交接宽限期、创建进程仍运行及陌生文件保护测试通过；Debug 三组回归通过（7.26 秒）。此清理不覆盖旧版无标记目录或已下载安装包。

- 2026-09-14 安装与菜单验证：实际测试副本从 0.1.0 升级到 0.1.1，助手记录 installed / installerExitCode=0，安装后主程序 ProductVersion 为 0.1.1，四个独立数据文件哈希保持不变。根据用户补充要求，未签名 MSIX 注册失败后改为自动注册“显示更多选项”菜单；实际新版 Inno 安装退出 0，无需确认菜单错误框，目录/空白处/文件/驱动器四个当前用户注册项均已核对。专属传统键卸载清理通过。驱动器根路径点后缀、中文空格路径、文件父目录、无效路径与空路径回归通过，Release 三组测试通过（6.86 秒）。实际 Explorer 点击、默认用户数据目录和干净 Windows 环境仍待验收。

- 更新助手结果闭环补充：退出安装前将助手、当前加载的 Qt Core 和 VC 运行库复制到独立 updates/helper-UUID 目录，从该目录启动，避免助手等待安装器时占用安装目录内待覆盖文件。这只在用户选择退出安装时进行，不是启动解压。助手现等待安装器退出并写 installerExitCode，非零/异常退出记为 failed，成功退出记为 installed；设置页仍以实际启动版本达到目标为最终完成依据。原“等待父进程、校验失败、不可执行文件”测试继续通过；新增只含系统 PATH 的缓存助手真实启动和模拟安装器退出 2 的失败记录测试，成功退出 0 状态及 UI installed 文案回归通过。Debug 三组测试全部通过（7.55 秒）。真实 Inno 跨版本覆盖、缓存助手目录回收和长时间安装中断仍待验收；Release 包未包含本轮助手改动。

- 实际安装与卸载数据保留：先核实 HKCU 卸载记录指向 build/uterminal-installed-smoke，且无 UTerminal.ShellIntegration 注册；用最新安装器更新此测试副本，安装退出 0，94 项二进制/字体哈希与包内清单一致。仅系统 PATH、独立 uninstall-retention-data 数据目录运行安装后应用成功，无日志错误。随后重新核实路径、菜单状态及测试进程已退出，运行实际 unins000.exe，卸载退出 0；主程序和卸载注册被移除，四个脚本/源码/用户文件/日志保持原哈希。原调试实例 PID 69344 全程仍在运行。本次不涉及跨版本升级、默认用户数据目录、已签名菜单卸载或干净 Windows VM；这些仍待验收。安装日志 install-retention.log 中记录预期的未签名菜单注册失败；卸载和哈希证据位于 build/uninstall-retention.log、build/uninstall-retention-before.json。测试安装副本现已卸载，安装器文件继续保留。

- 版本来源统一：CMake project VERSION 生成应用编译宏、Windows 文件版本资源与构建目录 version.json；主程序、Updates 回退版本和设置页使用构建版本。打包脚本验证主程序/更新助手/菜单 DLL 的 ProductVersion 后，传给 Inno AppVersion、输出文件名与 MSIX 身份版本，避免旧二进制混包。实际读取三个二进制均为 0.1.0，生成清单为 0.1.0.0，安装器版本为 0.1.0。Release 三组回归通过（6.78 秒）；最新安装包 2026-09-13 23:46，28,224,696 字节，SHA-256 `8233286D3B0C222BCCFB92F37F2C5334A5B67CDB4F7BF10CC5D15F37AF83C66B`，校验文件同步生成。本轮尚未执行跨版本升级或卸载。

- 清理后全新 Release 构建：在此前不存在的 build/uterminal-clean-vs 重新配置、编译并运行三组 CTest，全部通过（6.77 秒）。构建/打包脚本新增可选 BuildDirectory，打包产物的三个应用二进制哈希与此干净构建完全一致，94 项部署清单哈希也一致。最新安装器 2026-09-13 23:41，28,221,802 字节，SHA-256 `0565AB544B8860B19B340F46C939D75D77AD84D82081564703ABE0D24CC11A2B`，已包含全部近期参数迁移改动。仅系统 PATH、独立数据目录启动部署包成功，布尔/秘密/多行参数页面截图 build/clean-package-ui.png 已检查，无 QML 日志错误。CMake Release 测试预设已补齐并由 CMake 列表命令识别。本次尚未重新安装/升级/卸载，普通用户机器的正式右键菜单签名条件仍未满足。

- 旧应用清理完成：确认相关路径相对 HEAD 没有未提交修改后，删除 135 个旧受控文件：src/poptools 主程序、Python/PySide UI、Android/投屏/Jira/飞书等预设业务和资源、旧测试、旧原生终端包装层、main.py、pyproject/锁文件及过时第三方声明。保留 native/third_party/libvterm（含本地补丁）、tests/cpp 和可选插件 bootstrap。清理旧源目录中已核实的生成版本文件、缓存 pyc、旧 DLL 与 Python 安装缓存。原始参考代码仍在提交 64c63663c6d25b338c714c9efc265eedf2fa2ecc，可用 git show 读取；删除清单保存于 build/legacy-removal-manifest.txt。清理后 Debug 构建及三组回归全部通过（6.99 秒），当前应用不存在旧源码依赖。迁移的依赖文件、完整 UI、安装升级卸载等剩余验收仍需继续。

- 秘密参数迁移：支持 secret 类型，QML 输入框使用 Password 与敏感输入提示，并隐藏“设为默认”快捷按钮。普通输出访问器按运行快照中的秘密值做精确文本遮盖，运行中暂缓显示末尾可能属于分段秘密值的前缀；完整命令行不写日志。真实 Python 合成值分两次写出时，各次 UI 输出快照均未暴露值，最终显示 `***`；执行后 runs 临时源码清理、重启输入为空、分享内容不含本次秘密输入均通过。Debug 三组回归通过（7.07 秒），秘密输出和迁移参数集成共 4 项含初始化/清理通过（703ms）。交互终端保留原始程序显示，内存原始输出及程序自行写出的文件不属于该精确遮盖范围；已有模板内明文默认值仍按导入原意保留。密码框实际交互、异常中断与输出截断边界仍待扩展验收，Release 包未更新。

- 迁移参数真实 Python 验收：新增 `migratedParameterExecution`，从旧 executor/parameters JSON 导入后通过实际 Executions 启动受管 Python，分别验证显式 false、显式 true、缺省采用模板 true 三种路径。Python JSON 回传的布尔值、条件 argv 增删、中文 CRLF/空行/缩进/尾部换行、引号/反斜杠、带前导零长整数均与输入一致；同时重跑原 Python argv 集成测试。两项测试加初始化/清理共 4 项通过（584ms），输出 `build/migrated-parameters-results.txt`。本次未下载/安装运行时；复用了已有隔离测试环境。此结果补齐真实 Python 参数执行证据，不代表复选框交互或秘密参数已验收。

- 布尔参数迁移：保留 boolean 类型，模板默认值按旧 QML Boolean(string) 规则决定勾选状态（非空字符串含 `0` 为 true）；运行输入保持 QVariant bool，通过独立 C++ setter 和复选框更新，普通文本 setter 拒绝覆盖。渲染为旧 Python str(bool) 的 `True`/`False`；required=true 的 false 值仍有效。执行入口先填充类型化默认值再过滤旧条件 args，修复默认值未参与条件判断的问题。回归覆盖 false/true 条件参数、默认值、错误字符串输入和重启恢复；Debug 三组测试通过（6.94 秒）。实际复选框点击及真实 Python 布尔参数执行仍需集成验收。秘密参数仍待实现，Release 包尚未更新。

- 多行参数迁移：保留 multiline 类型，QML 使用可滚动纯文本 TextArea；会话输入在切换脚本后保留，执行快照保留中文、CRLF、空行、缩进及尾部换行，重启仍恢复模板默认值。Debug 三组回归通过（6.96 秒）。实际页面截图发现参数区宽度随内容收缩，已将外层参数 ScrollView、ColumnLayout 与内层多行输入宽度绑定到可用区域；修正后截图 `build/multiline-ui.png` 已检查，启动无 QML 错误。尚未验证实际键盘连续输入与嵌套滚动，多行内容保存为模板默认值仍受既有单行占位符语法限制。Release 包仍待更新。

- 参数类型迁移继续补充：integer/number 保留类型与旧版文本传值语义，不做浮点/整数转换，长整数、前导零、科学计数法和可选空值均通过回归；模板显式 choice/file 类型仍优先。directory 保留类型，QML 提供目录选择与拖入；拖入只接受真实目录，拒绝文件/不存在路径且保留原输入，手动输入沿用旧文本行为。类型与默认值重启持久化通过。最新 Debug 三组测试全部通过（7.02 秒）；布尔、多行和秘密类型仍待补齐，目录选择/拖入的真实桌面交互还需验收。当前 Release 安装包未包含这两轮参数迁移改动。

- 旧参数元数据迁移补充：旧 `parameters` 保存为 `parameterMetadata`，文本/文件/选项参数保留显示名称、显式 required 和 placeholder；与旧自定义脚本同步器一致，默认值、选项和文件/选项类型由模板决定，Var/pVal 声明优先决定标签。该元数据贯通编辑保存、默认值修改、导出再导入与实际执行验证；QML 输入框显示提示文字。布尔、数字、多行、目录、秘密等尚未实现的独立参数类型现在明确拒绝导入，避免静默丢失语义，后续仍需实现这些类型。Debug 三组回归全部通过（7.04 秒），新增测试覆盖可选空参数实际 CMD 输出、必填错误标签、声明优先、重启与分享、重复元数据和未支持类型拒绝。本次改动尚未重新纳入 Release 安装包。

- 旧构建链清理：移除 `packaging/` 的六个 PopTools/PyInstaller/旧原生库构建文件及 `.github/workflows/release.yml`。当前 CMake 和新脚本没有引用这些文件。新增手动 `uterminal-package.yml`，使用 Windows 2022 runner、Qt 6.10.3 和当前 Release 构建/测试/安装包脚本，生成安装器与校验清单工件；不发布 Release。两个内嵌 PowerShell 块通过解析，校验清单步骤在本地现有安装包上执行通过；远程工作流尚未推送执行，完整 Actions 语法/运行验收仍待完成。常规 CI 补充 installer 与新工作流路径触发；`.vs/` 和 `.qtcreator/` 加入忽略。旧业务源码和旧测试仍待迁移验收后移除。

- 最新打包验证（2026-09-13 23:10）：Release 三组 CTest 全部通过（6.94 秒）；`UTerminal-0.1.0-win-x64-setup.exe` 为 28,425,819 字节，SHA-256 `C8C72E7A35B99083929DD4F71BC9C7AE3038A33028BD82C2C2E5B836297A131D`。包含近期条件参数/源码导入、插件取消、窗格状态与关闭、第三方组件记录改动。部署目录仅用系统 PATH、独立数据目录启动设置页成功，退出码 0，无 QML 错误；截图 `build/package-notices-smoke.png` 已检查。94 项部署哈希及三个 SDK 原始 SBOM 哈希均一致。本次未重新执行安装/升级/卸载验收，正式菜单签名仍未解决。

- 发布依赖记录补充：打包步骤从当前 Qt SDK 的模块元数据解析部署 DLL 所属仓库，复制对应原始 SPDX JSON；生成实际 EXE/DLL/字体的相对路径、大小与 SHA-256 清单，同时携带 libvterm 的本地修改说明。当前部署验证为 94 个二进制/字体、29 个 Qt DLL、三个 Qt 仓库（qtbase、qtdeclarative、qtsvg），清单逐项哈希核对通过。SBOM 包含 SDK 构建范围，不能将其中每个组件都视为实际部署文件，也不代表完整发布许可审查已完成。

- `u_terminal` 从 `develop` 的 `64c63663c6d25b338c714c9efc265eedf2fa2ecc` 建立。原来的同名 C# 原型分支保存在 `backup/u_terminal-csharp-77a686d`。
- C++20 / Qt 6.10.3 / CMake / MSVC 项目，可生成 Visual Studio 2026 的 `UTerminal.slnx`。
- C++ 脚本模型、参数解析、原子 JSON 保存、独立源码修订、删除备份、JSON 分享与集合导入导出。
- C++ 插件下载、SHA-256 校验、解压、私有运行时目录与版本租约的基础实现。
- C++ ProcessRunner 使用 Windows Job 归属进程树；ConPTY 使用独立读写线程与有界输出缓冲。
- C++ 会话模型与持久 TerminalItem，QML 宿主重建保留终端对象；标签、基础分屏、右键选区快照、添加脚本草稿、多行粘贴确认。
- 自定义、终端、设置及编辑/安装弹窗 QML 初版。Figma 参照来自本机 Figma APP；用户要求不再使用 Figma MCP。
- `scripts/build-uterminal.ps1`、`scripts/package-uterminal.ps1`、Inno Setup 安装脚本。Qt / QML / 内置资源在安装时解压为普通文件。
- PythonEnvironment C++ 服务与 QML 管理弹窗：包列表、源码 AST/import 诊断、常见模块到发行包映射、手动 pip 安装、依赖日志、等待环境空闲、迁移确认和失败保留原活动版本。Python helper 仅随可选插件解释器运行。

## 已验证

- Debug 和 Release 都编译成功。
- core：参数声明与必填项、重复选项、脚本分享/恢复/删除保护、设置持久化，全部通过。
- runtime：真实 CMD 输出与退出、启动失败、超时停止、ConPTY 启动、持续输出下关闭、逐字节 UTF-8 中文/Emoji、QML 宿主重建保留缓冲、TUI 右键拦截、多行粘贴确认，全部通过。
- 修复了 ConPTY 从 CTest 启动时继承重定向标准句柄的问题，显式使用 STARTF_USESTDHANDLES。
- 设置页浅色/深色实际渲染截图已检查；首个安装包在项目内隔离目录安装，并在移除 Qt SDK PATH/QML_IMPORT_PATH/QT_PLUGIN_PATH 后成功启动，无 QML 加载错误。
- 安装包已补齐 application-local MSVC DLL；同一测试目录覆盖安装后再次独立启动成功，确认 `vcruntime140.dll` 落盘。Release 已禁用源码目录回退，Visual Studio 资源复制目标已通过构建。
- 官方 Python 3.13.14、3.12.10 与 PowerShell 7.6.3 在项目内测试目录实际安装通过；pip 与基础解释器环境一致、缺模块与语法诊断、依赖等待租约、跨次版本重装、迁移失败保留旧环境均有端到端测试。PowerShell 真正提示符与输入执行已验证。
- 修复最后标签关闭时 qBound 上下界反转断言。终端截图先进行首帧渲染，避免隐藏测试窗口尚未布局导致错误判断；单窗格完整尺寸与真实提示符检查已加入测试入口。
- 双窗格实际截图已验证两侧提示符与均分布局。参数默认值更新已支持 Var/pVal 声明别名和文件参数，避免误改同名独立参数及正文引用；新增回归通过，Debug core/runtime 均通过。
- C++ ScriptHighlighter 接入 QML TextArea，提供 Python/PowerShell/CMD 基础词法高亮及明暗主题配色；Python 三引号、PowerShell 块注释/here-string 跨行状态有回归覆盖。Debug core 10 项、runtime 13 项通过（计入初始化/清理），实际 Python 编辑器截图显示高亮且应用日志为空。截图：`build/uterminal-editor-highlight-sample.png`。
- C++ ScriptEditing 实现 Tab 制表位、选区整行缩进、Shift+Tab 反缩进，每次操作合并为一个撤销步骤；覆盖反向选区、选区结束于下一行行首、中文和空文本。最新 Debug core 10 项、runtime 14 项通过（计入初始化/清理）。实际编辑弹窗的 `--smoke-editor` 已发送 Tab/Shift+Tab/Ctrl+Z/Ctrl+Y 并断言文本和草稿同步，退出码 0，日志为空。
- 编辑器提供环境变量增改删（值支持多行）与输出目录配置。C++ 校验 Windows 环境名称重复、非法值和应用管理的 Python/输出变量；修复旧导入 `environment`/`env` 字段不一致并兼容已保存记录。执行器创建输出目录，注入 `UTERMINAL_OUTPUT_DIR` 和旧 `POPTOOLS_OUTPUT_DIR`，相对路径基于工作目录。真实 CMD 在中文带空格的数据/输出目录执行、写文件、清理临时源码和变量隔离已通过；最新 Debug core 11 项、runtime 15 项通过（计入初始化/清理）。编辑窗口截图 `build/uterminal-editor-env.png` 正常。
- 交互脚本新增超时、窗格结束通知及输出保留；直接 endPane 和关闭标签均结束任务状态。执行服务销毁会停止拥有的进程、结束交互窗格并清理源码，源码写入失败通过作用域清理。真实 CMD 交互脚本的正常退出（退出码 7）、超时、endPane、关闭标签和服务销毁五条路径均通过，均核对进程停止、临时源码清除和脚本解除运行保护。最新 Debug core 11 项、runtime 20 项通过（计入初始化/清理）。

本机验证输出在 `build/uterminal-vs/*-results.txt`、`build/uterminal-*.png` 与 `build/uterminal-install.log`。这些是本机产物，未作为发行附件提交。

## 必须继续完成

旧 Python 文件命令参数补充：集合导入识别带参数的 .py 路径，按旧分词规则处理引号、空白、无反斜杠转义及未引用 # 注释；路径后的参数前置到 executor.args，之后统一走参数迁移。文件命令引号未闭合时报告错误。目录夹具覆盖带中文空格的路径、单/双引号、空参数、反斜杠和追加参数顺序，三组回归通过（7.34 秒）。独立参数元数据与依赖文件仍需完整迁移审视，安装包未更新本次改动。

旧集合文件源码修复：修复 collection["scripts"] 在空对象中插入 null，导致旧 tools 目录扫描被跳过的问题，改用 value 读取。旧 Python/BAT 纯文件路径（含引号、中文和空格）现读取所选集合内的源码；缺失、越界、读取失败及无效 JSON 写入报告并跳过，内联代码继续导入。新增真实目录夹具验证扫描、源码内容、缺失文件不入库和报告，三组回归通过（7.19 秒）。Python command 同时包含文件路径和额外参数、外部目录源码授权导入等仍待完善；不能把纯路径覆盖当作所有历史命令格式均已兼容。

旧条件 args 迁移补充：依据旧 execution_manager._render_args，迁移 Python 脚本中的 ?参数名:内容保留为字符串并设置 legacyConditionalArguments 标记；启动前先按输入值筛选，再校验/渲染剩余项，避免被省略项中的占位符阻止执行。不存在/空值省略，非空字符串（包括 "0"）保留；未带迁移标记的新脚本保留字面 ?x:y。编辑器显示语法说明，导入与重启标记保持有 core 覆盖；真实 Python argv 验证条件完整参数（含空格）及省略缺失值参数通过（357ms），常规三组回归通过。旧界面的独立参数元数据迁移及所有历史类型仍需审视，当前不应再笼统声称所有条件 args 都被拒绝。安装包尚未包含本次修改。

分屏关闭界面验证：新增 --smoke-close-pane，真实应用建立两个 PowerShell 窗格，通过窗口鼠标按下/释放点击第二窗格状态栏关闭按钮，断言剩一个窗格、原第一窗格仍运行且获得焦点。运行退出码 0，后续终端提示符和尺寸检查通过，build/pane-close-ui.png 已检查为单窗格填满区域并保留版本状态。右键菜单入口和其他多窗格关闭组合仍可继续扩大验收。

分屏关闭补充：状态栏（多窗格时）和右键菜单新增关闭窗格入口；关闭非聚焦窗格不再抢走焦点，最后窗格关闭会发出空焦点通知。常规三组测试通过（7.01 秒），真实 PowerShell 双窗格测试验证关闭第二窗格后第一窗格仍运行、恢复焦点并执行输出成功（3 项含初始化/清理，506ms）。无界面测试环境有 Qt 字体目录警告，未影响断言；鼠标点击入口和完整关闭交互仍需 UI 验收。安装包尚未包含此改动。

CI 入口补充：新增 .github/workflows/uterminal-ci.yml，Windows 2022 runner、Qt 6.10.3 MSVC x64，Debug/Release 分别调用已在本机验证的构建脚本并运行 archive-validation/core/runtime，always 上传测试日志，权限仅 contents:read，不发布资产。支持 u_terminal push、相关文件 PR 与手动触发；README 已说明。工作流仍只在本地，未推送，不能宣称远端 CI 已通过；旧 release.yml 仍待迁移。

归档异常夹具验证：新增 scripts/test-uterminal-archive.ps1，通过实际安装解压脚本验证父目录越界（正/反斜杠）、绝对路径、盘符路径、NTFS 文件流、Unix 符号链接均拒绝；异常条目之前的普通文件也不写入，合法包正常解压。测试使用 Windows PowerShell/.NET，在独立 GUID 目录保留夹具，不访问网络。已接入 CTest archive-validation，常规构建测试通过。重解析点与竞态、资源耗尽及崩溃恢复仍需进一步覆盖。

安装取消恢复实测：新增 cancelPythonPreparationAndRetry，在隔离目录真实下载 Python 3.12.10，进入准备阶段后 100ms 发出取消；验证状态为取消、未发 installed 信号、无 installed.json、无活动版本、下载 ZIP 已清理。随后同一目录重新下载安装成功，仅发一次 installed，验证该路径的锁释放和残留目录重试恢复。3 项含初始化/清理通过（21.624 秒）。仍需覆盖解压期间取消、应用被强制结束、恶意归档与不同故障阶段，不能据此宣称全部恢复场景完成。

插件安装进程归属补充：runStep 已由裸 QProcess 改为复用 ProcessRunner，安装/解压/venv/pip 子进程在创建时纳入 Windows Job；取消调用 stop，退出时回收后代，析构先断开回调再销毁执行器。保留环境污染清理和 64 KiB 输出上限，补入阶段启动与 complete 前的取消标志检查。真实隔离 Python 下载、解压、venv/pip 验证通过（3 项含初始化/清理，22.889 秒）；最终 Debug core/runtime 通过（6.91 秒）。实际安装中途取消、残留目录恢复及子进程故障注入仍需专项验收，不能由正常安装成功推断这些路径全部完成。安装包尚未包含本轮改动。

根文档迁移：README.md 已改为 UTerminal 开发版入口，记录实际 VS/CMake 构建、测试、运行、安装包命令、代码结构、可选运行时和数据目录；明确签名、迁移、旧源码清理与安装验收仍未完成。原 PopTools 1.0.9 README 保存在 docs/legacy/PopTools-1.0.9.md；新版不再承诺旧版 Android/投屏/飞书/macOS/托盘功能。根文档本地链接均已检查；本轮仅改文档，未重复运行代码测试。

窗格状态补充：Pane 保存启动时的 PowerShell/Python 版本标签，释放版本租约后仍保留显示；底部 24 像素状态栏展示绑定版本和运行/退出状态，退出包含代码，不覆盖终端内容。真实 CMD exit 7 回归及版本标签保持通过，Debug core/runtime 通过（6.66 秒）。真实 PowerShell 窗口启动和尺寸 smoke 成功，build/pane-status.png 已检查。最新安装包尚未包含本次状态栏改动。

实际安装刷新验收：用最新安装器更新已有工作区 build/uterminal-installed-smoke，显式 /NOCLOSEAPPLICATIONS /NOICONS /NORESTART，退出码 0；用户 LocalAppData/Programs 下另一 UTerminal 进程仍在运行，未关闭。安装目录 1,397 个发布文件逐项 SHA-256 与暂存目录一致，证明相关依赖已由安装器展开；随后以仅 Windows 系统 PATH 和全新数据目录启动安装版成功，日志为空，build/installed-current.png 设置页正常。安装日志 build/installer-current-test.log 明确报告 Explorer 注册退出码 1（缺受信任签名）。本次为同版本测试安装覆盖，不能替代跨版本升级、卸载数据保留和干净 Windows 验收。

发布快照刷新：当前代码已重新完成 Release core/runtime 回归并生成 build/installer/UTerminal-0.1.0-win-x64-setup.exe（28,210,687 字节，2026-09-13 22:27）。包含近期环境锁、参数、终端查找/拖放/配色及 QML 改动；打包脚本排除 plugin-bootstrap/__pycache__ 测试缓存。部署版在仅保留 Windows 系统目录的 PATH 和全新应用数据目录中独立启动成功，检查 Qt/CRT/平台插件/原生扩展/更新助手与 bootstrap 文件齐全，ScriptsPage.qml 哈希匹配源码，设置页截图 build/release-package-current.png 正常且日志为空。此证据验证部署目录启动，不代替真实 Inno 安装、升级、卸载或干净 Windows 虚拟机验收；安装包仍未签名，一级菜单正式注册条件未解决。

重复参数定义补充：解析器区分普通引用与显式定义；先出现 ${id}、后出现默认值/类型/选项时，显式定义补全该参数，避免代码引用抢先覆盖 arguments 中的下拉约束。相同定义合并，冲突默认值、类型与重复 Var/pVal 声明明确报错；参数位置保持首次出现顺序。新增回归覆盖晚定义、无效选项、类型冲突、别名冲突和相同定义去重；Debug core/runtime 通过（6.61 秒）。

下拉参数校验补充：Parameters::render 现在拒绝不在声明选项中的值，覆盖 Var/pVal 别名解析；Scripts::setParameterValue 拒绝非法值并保留之前输入，避免显示默认值却保存其他值。Executions 启动前检查 code 与 Python arguments 的合并参数来源，使参数错误在并发替换确认之前报告。core 覆盖有效值、非法值、默认值、别名和输入状态保持；Debug core/runtime 通过（7.02 秒）。跨字段参数重复声明与别名作用域仍需继续审视。

文件参数拖入补充：文件输入框接入 QML DropArea 与拖入高亮，通过 Scripts::dropParameterFile 将单个本地文件 URL 转成本机路径并更新本次会话参数，不改脚本默认值或源码。拒绝多 URL、网络 URL、非文件参数及控制字符；不检查目标是否存在，以支持稍后生成的文件与共享路径。core 覆盖中文空格、百分号、井号及拒绝时保持原值，收藏重载保留参数。真实窗口 --smoke-file-drop 验证从窗口事件、QML URL 列表到 C++ 的完整传递，build/parameter-drop.png 正常、日志为空；Debug core/runtime 通过（6.55 秒）。资源管理器鼠标实拖仍待完整桌面验收。

自定义页控件对齐补充：筛选入口改用统一 ActionButton，采用 28 高度、描边与选中强调色，消除系统默认灰色方块；运行状态移入输出工具栏，复制/清空改为适配深色输出区的紧凑透明按钮，保留原调用。Debug 构建成功，真实窗口 build/figma-controls.png 已检查，控件无裁切且 QML 日志为空。本轮为界面样式调整，未重复执行后端测试；完整设计和交互验收仍未完成。

Figma 本机复核补充：通过 computer-use 启动已安装 Figma APP，实际打开 PopTools 文件并观察 Screen / 自定义（1362 × 1024）、Screen / 终端和 Screen / 设置，未使用 Figma MCP。自定义画板放大后确认紧凑单行脚本列表、语言标签、箭头及底部计数；本轮将脚本行从 58 改为 40，描述改为悬浮提示，保留收藏与运行图标、拖动手柄，补入语言标签和计数。浅色背景按画板填充改为 #f7f8fa。更新构建资源后真实 QML 拖动排序验证成功，build/figma-list-updated.png 已检查且日志无错误。详情、过滤按钮样式、运行输出及其他画板仍需继续逐项对齐，不代表全部 Figma 验收完成。

终端配色补充：设置页新增深灰、浅色、纯黑三种前景/背景组合与字体即时预览，配置写入 settings.json。Sessions 将变化应用到现有及新建 TerminalItem；更新 libvterm 默认颜色与绘制默认颜色，不重置缓冲，光标跟随前景色以适应浅色背景，程序显式 ANSI 色保留。回归覆盖配置重启恢复、非法配色拒绝、缓冲文本保持、背景像素和显式 RGB 背景像素；Debug core/runtime 均通过（6.34 秒）。实际设置窗口截图 build/terminal-colors-settings.png 已检查，浅色预览正常、无 QML 日志错误。完整运行会话下切换及更多 ANSI/TUI 配色组合仍需最终验收。

终端路径拖入补充：C++ TerminalItem 接收本地文件 URL 的复制拖放，多路径以空格连接；PowerShell 使用单引号并转义路径内单引号，CMD/BAT 使用双引号，交互 Python 等输入会话插入原始路径。不附加回车，使用已有 bracketed-paste 通道；拒绝非本地 URL、控制字符及仅允许移动的拖放，避免源文件被移动。运行时测试覆盖中文空格、多路径、单引号、三种输入语言以及拒绝分支，并用真实 QQuickWindow 的合成拖放事件验证界面路由。最新 Debug core/runtime 均通过（6.19 秒）。资源管理器鼠标实拖及活动 TUI 中的效果仍待完整桌面验收。

更新下载与安装补充：Updates 已实现分块下载、精确大小/SHA-256 校验、QSaveFile 原子保存、取消与 pending 缓存恢复；重启重新校验缓存，退出后安装选项默认关闭。新增原生 `UTerminalUpdateRunner.exe`，等待父进程退出后重新校验安装包，再以不主动关闭其他应用的 Inno 参数启动；构建与打包脚本已包含 helper。App 退出确认纳入进行中的更新下载。可控网络测试覆盖取消、成功、恢复、损坏拒绝；真实 helper 进程测试验证父进程未退出时不执行、退出后调用测试安装器、错误哈希拒绝。最新 Debug core 16 项、runtime 21 项通过（计入初始化/清理）。测试安装器只写标记文件，未覆盖实际 Inno 升级。

应用更新基础：新增 Updates C++ 服务，使用 git remote 与旧更新器一致的 `popkter/PopToolProject` GitHub releases API，只接受匹配版本的 UTerminal x64 安装包、HTTPS 仓库下载路径、有效 SHA-256 digest 和合理大小，排除旧 PopTools 包。支持稳定/预发布排序、手动/启动/每日/每周策略；插件独立每日/每周检查已接入。设置页显示当前版本、策略、检查结果与说明。Debug core 15 项、runtime 20 项通过（计入初始化/清理），真实 GitHub API 检查成功（770 ms），设置页截图 `build/uterminal-update-settings.png` 正常。

编辑器插件提示补充：App C++ 按语言记录本次应用会话已提示状态；有代码时主动编辑或切换语言才检查缺失插件，先更新并保存草稿，再打开安装入口，每种语言只自动提示一次。显式安装按钮继续可用，不自动下载或执行。真实无 Python 插件的编辑弹窗已断言首次 Tab 编辑出现提示、关闭后连续反缩进/撤销/重做不再弹窗且草稿同步，退出码 0、日志为空；Debug core/runtime 通过。

干净安装复验：在 `build/uterminal-plugin-fresh-verification` 从零下载安装 Python 3.13.14 与 PowerShell 7.6.3，新版解压路径、精确 PowerShell 版本/profile 校验、Python 基础解释器与私有环境一致性、真实 PowerShell 提示符与命令执行均通过（6 项，含初始化/清理，58.266 秒）。安装清单新增实际 archiveSize；经固定 SHA-256 验证后，内置目录已补齐 Python 3.13.14 的 14,345,376 字节和 PowerShell 7.6.3 的 116,931,488 字节，三个内置包现在都有精确大小。

插件下载校验补充：下载采用 64 KiB 分块写入、256 KiB 网络读取缓冲，提供 512 MiB 总上限；存在目录 size 时核对精确字节数，先验证大小再 SHA-256，保留磁盘写入/flush 错误并清理失败包。GitHub 版本刷新保留资产 size。真实 HTTPS 测试已验证将 Python 3.12.10 声明大小改为 1 字节时拒绝、清理下载且活动版本不变，以及正确声明大小时完整下载安装成功（17.565 秒）。Debug core/runtime 同时通过。其余两个内置包暂未补精确 size，仍使用总上限和 SHA-256。

终端退出时序补充：回归暴露 ConPTY 进程退出先于最后输出读取的竞态；现在线程异步关闭伪控制台，GUI 继续排空读取队列，EOF 且队列为空后才发送 finished。修复后完整 runtime 测试连续运行 10 次均通过（44.80 秒），覆盖交互脚本退出码与最终输出、超时和各关闭路径。

默认值编辑补充：详情页增加“设为默认”，下拉选项将所选项移到声明首位，保留全部标签/值；Var/pVal 别名引用保持不变。保存默认值直接更新已选脚本，不再覆盖编辑器中未保存的其他草稿。重启恢复选项默认值、非法选项拒绝和草稿保持已有 core 回归。最新 core 13 项通过（计入初始化/清理）。

参数输入状态补充：Scripts C++ 模型按脚本保存本次应用会话的输入，QML 绑定文本/选项/文件值并提供恢复默认值。切换脚本、收藏导致重载、修改默认值、显式空输入和参数快照独立性均有 core 回归；输入不写入磁盘，重启恢复脚本默认值。最新 Debug core 12 项、runtime 20 项通过（计入初始化/清理），应用启动无 QML 错误。有参数详情页的实际交互和页面销毁重建仍应加入完整 UI 验收。

1. 继续完善 Python 并发边界：应用内安装任务使用版本预留/租约排队；受管 Python 启动引导现在通过 Windows 文件锁协调跨进程读取与 pip 写入，直接 pip.exe 和 python -m pip 均已验证。C++ 插件安装/修复和移除使用同一版本目录外的独占锁。并行读取、读写冲突拒绝、进程退出释放、外部锁阻止安装与删除均通过真实进程测试；脚本参数与既有依赖安装回归通过（集成 6 项含初始化/清理，2.197 秒），Debug core/runtime 通过。该机制是受管启动协议，-I/-S 或主动绕开 bootstrap 不受保护；pip 源码包构建子进程及初始 .pth 执行顺序仍需验证，不能宣称所有 Python 启动方式已覆盖。迁移、诊断与安装的主要流程已具备并有端到端验证。
2. 插件取消/修复/回退与中断恢复的完整验证；签名元数据与兼容版本目录刷新仍待完善。新版正常安装路径及精确 PowerShell 版本/profile 已从零安装验证；重解析点防护仍需恶意包故障注入。三个内置包精确大小已补齐，下载大小校验通过真实网络测试，Python 已有两个经过实际安装的兼容版本。
3. 更新服务的检查、版本筛选、策略、下载/校验/取消/恢复和退出后安装 helper 已实现；继续完成更新通知（含插件）、从应用设置页触发退出安装的完整交互验收，以及下载安装包缓存回收。标记助手目录的启动回收已实现，详见上方最新记录。helper 已将等待、校验失败、启动失败及安装程序已启动写入原子结果记录；设置页在下次启动时显示结果并提供日志目录入口，只有当前版本达到目标版本才显示完成。实际 helper 校验失败及无效可执行文件启动失败均已验证；无效程序的系统错误框被禁用，避免后台助手阻塞。安装器通过 /LOG 保留日志，助手已收集最终退出码；实际测试副本的 0.1.0 → 0.1.1 安装和数据保留已验证，但设置页到退出安装的完整用户操作链仍待验收。当前 API 仅读取最多 100 个 release，需审视分页；通道变化后的状态文案、自动检查失败重试策略仍需完善。响应上限最终读取检查已补入。不能虚构发行服务或下载地址。
4. 终端路径拖入、配色、窗格关闭与版本标识、滚动选择稳定性、IME/TUI/大输出/DPI 的完整验证。Ctrl+F 查找、历史定位、上下循环、结果高亮与查找栏已实现，支持中文和 Emoji，查询保存在持久终端对象中；结果最多保留 10000 项并显示加号，动态刷新按 150ms 合并。已补充历史行 continuation 元数据，复制与查找能跨显示自动折行并保留真实换行；显式行末空格保留，宽字符换行的空白占位不混入复制文本。测试覆盖屏幕、历史、宽字符边界、窗口增高回填和宽度变化；同时修复 libvterm 重排可见首行延续历史时的负行号越界。实际终端查找栏截图已通过，仍需扩大真实 Shell/TUI 的重排、跨行高亮和大缓冲性能验证。持久绘制对象已与 QML 页面生命周期解耦，缓冲与绘制仍需进一步拆分。底层接口补丁记录在 native/third_party/libvterm/UTERMINAL-PATCHES.md。
5. 旧版条件 args 和外部源码路径导入仍待完成。自定义排序已接入拖动手柄、目标指示与边缘自动滚动；完整顺序原子写入 state.json，筛选后移动保留隐藏项位置，不重写脚本源码。后端持久化及真实 QML 窗口第三项拖到第一项均验证通过，长列表边缘滚动仍需扩大交互验收。排序下拉框同步已保存状态；删除确认弹窗布局循环已消除。普通 Python args 已支持导入、逐项编辑、占位符、默认值及真实 argv 传递；中文空格、空参数、引号和反斜杠已通过实际 Python 执行验证。迁移后移除旧 executor/presentation，避免再次导入覆盖新编辑内容。旧版 PowerShell/BAT 本身忽略独立 args，当前对这些带 args 的导入明确拒绝并说明，仍需完善迁移报告。编辑器已支持 20 个内置图标选择，脚本列表使用保存的图标；真实弹窗选择“文件夹”并验证草稿文件同步通过。首次缺插件提示已接通并验证不重复打断输入。每脚本参数输入保持和选项默认值编辑已接入 C++ 与 QML，仍需完整 UI 验收。环境变量与输出目录配置已接通；基础语法高亮、批量缩进/反缩进及撤销重做已通过真实编辑弹窗验证。
6. 执行服务进一步核对：环境污染与版本租约、输出总量限制、普通进程退出期间清理和写入失败清理的故障注入验证。交互结束/超时/任务状态及销毁清理已通过真实 CMD 五路径测试；CMD 中文带空格路径已通过普通运行测试，仍需扩展引号和特殊字符边界。
7. 按 Figma APP 再检查有脚本详情、编辑弹窗、插件安装弹窗和实际终端页面；现有截图主要覆盖设置与空脚本页。
8. 后续源码改动完成后重打最终安装包。当前安装包是开发快照；以最新打包日志及上方带日期记录为准，不能依据早期快照描述认定完整验收通过。
9. 旧 Python/PySide 主程序、排除的预设业务、旧构建与旧测试已删除；后续迁移参考使用上述原始 Git 提交。继续对当前 C++ 应用进行完整迁移与功能验收。
10. 更新根 README、CI、第三方声明与发布说明，完成安装/升级/卸载数据保留检查以及完整需求验收。未完成前不标记目标完成。

## 本机命令

### Windows 11 一级右键菜单（2026-09-13 新增）

已加入无 Qt 依赖的原生 IExplorerCommand DLL、稀疏身份清单、打包签名参数、安装注册及卸载脚本；命令行进入终端页并解析目录。首次缺少 PowerShell 会保留目录至用户安装后主动打开。Release 核心/运行时测试通过，真实 PowerShell 集成测试验证了中文空格目录、文件父目录、无效路径和空路径。开发者模式的松散清单注册、移除均成功。

一级菜单仍需要受信任签名，脚本支持证书指纹与 Publisher，不自动修改证书信任或开发者模式。按 2026-09-14 用户补充要求，无签名时自动降级到“显示更多选项”；实际未签名安装及四类传统入口注册已验证，不再因一级菜单失败阻塞安装。实际 Explorer 菜单显示与点击仍待验证。详见 resources/shell/README.md。

```powershell
./scripts/build-uterminal.ps1 -Configuration Debug -Test
./scripts/package-uterminal.ps1
```

Qt 默认查找 `build/qt-sdk/6.10.3/msvc2022_64`，也可设置 `QT_ROOT`。安装包输出为 `build/installer/UTerminal-0.1.0-win-x64-setup.exe`，当前仅为开发验证版本。

终端关闭补充：完整回归中发现条件变量退出标志在锁外修改，可能漏掉关闭通知；已改为持锁更新 stopping 后通知。持续验证关闭与销毁路径，不能仅以更新助手测试通过推断终端退出可靠性。
