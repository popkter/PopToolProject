# 泡泡工具箱 Design QA

## Evidence

- Source images:
  - `docs/assets/poptools-reference-local.png`
  - `docs/assets/poptools-reference-online.png`
  - `docs/assets/poptools-material3-reference.png`
- Implementation screenshots:
  - `docs/assets/poptools-implementation-local.png`
  - `docs/assets/poptools-implementation-online.png`
  - `docs/assets/poptools-dynamic-command.png`
  - `docs/assets/poptools-responsive-primary-compact.png`（1050 × 720）
  - `docs/assets/poptools-responsive-both-compact.png`（780 × 720）
  - `docs/assets/poptools-responsive-minimum.png`（600 × 360）
  - `docs/assets/poptools-command-editor-edit.png`（1200 × 800）
  - `docs/assets/poptools-command-editor-new.png`（1200 × 800）
  - `docs/assets/poptools-global-device-selector.png`（1200 × 800）
  - `docs/assets/poptools-global-device-menu.png`（1200 × 800）
  - `docs/assets/poptools-unified-local-commands.png`（1200 × 800）
- Same-state comparison: `docs/assets/poptools-design-qa-online.jpg`
- Capture viewport: 1488 × 1024 application content
- Capture density: 100%
- Capture platform: Qt offscreen software renderer on Windows

## Comparison checklist

| Area | Result | Notes |
| --- | --- | --- |
| Overall composition | Passed | The implementation preserves the approved desktop hierarchy and dense tool-workspace proportions. |
| Navigation hierarchy | Passed | Primary section rail, secondary tool list and focused workspace remain visually distinct. |
| Material 3 styling | Passed | Flat surfaces, rounded containers, lavender selection states and purple primary actions are consistent. |
| Typography | Passed | Chinese labels, titles, descriptions and monospace output render without clipping at the target viewport. |
| Iconography | Passed | Rounded Material icons render from the font packaged with the application. |
| Local tool workspace | Passed | Editable tool metadata, dynamic parameters, primary run action and console are present. |
| Online JSON workspace | Passed | Input/result panes, format action and bottom output area reproduce the reference task flow. |
| Safety state | Passed | Tools marked as high risk show a confirmation dialog before execution. |
| Dynamic command parameters | Passed | `${输入密码}` produces a labeled standard text field in the local command workspace. |
| Fixed command actions | Passed | Run, edit and delete actions are identical for every local command and remain fixed while parameters scroll independently. |
| Responsive width | Passed | Primary labels collapse first, tool-list labels collapse at the second breakpoint, and the remaining icons expose full-name tooltips. |
| Responsive height | Passed | At 600 × 360 the app mark and all four primary navigation actions remain visible and usable. |
| Command editor dialogs | Passed | Create and edit share one Material 3 surface, the same PowerShell/Bash/BAT choices, a fixed action footer, and one scrollable script editor. |
| Unified local commands | Passed | Initial and user-added commands have the same list appearance, editor, delete action and persistence behavior; no source or edited marker is shown. |
| Global Android device | Passed | The selector lists the connected device, persists one global choice, and per-command Android-device fields are removed. |
| Tray lifecycle | Passed | Closing the main window hides it when the Windows tray is available; the tray menu exposes show and explicit exit actions. |
| Overflow and collisions | Passed | No overlapping, clipped or off-canvas controls were found in the captured states. |

## Iteration history

1. Initial offscreen capture exposed missing application text because the headless Qt platform had no system font database.
2. The QA capture now explicitly registers the installed Windows Chinese UI font; production continues to use the normal Windows font database.
3. Replaced the oversized variable icon font with the official rounded Material Icons font and verified icon ligatures in both captured states.
4. Added a confirmation dialog for destructive or high-risk local tools and repeated QML lint, same-state capture and comparison checks.
5. Merged user commands into Local, verified generated password input, fixed header actions and the custom-command delete affordance.
6. Added two-stage width collapse, compact-height behavior, responsive dialogs and visual verification at 1050 × 720, 780 × 720 and 600 × 360.
7. Rebuilt command dialogs, verified script scrolling, unified prebuilt/custom edit behavior, and added the global Android device selector with live connected-device evidence.
8. Removed origin-specific UI, edited markers and restore-default behavior; verified that every local command now uses the same edit/delete lifecycle.
9. Unified create/edit runner choices to PowerShell, Bash and BAT; removed the argument-list tab and merged legacy command arguments into the script editor.
10. Added close-to-tray lifecycle actions and changed distribution from an onedir bundle to one self-contained EXE.

