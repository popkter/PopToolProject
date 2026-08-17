# 泡泡工具箱用户引导

泡泡工具箱适合把常用的 Android、PowerShell、Bash、BAT 和 Python 操作整理成可重复执行的工具。本文介绍如何创建自定义脚本、用变量生成输入框、运行带依赖的 Python 脚本，以及使用应用内置终端管理 Python 环境。

## 一、创建自定义脚本

1. 进入“客制”。
2. 点击新建脚本/命令按钮。
3. 填写脚本名称和说明。
4. 在脚本类型中选择 `PowerShell`、`Bash`、`BAT 脚本` 或 `Python`。
5. 在“脚本内容”中输入命令或脚本，保存后即可在客制列表中运行。

脚本和命令保存在本机，不会上传到网络。预置功能不能直接编辑；如果需要修改预置功能，应复制为自己的客制脚本。

## 二、在脚本中添加变量并生成输入框

脚本中的占位符会自动转换为运行前的输入框。变量名只能使用中文、字母、数字和下划线。

### 快速写法

直接在命令中使用 `${变量名}`：

```powershell
adb shell settings put global auto_time ${自动设置时间}
adb shell settings put global auto_time_zone ${自动设置时区}
```

保存后，应用会自动生成“自动设置时间”和“自动设置时区”两个输入框。

使用 `${变量名=默认值}` 可以设置默认值：

```powershell
adb shell cmd alarm set-time ${时间戳=1786356497528}
```

输入框会预填默认值，运行前仍然可以修改。

### 推荐写法：使用 `pVal` 声明变量

当变量需要多次使用，或者希望把内部变量名和输入框显示名称分开，可以在脚本开头声明：

```powershell
pVal timestampMs = ${时间戳=1786356497528}

Write-Host "即将设置 Android 设备时间"
adb shell cmd alarm set-time ${timestampMs}
adb shell date
```

说明：

- `timestampMs` 是脚本内部使用的变量名。
- `时间戳` 是输入框显示名称。
- `1786356497528` 是默认值。
- `pVal` 声明行只用于生成参数，不会被发送给 PowerShell、Bash、BAT 或 Python 执行。
- `pVal timestampMs: ${时间戳=...}` 冒号写法也支持。

### Python 中使用变量

占位符替换发生在脚本执行前，因此 Python 字符串变量要加引号：

```python
import urllib.parse

keyword = "${搜索关键词=Android 工具}"
print(urllib.parse.quote(keyword))
```

如果需要数字，应在 Python 中自行转换：

```python
count = int("${数量=3}")
print(count * 2)
```

不要把不可信输入直接拼接进复杂 shell 语句；涉及文件路径、引号或特殊字符时，应在对应脚本语言中进行转义或使用参数数组。

## 三、创建或导入 Python 脚本

### 方式 A：直接在应用中创建 Python 脚本

1. 新建一个客制脚本。
2. 类型选择 `Python`。
3. 将 Python 源码粘贴到脚本内容区域。
4. 保存脚本。

例如：

```python
import datetime

print("当前时间：", datetime.datetime.now().isoformat(timespec="seconds"))
```

新建或编辑 Python 脚本时，应用会自动分析源码中的 `import` 和 `from ... import ...`，并使用应用专属 Python 环境检查依赖。

### 方式 B：运行已有的 `.py` 文件

新建一个 Python 类型的客制脚本，在脚本内容区域填写 `.py` 文件路径，例如：

```text
C:\Users\Public\Scripts\device_report.py
```

路径中包含空格时请使用引号：

```text
"C:\Tools\Android Scripts\device_report.py"
```

应用会使用应用专属 Python 环境启动该文件。脚本文件旁边的本地模块也会被 Python Doctor 识别为本地模块，不会误报为需要安装的第三方依赖。

### 方式 C：导入 PopTools 脚本配置

如果要在多台电脑之间迁移客制脚本：

1. 打开“设置”。
2. 找到“客制脚本”。
3. 在一台电脑上点击“导出脚本”，应用会在“文档”目录生成一个带时间戳的脚本目录。
4. 将这个目录复制到另一台电脑。
5. 在另一台电脑的“设置 → 客制脚本”中点击“导入脚本”，选择该目录。

导入目录应包含应用导出的 `tools` 和 `scripts` 子目录。导入操作会先备份当前默认目录，然后替换其中的本地脚本配置；不会覆盖主题、窗口尺寸和设备选择等应用设置。单独的 `.py` 文件不能通过这个按钮直接导入，应该使用上面的方式 A 或 B。

默认配置目录为：

```text
%LOCALAPPDATA%\PopTools
```

## 四、使用应用内 Python 环境和安装依赖

### Python 运行环境

应用自带 Python 运行时，并在用户数据目录中维护用户专属 venv。不需要安装或配置系统 Python，也不会修改系统 Python。Python Doctor、内置终端中的 `python`/`pip`、依赖安装和客制 Python 脚本始终使用同一套应用专属环境。

