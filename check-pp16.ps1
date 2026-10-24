param([ValidateRange(300,10000)][int]$Cycles = 3000, [switch]$UndoOnly, [switch]$PerfOnly, [switch]$ResponseOnly, [switch]$FileOnly, [switch]$ClipOnly, [switch]$GradientOnly, [switch]$ImportOnly, [ValidateSet('Small','Medium')][string]$MemoryModel = 'Medium')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    # Each run has an isolated drive: keep past reports and avoid root/out clutter.
    $prefix = if ($MemoryModel -eq 'Medium') { 'pp16-medium-' } else { 'pp16-' }
    $output = if ($MemoryModel -eq 'Medium') { 'out/medium' } else { 'out' }
    $checksDir = if ($MemoryModel -eq 'Medium') { 'obj/medium-checks' } else { 'obj/checks' }
    $runName = $prefix + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,6)
    $runRel = 'obj/' + $runName
    $runDir = Join-Path $PSScriptRoot $runRel
    New-Item -ItemType Directory -Path $runDir | Out-Null
    Copy-Item -LiteralPath "$output/PP16.EXE","$output/PP16UI.P16" -Destination $runDir
    & ./build-checks.ps1 -MemoryModel $MemoryModel
    foreach ($name in @('PPTVIDEO','PPTVIEW','PPTDRAW','PPTUNDO','PPTRESP','PPTFUI','PPTCLIP','PPTFILE','PPELLIP','PPSTART','PPTCLPF','PPGRAD','PPIMPF','PPIMPU')) {
        Copy-Item -LiteralPath "$checksDir/$name.EXE" -Destination $runDir
    }
    & './tools/fpc-i8086/app/bin/i386-win32/ppcross8086.exe' '-n' '@hx8086.cfg' '-oMEMINFO.EXE' 'src/MEMINFO.PAS' 2>&1 |
        Tee-Object -FilePath obj/monitor.log -Append
    if ($LASTEXITCODE -ne 0) { throw 'Memory diagnostic build failed.' }
    Copy-Item -LiteralPath out/MEMINFO.EXE -Destination $runDir
    $dosbox = Join-Path $env:USERPROFILE '.vscode/extensions/xsro.vscode-dosbox-0.1.8-win32-x64/emu/dosbox_x/win32-x64/dosbox-x.exe'
    function Invoke-Profile([string]$Name, [string]$Settings, [string]$Commands) {
        $cfg = "$runRel/$Name.conf"
        @"
[cpu]
cycles=fixed $Cycles
$Settings
"@ | Set-Content -LiteralPath $cfg -Encoding ASCII
        "@echo off`r`nver set 3 30`r`n$Commands`r`nexit`r`n" | Set-Content -LiteralPath "$runDir/RUNTEST.BAT" -Encoding ASCII
        $arguments = '-nopromptfolder -conf dosbox-x.conf -conf ' + $cfg + ' -noautoexec -c "mount c ' + $runRel + '" -c "c:" -c RUNTEST.BAT -c exit'
        $p = Start-Process -FilePath $dosbox -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru
        $limit = (Get-Date).AddSeconds([Math]::Max(240, 240 * 3000 / $Cycles))
        while (-not $p.WaitForExit(1000)) {
            if ((Get-Date) -gt $limit) { $p.Kill(); throw "$Name timed out; reports retained in $runDir" }
        }
        if ($p.ExitCode -ne 0) { throw "$Name DOSBox exited $($p.ExitCode)" }
    }
    $runImport = $ImportOnly -or -not ($UndoOnly -or $PerfOnly -or $ResponseOnly -or $FileOnly -or $ClipOnly -or $GradientOnly)
    $importCommands = @'