## Intentional adaptations

- The approved architecture uses the three-column navigation pattern consistently in every section. The online reference collapses its second level into top tabs, while this implementation keeps tools in the secondary column so user-added online tools can use the same registry and search behavior.
- Native Windows title-bar appearance is excluded from the offscreen capture and is supplied by Windows when the packaged application starts normally.
- The local implementation screenshot selects a currently integrated Android tool instead of reproducing the ASR sample content literally; component hierarchy and visual treatment remain the same.

## 客制功能“新建命令”入口迁移（2026-07-29）

- Source visual truth: `docs/assets/poptools-create-command-reference.png`（1500 × 1000，用户标注明确指向标题栏右侧）
- Implementation screenshot: `docs/assets/poptools-create-command-moved.png`（1875 × 1250 物理像素；1500 × 1000 逻辑窗口；125% Windows 显示密度）
- Normalized comparison: `docs/assets/poptools-create-command-comparison.png`（左右并排；实现截图归一化为 1500 × 1000）
- State: 客制功能 / Android 工具列表，未悬停
- Full-view evidence: 底部“新建命令”大按钮已消失，命令列表获得完整可用高度；标题栏右侧出现加号入口，三栏布局、搜索框和内容区均未漂移。
- Focused-region evidence: 标题区与原底部区域均属于本次变更核心，因此使用同一张并排对比图检查；加号采用项目内置 Material Icons Round 字体，颜色、尺寸和标题基线符合现有 Material 3 令牌。
- Typography: 现有标题、列表和提示文字的字体、字号、字重与换行均保持不变。
- Spacing/layout: 新按钮为 40 × 40，位于 48 高标题行右侧；紧凑工具栏中仍保持水平居中；未发现遮挡、裁切或越界。
- Colors/tokens: 默认透明、悬停使用 `Theme.primaryContainerHover`，图标使用 `Theme.primary`，与现有主题一致。
- Image/icon fidelity: 使用已打包的 Material 图标字体中的 `add`，没有新增位图或近似绘制资产。
- Copy/content: 可见按钮文字被移除；悬停提示保留“新建命令”，入口含义没有丢失。
- Interaction: 点击仍调用 `commandEditorDialog.openForCreate()`；入口仅在 `local`（客制功能）分区显示。
- Findings: 未发现 P0/P1/P2 问题。
- Comparison history: 首次实现即满足标注位置；无需视觉修复迭代。

## 命令编辑弹窗说明框等高（2026-07-29）

- Source visual truth: `docs/assets/poptools-command-editor-height-reference.png`（1920 × 1020，红框标注功能说明输入区）
- Implementation screenshot: `docs/assets/poptools-command-editor-equal-description-height.png`（1920 × 1020 物理像素；1536 × 816 逻辑窗口；125% Windows 显示密度）
- Normalized comparison: `docs/assets/poptools-command-editor-height-comparison.png`（同尺寸左右并排，无密度缩放）
- State: 客制功能 / 新建本地命令弹窗；编辑弹窗复用同一组件和尺寸属性。
- Full-view evidence: 功能说明输入框已从 70 高缩至 50 高，与命令名称输入框一致；脚本内容区域、提示条和底部操作区均未重叠或裁切。
- Focused-region evidence: 并排对比图清晰覆盖命令名称、运行方式和功能说明区域；实现中两处输入框外框高度相同，标签间距和圆角保持一致。
- Typography: 标签、占位文字、字重和基线保持原样，无截断。
- Spacing/layout: 两个输入框均使用 `Layout.preferredHeight: 50`；功能说明上下内边距保持 12，不影响单行占位文字垂直可读性。
- Colors/tokens: 背景、描边、焦点态和现有 Material 3 主题令牌均未改变。
- Image/icon fidelity: 本次没有新增或替换图像、图标资产。
- Copy/content: “功能说明”和“简要说明命令用途”文字保持不变。
- Interaction: 新建与编辑继续共用 `descriptionField`，保存数据路径未改变。
- Findings: 未发现 P0/P1/P2 问题。
- Comparison history: 首次实现通过同尺寸并排视觉检查，无需修复迭代。

final result: passed