### 安装脚本依赖

例如脚本中有：

```python
import requests
from PIL import Image
```

新建、编辑或运行 Python 脚本时，应用会检查源码导入的模块。如果缺少常见第三方依赖，Python Doctor 会把导入名映射为对应的 pip 包名并显示安装提示。确认后，应用会自动安装到用户专属 venv，安装完成前窗口不会关闭，随后会自动重新检查脚本。

如果希望提前确认环境状态，可以点击“运行命令”左侧的依赖检查图标手动检查。标准库和脚本旁的本地模块不会作为第三方依赖安装。

### 开启并使用内置终端

终端功能默认关闭。进入“设置”，点击“终端功能”即可开启；如果尚未安装应用专用的 PowerShell 7 插件，应用会先询问是否下载安装。用户拒绝或取消安装时，终端功能保持关闭，主界面不会显示“终端”Tab。

确认后，应用下载微软官方 ZIP 包、校验 SHA-256 并安装到当前用户的应用数据目录。只有安装成功后，终端功能才会开启，主界面才会显示“终端”Tab。该插件不修改系统 PowerShell，也不会使用电脑上已有的 `pwsh.exe` 代替。

以后可以在“设置”中关闭终端功能。关闭后主界面的“终端”Tab 会立即隐藏，正在运行的终端会话也会停止；已经下载的 PowerShell 7 插件会保留，再次开启时无需重复安装。

安装成功后，内置终端会通过 Windows ConPTY 启动真正的交互式 PowerShell 7，并绑定到应用专属 Python 环境。它不是“输入整条命令再提交”的文本框：可直接使用 PSReadLine 历史预测、Tab 补全、方向键历史、`Ctrl+R` 搜索与原生光标编辑。输入曾执行过的命令前缀时，PowerShell 会显示可接受的历史建议。

可以直接输入：

```text
python --version
pip list
pip install requests Pillow
pip install -r requirements.txt
```

这里的命令外壳来自应用安装的 PowerShell 7 插件；`python` 指向应用内置 Python 运行时，`pip` 会把依赖安装到用户专属 venv。无需查找 Python 的绝对路径，也不要在系统终端中使用全局 `pip`。手动安装完成后，可以重新运行依赖检查，再执行 Python 工具。

### 内置终端的会话与资源管理

- 在设置中成功开启终端并首次进入“终端”后，会创建 PowerShell 7、ConPTY 和终端渲染页面；此后会话在应用运行期间持续保持。
- 切换到其他主界面分区不会结束 PowerShell，会话中的当前目录、变量和正在运行的命令都会保留。
- 点击“重启会话”会结束当前 PowerShell 进程树并创建干净的新会话。
- 用户真正退出应用时，应用会同时回收 `pwsh.exe`、Windows ConPTY 宿主 `OpenConsole.exe`、终端线程和页面渲染资源；仅关闭到系统托盘不会结束会话。
- 控制器只保留最近 131,072 个字符的回放数据；xterm 页面提供最多 10,000 行的当前会话滚动记录，避免输出历史无界增长。

终端适合在应用使用期间保留交互状态。如果要停止当前环境，可点击“重启会话”；退出应用后，不应依赖该终端继续承载后台任务。

注意：`import` 名称和 pip 包名称不一定相同：

| Python 导入名 | 常见安装包名 |
| --- | --- |
| `PIL` | `Pillow` |
| `cv2` | `opencv-python` |
| `yaml` | `PyYAML` |
| `bs4` | `beautifulsoup4` |
| `dateutil` | `python-dateutil` |
| `lunar_python` | `lunar-python` |

如果应用提示的模块名不是实际的 pip 包名，请按第三方库的文档使用正确的包名安装。

### 依赖安装建议

- 不要使用系统全局 `pip`；需要手动管理包时，优先使用内置终端中的 `pip`。
- 推荐在项目或脚本旁维护 `requirements.txt`，例如：

  ```text
  requests>=2.32
  Pillow>=11
  ```

  然后在内置终端中安装：

  ```text
  pip install -r requirements.txt
  ```

- 如果依赖安装失败，请检查网络、代理和 pip 源配置。

## 五、运行和排查

- 运行参数脚本时，先填写自动生成的输入框，再点击“运行命令”。
- 没有参数的最近使用工具可以直接执行；有参数的工具会先打开参数弹窗。
- 控制台会实时显示标准输出和错误输出。
- Python 脚本有语法错误时，应用会在保存后提示错误位置。
- Python 脚本在新建、编辑和运行时会检查依赖；依赖缺失时，优先使用弹窗中的“确认安装”。
- 需要查看版本、包列表或执行自定义 pip 命令时，可使用内置终端。
- Android 命令执行前，确认设备选择器中已经选择目标设备，并确保设备已连接且允许 USB 调试。
