$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Force -Path obj/checks,obj/filechecks | Out-Null
    $compiler = './tools/fpc-i8086/app/bin/i386-win32/ppcross8086.exe'
    foreach ($group in @('VIDEO','VIEW','DRAW','UNDO','RESPONSE','FILEUI')) {
        $unitDir = "obj/checks/$group"
        $exe = switch ($group) { 'RESPONSE' { 'PPTRESP' } 'FILEUI' { 'PPTFUI' } default { "PPT$group" } }
        New-Item -ItemType Directory -Force -Path $unitDir | Out-Null
        & $compiler '-n' '@pp16.cfg' "-FU$unitDir" '-FEobj/checks' "-dPP16_${group}_TEST" "-o$exe.EXE" 'tests/PPTEST.PAS'
        if ($LASTEXITCODE -ne 0) { throw "$group harness build failed" }
    }
    & $compiler '-n' '@pp16.cfg' '-FUobj/filechecks' '-FEobj/checks' '-dPP16_FILE_TEST' '-oPPTFILE.EXE' 'tests/FILETEST.PAS'
    if ($LASTEXITCODE -ne 0) { throw 'File harness build failed' }
    & $compiler '-n' '@pp16.cfg' '-FUobj/checks' '-FEobj/checks' '-oPPSTART.EXE' 'tests/PPSTART.PAS'
    if ($LASTEXITCODE -ne 0) { throw 'Production launch driver build failed' }
} finally { Pop-Location }
