param([ValidateSet('Small','Medium')][string]$MemoryModel = 'Small')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    $config = if ($MemoryModel -eq 'Medium') { 'pp16-medium.cfg' } else { 'pp16.cfg' }
    $checks = if ($MemoryModel -eq 'Medium') { 'obj/medium-checks' } else { 'obj/checks' }
    $fileUnits = if ($MemoryModel -eq 'Medium') { 'obj/medium-filechecks' } else { 'obj/filechecks' }
    New-Item -ItemType Directory -Force -Path $checks,$fileUnits | Out-Null
    $compiler = './tools/fpc-i8086/app/bin/i386-win32/ppcross8086.exe'
    foreach ($group in @('VIDEO','VIEW','DRAW','UNDO','RESPONSE','FILEUI','CLIP')) {
        $unitDir = "$checks/$group"
        $exe = switch ($group) { 'RESPONSE' { 'PPTRESP' } 'FILEUI' { 'PPTFUI' } default { "PPT$group" } }
        New-Item -ItemType Directory -Force -Path $unitDir | Out-Null
        $defines = @("-dPP16_${group}_TEST")
        if ($group -eq 'CLIP') { $defines += '-dPP16_CLIP_ENABLED' }
        $source = if ($group -eq 'CLIP') { 'tests/CLIPRUN.PAS' } else { 'tests/PPTEST.PAS' }
        & $compiler '-n' "@$config" "-FU$unitDir" "-FE$checks" $defines "-o$exe.EXE" $source
        if ($LASTEXITCODE -ne 0) { throw "$group harness build failed" }
    }
    $ellipseUnitDir = "$checks/ELLIPSE"
    New-Item -ItemType Directory -Force -Path $ellipseUnitDir | Out-Null
    & $compiler '-n' "@$config" "-FU$ellipseUnitDir" "-FE$checks" '-oPPELLIP.EXE' 'tests/ELLIPSETEST.PAS'
    if ($LASTEXITCODE -ne 0) { throw 'Ellipse harness build failed' }
    & $compiler '-n' "@$config" "-FU$fileUnits" "-FE$checks" '-dPP16_FILE_TEST' '-oPPTFILE.EXE' 'tests/FILETEST.PAS'
    if ($LASTEXITCODE -ne 0) { throw 'File harness build failed' }
    & $compiler '-n' "@$config" "-FU$fileUnits" "-FE$checks" '-dPP16_FILE_TEST' '-oPPTCLPF.EXE' 'tests/CLPFILE.PAS'
    if ($LASTEXITCODE -ne 0) { throw 'CLP file harness build failed' }
    & $compiler '-n' "@$config" "-FU$checks" "-FE$checks" '-oPPSTART.EXE' 'tests/PPSTART.PAS'
    if ($LASTEXITCODE -ne 0) { throw 'Production launch driver build failed' }
} finally { Pop-Location }
