# Windows 11 右键菜单

可选的一级菜单通过原生 `UTerminalShell.dll` 的 `IExplorerCommand` 和稀疏 MSIX 身份注册，支持文件夹、文件夹空白处及文件。文件使用所在目录；无效路径、非文件系统位置或空路径回退到用户主目录。启动参数为 `UTerminal.exe --open-terminal --directory "路径"`。

PowerShell 7 尚未安装时，应用进入终端页并提示安装；目标目录保留到用户主动点击“打开终端”，安装完成不会自动执行。

文件夹空白处的注册项不设置 `MultiSelectModel=Single`：该位置没有选中对象，此限制会让 Explorer 隐藏菜单。安装器会删除旧版本遗留的该属性；文件、文件夹和驱动器对象仍保留单选限制。

## 正式打包

当前安装器通过 Inno Setup 的 [Registry] 直接写入 HKCU\Software\Classes 下的传统菜单，支持目录、目录空白处、文件和驱动器。安装完成后通知资源管理器刷新；卸载自动移除 UTerminal.OpenHere 专属键。菜单显示在 Windows 11 的“显示更多选项”中，不依赖 PowerShell、MSIX 注册或签名。安装日志默认保存在用户临时目录的 Setup Log 文件中。一级菜单作为手动可选集成，需要目标机器信任的签名。

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

部署目录必须包含 UTerminal.exe、UTerminalShell.dll、Qt 运行库和 resources。安装器不尝试 MSIX 注册。需要一级菜单时才手动调用 register.ps1（签名包使用 -InstallDirectory；开发清单额外使用 -Development）。现代注册成功后清理传统入口；卸载通过 register.ps1 -Unregister 移除当前用户身份包和各目标下的 UTerminal.OpenHere 专属注册项。

实现参考：https://learn.microsoft.com/windows/apps/desktop/modernize/integrate-packaged-app-with-file-explorer
签名参考：https://learn.microsoft.com/windows/apps/desktop/modernize/grant-identity-to-nonpackaged-apps