MEMINFO > IMPPRE.TXT
PPIMPF > IMPORT.TXT
PPIMPU > IMPORTUI.TXT
CD IMAGES
C:\PPIMPF.EXE /SIBLING > SIBLING.TXT
CD ..
MEMINFO > IMPPOST.TXT
'@
    if ($runImport) {
        & python -X utf8 tests/importfixtures.py $runDir
        if ($LASTEXITCODE -ne 0) { throw 'Import fixture setup failed' }
    }
    if ($ImportOnly) {
        Invoke-Profile 'import' "[dos]`nint33=true`nlfn=true" $importCommands
        Copy-Item -LiteralPath "$runDir/IMPPRE.TXT" -Destination "$runDir/BEFORE.TXT"
        Copy-Item -LiteralPath "$runDir/IMPPOST.TXT" -Destination "$runDir/AFTER.TXT"
        $checks = @(@('IMPORT.TXT','IMPORT FILE CHECKS PASSED'), @('IMPORTUI.TXT','IMPORT UI CHECKS PASSED'), @('IMAGES/SIBLING.TXT','IMPORT FILE CHECKS PASSED'))
    } elseif ($GradientOnly) {
        Invoke-Profile 'gradient' "[dos]`nint33=true" "MEMINFO > BEFORE.TXT`r`nPPGRAD > GRADIENT.TXT`r`nMEMINFO > AFTER.TXT"
        $checks = ,@('GRADIENT.TXT','GRADIENT CHECKS PASSED')
    } elseif ($FileOnly) {
        Invoke-Profile 'fileui' "[dos]`nint33=true`nlfn=true" "MEMINFO > BEFORE.TXT`r`nPPTFUI /FILEUI > FILEUI.TXT`r`nMEMINFO > AFTER.TXT"
        $checks = ,@('FILEUI.TXT','M6 UI CHECKS PASSED')
    } elseif ($ResponseOnly) {
        Invoke-Profile 'response' "[dos]`nint33=true" "MEMINFO > BEFORE.TXT`r`nPPTRESP /RESP > RESPONSE.TXT`r`nMEMINFO > AFTER.TXT"
        $checks = ,@('RESPONSE.TXT','UI PERF CHECKS PASSED')
    } elseif ($PerfOnly) {
        Invoke-Profile 'perf' "[dos]`nint33=true" "MEMINFO > BEFORE.TXT`r`nPPTRESP /PERF > PERF.TXT`r`nMEMINFO > AFTER.TXT"
        $checks = ,@('PERF.TXT','UI PERF CHECKS PASSED')
    } elseif ($UndoOnly) {
        Invoke-Profile 'undo' "[dos]`nint33=true" "MEMINFO > BEFORE.TXT`r`nPPTUNDO /UNDOTEST > UNDO.TXT`r`nMEMINFO > AFTER.TXT"
        $checks = ,@('UNDO.TXT','M5 CHECKS PASSED')
    } elseif ($ClipOnly) {
        Invoke-Profile 'clip' "[dos]`nint33=true" "MEMINFO > BEFORE.TXT`r`nPPTCLIP /CLIPTEST > CLIP.TXT`r`nPPELLIP > ELLIPSE.TXT`r`nMEMINFO > AFTER.TXT"
        $checks = @(@('CLIP.TXT','M9 CHECKS PASSED'), @('ELLIPSE.TXT','ELLIPSE CHECKS PASSED'))
    } else {
        Invoke-Profile 'normal' "[dos]`nint33=true" @'
MEMINFO > BEFORE.TXT
PPTVIDEO /TEST > PIXELS.TXT
PPTVIDEO /MTEST > MOUSE.TXT
PPTVIEW /UITEST > VIEW.TXT
PPTDRAW /DRAWTEST > DRAW.TXT
PPTUNDO /UNDOTEST > UNDO.TXT
PPTCLIP /CLIPTEST > CLIP.TXT
PPELLIP > ELLIPSE.TXT
PPTRESP /RESP > RESPONSE.TXT
PPTFUI /FILEUI > FILEUI.TXT
PPTVIDEO /DUMP > DUMP.TXT
MEMINFO > AFTER.TXT
'@
    Invoke-Profile 'nomouse' "[dos]`nint33=false" 'PPTVIDEO /NTEST > NOMOUSE.TXT'
    Invoke-Profile 'wrongvid' "[dosbox]`nmachine=svga_s3" 'PP16 /PROBE > WRONGVID.TXT'
        $checks = @(@('PIXELS.TXT','M1 CHECKS PASSED'), @('MOUSE.TXT','M2 CHECKS PASSED'), @('VIEW.TXT','M3 CHECKS PASSED'), @('DRAW.TXT','M8 CHECKS PASSED'), @('UNDO.TXT','M5 CHECKS PASSED'), @('CLIP.TXT','M9 CHECKS PASSED'), @('ELLIPSE.TXT','ELLIPSE CHECKS PASSED'), @('RESPONSE.TXT','UI PERF CHECKS PASSED'), @('FILEUI.TXT','M6 UI CHECKS PASSED'), @('DUMP.TXT','M1 CHECKS PASSED'), @('NOMOUSE.TXT','MISSING DRIVER CHECK PASSED'), @('WRONGVID.TXT','REFUSED: Unsupported machine'))
    }
    if (-not ($ImportOnly -or $UndoOnly -or $PerfOnly -or $ResponseOnly -or $FileOnly -or $ClipOnly -or $GradientOnly)) {
        Invoke-Profile 'gradient' "[dos]`nint33=true" "MEMINFO > GRADPRE.TXT`r`nPPGRAD > GRADIENT.TXT`r`nMEMINFO > GRADPOST.TXT"
        if ((Get-Content "$runDir/GRADPRE.TXT" -Raw) -ne (Get-Content "$runDir/GRADPOST.TXT" -Raw)) { throw 'Gradient tests changed DOS memory chain.' }
        $checks += ,@('GRADIENT.TXT','GRADIENT CHECKS PASSED')
    }
    if ($FileOnly -or -not ($ImportOnly -or $UndoOnly -or $PerfOnly -or $ResponseOnly -or $ClipOnly -or $GradientOnly)) {
        & python -X utf8 tests/filefixtures.py $runDir
        if ($LASTEXITCODE -ne 0) { throw 'File fixture setup failed' }
        # Exercise a host that offers LFNs; PP16 must still use DOS 8.3 APIs.
        Invoke-Profile 'files' "[dos]`nint33=true`nlfn=true" @'
MEMINFO > FILEPRE.TXT
PPSTART /SAVE > PRODSAVE.TXT
PPSTART /OPEN > PRODOPEN.TXT
PPTFILE /WRITE > FWRITE.TXT
PPTFILE /READ > FREAD.TXT
PPTFILE /CHECK > FCHECK.TXT
CD BLOCKED
C:\PPTFILE.EXE /BLOCKED > BLOCKED.TXT
CD ..
MEMINFO > FILEPOST.TXT
'@
        $checks += @(@('FWRITE.TXT','M6 FILE CHECKS PASSED'), @('FREAD.TXT','M6 FILE CHECKS PASSED'), @('FCHECK.TXT','M6 FILE CHECKS PASSED'), @('BLOCKED/BLOCKED.TXT','M6 FILE CHECKS PASSED'))
        $checks += @(@('PRODSAVE.TXT','PRODUCTION SESSION PASSED'), @('PRODOPEN.TXT','PRODUCTION SESSION PASSED'))
        if ((Get-Content "$runDir/FILEPRE.TXT" -Raw) -ne (Get-Content "$runDir/FILEPOST.TXT" -Raw)) { throw 'File tests changed DOS memory chain.' }
        & python -X utf8 tests/filefixtures.py $runDir verify
        if ($LASTEXITCODE -ne 0) { throw 'Independent file verification failed' }
    }
    if ($FileOnly -or $ClipOnly -or -not ($ImportOnly -or $UndoOnly -or $PerfOnly -or $ResponseOnly -or $GradientOnly)) {
        & python -X utf8 tests/clpfixtures.py $runDir
        if ($LASTEXITCODE -ne 0) { throw 'CLP fixture setup failed' }
        Invoke-Profile 'clpfiles' "[dos]`nint33=true`nlfn=true" "MEMINFO > CLPPRE.TXT`r`nPPTCLPF /WRITE > CLPWRITE.TXT`r`nPPTCLPF /CHECK > CLPCHECK.TXT`r`nMEMINFO > CLPPOST.TXT"
        $checks += @(@('CLPWRITE.TXT','CLP FILE CHECKS PASSED'), @('CLPCHECK.TXT','CLP FILE CHECKS PASSED'))
        if ((Get-Content "$runDir/CLPPRE.TXT" -Raw) -ne (Get-Content "$runDir/CLPPOST.TXT" -Raw)) { throw 'CLP tests changed DOS memory chain.' }
        & python -X utf8 tests/clpfixtures.py $runDir verify
        if ($LASTEXITCODE -ne 0) { throw 'Independent CLP verification failed' }
    }
    if ($runImport) {
        if (-not $ImportOnly) {
            Invoke-Profile 'import' "[dos]`nint33=true`nlfn=true" $importCommands
            $checks += @(@('IMPORT.TXT','IMPORT FILE CHECKS PASSED'), @('IMPORTUI.TXT','IMPORT UI CHECKS PASSED'), @('IMAGES/SIBLING.TXT','IMPORT FILE CHECKS PASSED'))
        }
        if ((Get-Content "$runDir/IMPPRE.TXT" -Raw) -ne (Get-Content "$runDir/IMPPOST.TXT" -Raw)) { throw 'Import tests changed DOS memory chain.' }
        & python -X utf8 tests/importfixtures.py $runDir verify
        if ($LASTEXITCODE -ne 0) { throw 'Independent import verification failed' }
        & python -X utf8 tests/framecheck.py "$runDir/IMPORTED.BIN" "$runDir/IMPORTED.PNG" ui
        if ($LASTEXITCODE -ne 0) { throw 'Imported image framebuffer checks failed' }
        & python -X utf8 tests/framecheck.py "$runDir/IMPORTUI.BIN" "$runDir/IMPORTUI.PNG" import
        if ($LASTEXITCODE -ne 0) { throw 'Import dialog framebuffer checks failed' }
    }
    foreach ($pair in $checks) {
        $report = Get-Content -LiteralPath (Join-Path $runDir $pair[0]) -Raw
        $report | Tee-Object -FilePath obj/monitor.log -Append
        if (-not $report.Contains($pair[1]) -or $report -match 'FAIL:|Runtime error') { throw "Failed $($pair[0]); see $runDir" }
    }
    if ((Get-Content "$runDir/BEFORE.TXT" -Raw) -ne (Get-Content "$runDir/AFTER.TXT" -Raw)) { throw 'DOS memory chain did not restore exactly.' }
    if (-not ($ImportOnly -or $UndoOnly -or $PerfOnly -or $ResponseOnly -or $FileOnly -or $ClipOnly -or $GradientOnly)) {
        & python -X utf8 tests/filledshapecheck.py $runDir
        if ($LASTEXITCODE -ne 0) { throw 'Independent filled-shape verification failed.' }
    }
    if ($GradientOnly -or -not ($ImportOnly -or $UndoOnly -or $PerfOnly -or $ResponseOnly -or $FileOnly -or $ClipOnly)) {
        & python -X utf8 tests/gradfiles.py $runDir
        if ($LASTEXITCODE -ne 0) { throw 'Independent gradient file verification failed.' }
    }
    if ($PerfOnly) {
        & python -X utf8 tests/uiperfcheck.py $runDir
        if ($LASTEXITCODE -ne 0) { throw 'UI frames differ from full redraws.' }
    }
    if ($ImportOnly) { $scope = 'IMPORT' } elseif ($GradientOnly) { $scope = 'GRADIENT' } elseif ($FileOnly) { $scope = 'M6' } elseif ($ResponseOnly) { $scope = 'RESPONSE' } elseif ($PerfOnly) { $scope = 'UI PERF' } elseif ($UndoOnly) { $scope = 'M5' } elseif ($ClipOnly) { $scope = 'M9' } else { $scope = 'ALL PP16' }
    "$scope CHECKS PASSED ($Cycles cycles/ms); reports: $runRel" | Tee-Object -FilePath obj/monitor.log -Append
} finally { Pop-Location }
