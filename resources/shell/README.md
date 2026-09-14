# Windows 11 一级右键菜单

菜单通过原生 `UTerminalShell.dll` 的 `IExplorerCommand` 和稀疏 MSIX 身份注册，支持文件夹、文件夹空白处及文件。文件使用所在目录；无效路径、非文件系统位置或空路径回退到用户主目录。启动参数为 `UTerminal.exe --open-terminal --directory "路径"`。

PowerShell 7 尚未安装时，应用进入终端页并提示安装；目标目录保留到用户主动点击“打开终端”，安装完成不会自动执行。

## 正式打包

一级菜单身份包需要目标机器信任的签名。无可信签名或现代菜单注册失败时，安装脚本自动注册当前用户的传统菜单，在 Windows 11 的“显示更多选项”中提供相同入口，不阻塞安装。支持目录、目录空白处、文件和驱动器；仅当两种注册方式都失败时安装器才报告菜单注册错误。

使用当前用户证书存储中的代码签名证书：

```powershell
./scripts/package-uterminal.ps1 -SigningCertificateThumbprint CERTIFICATE_THUMBPRINT -Publisher 'CN=YOUR_PUBLISHER'
```

Publisher 必须与证书主体一致。脚本使用 Windows SDK SignTool 签名并验证身份包，不创建证书、不导入信任证书、不修改开发者模式。正式发布流程还应签名 EXE 安装器。

## 本机开发验证

仅当本机已经开启开发者模式时，可显式注册松散清单：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File resources/shell/register.ps1 -InstallDirectory ABSOLUTE_DEPLOY_DIRECTORY -Development
```

部署目录必须包含 UTerminal.exe、UTerminalShell.dll、Qt 运行库和 resources。正式安装器先尝试 MSIX 注册，不自动使用开发注册。现代注册成功后清理传统入口；卸载通过 register.ps1 -Unregister 移除当前用户身份包和各目标下的 UTerminal.OpenHere 专属注册项。

实现参考：https://learn.microsoft.com/windows/apps/desktop/modernize/integrate-packaged-app-with-file-explorer
签名参考：https://learn.microsoft.com/windows/apps/desktop/modernize/grant-identity-to-nonpackaged-apps
