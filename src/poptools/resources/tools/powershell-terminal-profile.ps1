$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function global:python {
    & $env:POPTOOLS_PYTHON @args
}

function global:pip {
    & $env:POPTOOLS_PIP -m pip @args
}

if ($env:POPTOOLS_ADB -and (Test-Path -LiteralPath $env:POPTOOLS_ADB)) {
    function global:adb {
        & $env:POPTOOLS_ADB @args
    }
}

Import-Module PSReadLine
Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView
