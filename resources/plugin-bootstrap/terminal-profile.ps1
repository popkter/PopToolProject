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
$global:UTerminalHistoryControlReady=$false
try {
    $optionCommand=Get-Command Set-PSReadLineOption -ErrorAction Stop
    $keyCommand=Get-Command Set-PSReadLineKeyHandler -ErrorAction Stop
    if($optionCommand.Parameters.ContainsKey('PredictionSource') -and $optionCommand.Parameters.ContainsKey('PredictionViewStyle')) {
        Set-PSReadLineKeyHandler -Chord 'Ctrl+x,Ctrl+y' -BriefDescription 'UTerminalHistoryOn' -ScriptBlock {
            try {
                Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView -ErrorAction Stop
                [Console]::Write("`e]6973;history:on`a")
            } catch {
                $reason=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($_.Exception.Message))
                [Console]::Write("`e]6973;history:error:$reason`a")
            }
        }
        Set-PSReadLineKeyHandler -Chord 'Ctrl+x,Ctrl+n' -BriefDescription 'UTerminalHistoryOff' -ScriptBlock {
            try {
                Set-PSReadLineOption -PredictionSource None -PredictionViewStyle InlineView -ErrorAction Stop
                [Console]::Write("`e]6973;history:off`a")
            } catch {
                $reason=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($_.Exception.Message))
                [Console]::Write("`e]6973;history:error:$reason`a")
            }
        }
        $global:UTerminalHistoryControlReady=$true
    }
} catch {}
if(-not (Test-Path variable:global:UTerminalOriginalPrompt)) {
    $global:UTerminalOriginalPrompt=$function:prompt
    function global:prompt {
        $state=if($global:UTerminalHistoryControlReady){'ready'}else{'unsupported'}
        [Console]::Write("`e]6973;prompt:$state`a")
        & $global:UTerminalOriginalPrompt
    }
}
