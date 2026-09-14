$OutputEncoding=[Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding=[Text.Encoding]::UTF8
function global:python {
    if(-not $env:UTERMINAL_PYTHON) { Write-Host '请在 UTerminal 设置中安装 Python 插件，然后新建终端。' -ForegroundColor Yellow; return }
    & $env:UTERMINAL_PYTHON @args
}
function global:pip {
    if(-not $env:UTERMINAL_PIP) { Write-Host '请在 UTerminal 设置中安装 Python 插件，然后新建终端。' -ForegroundColor Yellow; return }
    & $env:UTERMINAL_PIP -m pip @args
}
Import-Module PSReadLine -ErrorAction SilentlyContinue
