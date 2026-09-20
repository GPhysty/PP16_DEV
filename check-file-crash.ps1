param([string]$DosBoxPath, [string]$EditorPath = 'out/PP16.EXE')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    if (-not $DosBoxPath) {
        $DosBoxPath = Join-Path $env:USERPROFILE '.vscode/extensions/xsro.vscode-dosbox-0.1.8-win32-x64/emu/dosbox_x/win32-x64/dosbox-x.exe'
    }
    $runName = 'filecrash-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
    $runDir = Join-Path $PSScriptRoot ('obj/' + $runName)
    New-Item -ItemType Directory -Path $runDir | Out-Null
    $cases = @(@('long71','true','7 10'), @('long33','true','3 30'), @('short33','false','3 30'))
    foreach ($case in $cases) {
        $caseDir = Join-Path $runDir $case[0]
        New-Item -ItemType Directory -Path $caseDir | Out-Null
        Copy-Item -LiteralPath $EditorPath -Destination (Join-Path $caseDir 'PP16.EXE')
        Copy-Item -LiteralPath obj/checks/PPSTART.EXE -Destination $caseDir
        @"
[cpu]
cycles=fixed 3000
[dos]
lfn=$($case[1])
int33=true
"@ | Set-Content -LiteralPath (Join-Path $caseDir 'CASE.CONF') -Encoding ASCII
        @"
@echo off
ver set $($case[2])
PPSTART /SAVE DEMO > SAVE.TXT
PPSTART /SAVE PLANET > SECOND.TXT
PPSTART /OPEN PLANET > OPEN.TXT
PPSTART /SAVE PLANET > AGAIN.TXT
exit
"@ | Set-Content -LiteralPath (Join-Path $caseDir 'RUN.BAT') -Encoding ASCII
        $rel = 'obj/' + $runName + '/' + $case[0]
        $arguments = '-nopromptfolder -conf dosbox-x.conf -conf ' + $rel + '/CASE.CONF -noautoexec -c "mount c ' + $rel + '" -c "c:" -c RUN.BAT'
        $p = Start-Process -FilePath $DosBoxPath -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru
        $deadline = (Get-Date).AddSeconds(120)
        while (-not $p.WaitForExit(1000)) {
            if ((Get-Date) -gt $deadline) { $p.Kill(); throw "Timed out: $caseDir" }
        }
        foreach ($report in @('SAVE.TXT','SECOND.TXT','OPEN.TXT','AGAIN.TXT')) {
            Write-Output ($case[0] + '/' + $report)
            $result = Get-Content -LiteralPath (Join-Path $caseDir $report) -Raw
            Write-Output $result
            if ($result -match 'FAIL:|Runtime error' -or $result -notmatch 'PRODUCTION SESSION PASSED') {
                throw "Save/restart regression failed: $caseDir/$report"
            }
        }
        $demo = Join-Path $caseDir 'DEMO.P16'
        $planet = Join-Path $caseDir 'PLANET.P16'
        if ((Get-Item $demo).Length -ne 2068 -or (Get-Item $planet).Length -ne 2068 -or
            (Get-FileHash $demo).Hash -ne (Get-FileHash $planet).Hash) {
            throw "Saved files differ or have the wrong length: $caseDir"
        }
    }
    Write-Output "SAVE/RESTART CHECKS PASSED; reports: $runDir"
} finally { Pop-Location }
