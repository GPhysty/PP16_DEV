param([ValidateSet('Small','Medium')][string]$MemoryModel = 'Medium')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    if ($MemoryModel -eq 'Small') {
        throw 'The v1.1 gradient editor requires Medium. The frozen Small release is in dist/PP16V10.'
    }
    $config = if ($MemoryModel -eq 'Medium') { 'pp16-medium.cfg' } else { 'pp16.cfg' }
    $output = if ($MemoryModel -eq 'Medium') { 'out/medium' } else { 'out' }
    $units = if ($MemoryModel -eq 'Medium') { 'obj/medium' } else { 'obj' }
    if (($MemoryModel -eq 'Medium') -and -not (Test-Path tools/fpc-i8086/app/units/msdos/8086-medium/rtl/system.ppu)) {
        throw 'Run config/build-medium-rtl.ps1 first; see docs/MEDIUM-MODEL.md.'
    }
    New-Item -ItemType Directory -Force -Path $output,$units | Out-Null
    if (($MemoryModel -eq 'Medium') -and (Test-Path -LiteralPath 'out/PP16UI.P16')) {
        Copy-Item -LiteralPath out/PP16UI.P16 -Destination "$output/PP16UI.P16"
    }
    if (-not (Test-Path -LiteralPath "$output/PP16UI.P16")) {
        & python -X utf8 config/make_ui_atlas.py "$output/PP16UI.P16"
        if ($LASTEXITCODE -ne 0) { throw 'Toolbar atlas seed failed.' }
    }
    "`nPP16 $MemoryModel build $(Get-Date -Format s)" | Tee-Object -FilePath obj/monitor.log -Append
    & './tools/fpc-i8086/app/bin/i386-win32/ppcross8086.exe' '-n' "@$config" '-dPP16_CLIP_ENABLED' '-B' 'PP16.PAS' 2>&1 |
        Tee-Object -FilePath obj/monitor.log -Append
    if ($LASTEXITCODE -ne 0) { throw 'PP16 build failed.' }
    Get-Item "$output/PP16.EXE" | Select-Object Name, Length | Format-Table | Out-String |
        Tee-Object -FilePath obj/monitor.log -Append
} finally { Pop-Location }
