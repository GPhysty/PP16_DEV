$ErrorActionPreference = 'Stop'
$extensionRoot = Join-Path $env:USERPROFILE '.vscode\extensions'
$dosbox = Get-ChildItem -LiteralPath $extensionRoot -Directory -Filter 'xsro.vscode-dosbox-*-win32-x64' |
    Sort-Object LastWriteTime -Descending |
    ForEach-Object { Join-Path $_.FullName 'emu\dosbox_x\win32-x64\dosbox-x.exe' } |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1
if (-not $dosbox) { throw 'The VSCode DOSBox extension with DOSBox-X was not found.' }
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'out\HXTEST.EXE'))) {
    throw 'Build HXTEST.EXE first with the FPC Toolkit task or build.ps1.'
}
Push-Location $PSScriptRoot
try {
    # Interactive task: leave the emulator open for keyboard input and inspection.
    & $dosbox '-nopromptfolder' '-conf' 'dosbox-x.conf'
    if ($LASTEXITCODE -ne 0) { throw "DOSBox-X exited with code $LASTEXITCODE." }
} finally {
    Pop-Location
}
