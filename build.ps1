$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Force -Path 'out', 'obj' | Out-Null
    $compilerOutput = & '.\tools\fpc-i8086\app\bin\i386-win32\ppcross8086.exe' '-n' '@hx8086.cfg' 'HXTEST.PAS' 2>&1
    $compilerExit = $LASTEXITCODE
    $compilerOutput | Tee-Object -FilePath 'obj\monitor.log' -Append
    if ($compilerExit -ne 0) { throw '16-bit DOS build failed.' }
    if (-not (Test-Path -LiteralPath '.\out\HXTEST.EXE')) { throw 'Compiler did not produce out\HXTEST.EXE.' }
} finally {
    Pop-Location
}
