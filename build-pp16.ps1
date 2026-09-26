$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Force -Path 'out', 'obj' | Out-Null
    "`nPP16 build $(Get-Date -Format s)" | Tee-Object -FilePath obj/monitor.log -Append
    & './tools/fpc-i8086/app/bin/i386-win32/ppcross8086.exe' '-n' '@pp16.cfg' '-dPP16_CLIP_ENABLED' '-B' 'PP16.PAS' 2>&1 |
        Tee-Object -FilePath obj/monitor.log -Append
    if ($LASTEXITCODE -ne 0) { throw 'PP16 build failed.' }
    Get-Item out/PP16.EXE | Select-Object Name, Length | Format-Table | Out-String |
        Tee-Object -FilePath obj/monitor.log -Append
} finally { Pop-Location }
