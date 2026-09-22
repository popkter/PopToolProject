# PopTools 界面规范

## 设计来源与范围

以本机 Figma 中 `PopTools / Page 1` 为视觉参考。2026-09-22 通过 Figma 桌面窗口核对了 `Screen / 自定义`、`Screen / 终端`、`Screen / 设置` 及旁侧弹窗。设置画板为 1362 × 1024；自定义页 Content 的 X 为 72、宽为 1290，自动布局间距为 16，左右与底部内边距为 28，顶部为 40，浅色填充为 `#FBFCFE`。这些为实测值，其余组件尺寸和小窗口断点是实现约定，不声称为 Figma 原始变量。

界面保留现有功能入口、脚本参数、设备选择和执行行为。设置已按设计改为左侧外观、脚本目录、检查更新，右侧插件与关于。插件列表读取真实状态：PowerShell 支持安装及取消，Python、ADB、scrcpy 支持查看已有环境目录；尚未提供独立卸载与终端分屏能力，不放置无效按钮。设计中的示例版本、下载进度和脚本执行结果不能写死。

精确设计来源：[设置](https://www.figma.com/design/oz0LJrEjrrQVWIxCO4lOGL/PopTools?node-id=20-2839)、[自定义](https://www.figma.com/design/oz0LJrEjrrQVWIxCO4lOGL/PopTools?node-id=97-75)、[终端](https://www.figma.com/design/oz0LJrEjrrQVWIxCO4lOGL/PopTools?node-id=97-368)。设置、自定义、PowerShell 安装及退出弹窗通过设计上下文读取；终端背景通过本机图层 Fill 确认为 `#2B313D`。应用品牌标识保留猫猫头；应用内功能图标按用户要求统一使用本地 Material Icons Round 字体，QML 通过 `MaterialIcon` 组件展示，用户手册也复用同一字体。

## 唯一变量入口

`src/poptools/ui/qml/theme/Theme.qml` 是 QML 视觉变量的统一入口。组件通过 `Theme` 引用颜色、字号、间距、圆角与布局尺寸。不要复制颜色值或为同一角色创建新的局部常量。

分为三层：

1. 基础尺度：`space4…space40`、`fontBody`、`fontCaption` 等。
2. 语义角色：`workspaceBackground`、`textPrimary`、`inputBorder`、`navigationActiveIcon` 等。深浅色分支在主题内维护。
3. 组件规则：`navigationRailWidth`、`pageHeaderHeight`、`scriptListMinimumWidth`、`settingsTwoColumnWidth` 等。页面引用规则，不重复断点和固定尺寸。

0、1、比例计算、索引、事件时间、协议常量不必机械转换为视觉变量。只有重复或具有设计含义的值需要命名。终端 ANSI 色、图标路径与第三方内容属于各自的数据，不以普通页面配色强行覆盖。

## 页面与响应式布局

| 项目 | 规则 |
| --- | --- |
| 应用窗口 | 最小 960 × 720 逻辑像素，随显示缩放自动换算 |
| 顶栏 | 高 40，承担窗口拖动与窗口控制 |
| 导航栏 | 宽 72，图标按钮 44 × 44，纵向间距 20；顺序为终端、自定义、预设、设置 |
| 普通页面 | 左、右、下留白 28；顶栏承担设计中的顶部 40 |
| 页面标题 | 自定义标题区高 66，设置高 80；标题 36，辅助文字 15 |
| 面板间距 | 设置 16，自定义 18 |
| 自定义脚本 | 列表宽度占可用区 0.356，限制在 290–438；详情占剩余宽度 |
| 列表行 | 高 40，名称省略、类型标签保留，支持滚动 |
| 详情操作 | 宽屏编辑与删除各 94，运行 108 并靠右；高 36；窄屏分为管理行与整行运行按钮 |
| 输出控制台 | 默认展开，最高 348；小窗口优先保留 152 的输出区，参数区滚动；用户可以收起；状态显示真实执行结果 |
| 设置 | 每列至少 440，加 16 间距；内容宽不足 896 时改为单列并垂直滚动 |
| 终端 | 占满工作区，标签宽 120–180、高 32，工具栏高 38，溢出横向滚动；背景为独立角色 `terminalBackground`，与原生终端默认背景同步 |
| 确认弹窗 | 基准宽 548，左右留白 16、上下 24，标题 24，说明 18，按钮高 48；长文案自动增加高度 |

不通过固定文字坐标、缩小字体或隐藏必要操作解决溢出。优先采用文本省略、换行、滚动或响应式换列。

## 颜色与文字

浅色页面背景 `workspaceBackground`，卡片 `surfaceContainerLow`，正文 `textPrimary`，说明 `textSecondary`。主操作使用 `primary`，危险动作使用 `errorColor`，成功状态使用 `success`。选中与悬停分别引用独立角色；禁用状态同时反映在交互与颜色上。

标题使用 `workspaceTitleSize` / `fontDetailTitle` / `fontSectionTitle`；正文用 `fontBody`，标签用 `fontSupporting`，说明与列表元信息用 `fontCaption`。终端与代码保持等宽字体。角色相同的文字不因位于不同页面而使用不同字号。

## 公共组件

- `WorkspacePageHeader`：统一标题、说明与右侧操作；说明通过内容布局定位，不手写 y 坐标。
- `PrimaryButton`：默认高 40，紧凑操作高 36，大选项高 48；默认宽度由文字、图标和内边距计算。主操作、次操作、危险操作使用同一基础组件。
- `NavItem`：统一导航选中、悬停、边框与图标颜色。
- `AppDialog` / `AppPopupSurface`：统一遮罩、表面、圆角和内边距。
- `AppMenu` / `AppMenuItem`：统一菜单行与危险动作颜色。
- `AppComboBox` / `ToggleControl`：复用已有交互控件，避免页面复制底层实现。
- `AppTextField` / `AppCheckBox` / `AppSwitch` / `AppSlider` / `AppProgressBar`：统一输入、选择和进度的配色、焦点与禁用状态；业务页面不直接使用未定制的 Qt 默认控件。插件卸载确认复用 `AppDialog` 和 `PrimaryButton`，保留依赖删除及用户文件保留说明。

动画应引用 `motionFast` / `motionStandard` / `motionSpinner`。仅几何绘制或业务计时可以保留其独立时长。

## 验收方法

每次修改需核对自定义、终端和设置页，覆盖设计画板尺寸及 960 × 720、小窗口和浅深两种模式。检查长名称、空列表、参数滚动、控制台展开/收起、菜单和确认弹窗。测试通过不替代实际渲染检查。

本轮截图放在忽略版本控制的 `build/figma-ui-*.png`；运行时使用隔离的预览数据目录，不修改用户脚本。新组件继续遵守本规范，新增变量先确认是否已有同角色变量。
