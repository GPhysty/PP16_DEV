$ErrorActionPreference = 'Stop'
$dosbox = Join-Path $env:USERPROFILE '.vscode/extensions/xsro.vscode-dosbox-0.1.8-win32-x64/emu/dosbox_x/win32-x64/dosbox-x.exe'
if (-not (Test-Path -LiteralPath $dosbox)) { throw 'Configured DOSBox-X extension executable is missing.' }
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'out/PP16.EXE'))) { throw 'Run build-pp16.ps1 first.' }
# The requested interactive demo stays visible, then returns to the DOS prompt.
Start-Process -FilePath $dosbox -ArgumentList '-nopromptfolder -conf dosbox-x.conf -conf config/pp16.conf -noautoexec -c "mount c out" -c "c:" -c "ver set 3 30" -c PP16' -WorkingDirectory $PSScriptRoot -PassThru |
    Select-Object Id, ProcessName
