param([ValidateSet('8086', '386')][string]$Cpu = '8086')
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path (Join-Path $PSScriptRoot 'obj') | Out-Null
$dosbox = Join-Path $env:USERPROFILE '.vscode\extensions\xsro.vscode-dosbox-0.1.8-win32-x64\emu\dosbox_x\win32-x64\dosbox-x.exe'
$projectRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path.TrimEnd('\')
$trashRoot = Join-Path $projectRoot 'trash'
if ((Test-Path -LiteralPath $trashRoot) -and
    ((Get-Item -LiteralPath $trashRoot -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'The trash directory must be a normal directory inside this project.'
}
$trashBatch = Join-Path $trashRoot ('test-results-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
foreach ($name in @('DEFAULT.TXT', 'RESULT.TXT')) {
    $previousResult = Join-Path $PSScriptRoot ('out\' + $name)
    if (Test-Path -LiteralPath $previousResult) {
        $sourcePath = (Resolve-Path -LiteralPath $previousResult).Path
        $destinationPath = [IO.Path]::GetFullPath((Join-Path $trashBatch $name))
        if (-not $sourcePath.StartsWith($projectRoot + '\out\', [StringComparison]::OrdinalIgnoreCase) -or
            -not $destinationPath.StartsWith($projectRoot + '\trash\', [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Result archive paths must stay inside the project.'
        }
        New-Item -ItemType Directory -Force -Path $trashBatch | Out-Null
        Move-Item -LiteralPath $sourcePath -Destination $destinationPath
    }
}
Set-Content -LiteralPath (Join-Path $PSScriptRoot 'obj\check-cpu.conf') -Value "[cpu]`r`ncputype=$Cpu" -Encoding ASCII
$arguments = '-nopromptfolder -conf dosbox-x.conf -conf obj/check-cpu.conf -noautoexec -c "mount c out" -c "c:" -c "ver > DEFAULT.TXT" -c "ver set 3 30" -c "HXTEST.EXE > RESULT.TXT" -c exit'
$run = Start-Process -FilePath $dosbox -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $PSScriptRoot 'obj\dosbox-stdout.log') -RedirectStandardError (Join-Path $PSScriptRoot 'obj\dosbox-stderr.log')
if (-not $run.WaitForExit(20000)) {
    $run.Kill()
    throw 'DOSBox-X test timed out.'
}
& {
    Write-Output "DOSBox-X verification, CPU=$Cpu"
    foreach ($name in @('DEFAULT.TXT', 'RESULT.TXT')) {
        $path = Join-Path $PSScriptRoot ('out\' + $name)
        if (Test-Path -LiteralPath $path) {
            Write-Output ($name + ':')
            Get-Content -LiteralPath $path
        }
    }
} | Tee-Object -FilePath (Join-Path $PSScriptRoot 'obj\monitor.log') -Append
if (-not (Select-String -LiteralPath (Join-Path $PSScriptRoot 'out\RESULT.TXT') -Pattern '^ALL TESTS PASSED$' -Quiet)) {
    throw 'The DOS program did not report success.'
}
