param([string]$SourceRoot = 'tools/fpc-src-3.2.2')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
    $compiler = './tools/fpc-i8086/app/bin/i386-win32/ppcross8086.exe'
    if ((& $compiler '-iV') -ne '3.2.2') { throw 'This runtime recipe requires the bundled FPC 3.2.2 compiler.' }
    $versionFile = Join-Path $SourceRoot 'compiler/version.pas'
    if (-not (Test-Path -LiteralPath $versionFile)) {
        throw 'Stage the FPC release_3_2_2 rtl and compiler/version.pas sources first; see docs/MEDIUM-MODEL.md.'
    }
    $version = Get-Content -LiteralPath $versionFile -Raw
    foreach ($field in @(@('version_nr','3'), @('release_nr','2'), @('patch_nr','2'))) {
        if ($version -notmatch ($field[0] + "\s*=\s*'" + $field[1] + "'")) {
            throw 'The runtime sources must be FPC 3.2.2, matching the compiler.'
        }
    }
    $sourcePath = (Resolve-Path -LiteralPath $SourceRoot).Path
    $runtime = Join-Path $projectRoot 'tools/fpc-i8086/app/units/msdos/8086-medium/rtl'
    New-Item -ItemType Directory -Force -Path $runtime,'obj' | Out-Null
    $options = @('-n','-Tmsdos','-Cp8086','-WmMedium','-Ur','-CX','-O1','-Os',
        "-Fi$sourcePath/rtl/inc", "-Fi$sourcePath/rtl/i8086", "-Fi$sourcePath/rtl/msdos",
        "-Fu$sourcePath/rtl/inc", "-Fu$sourcePath/rtl/msdos", "-Fu$runtime", "-FU$runtime",
        "-FD$projectRoot/tools/fpc-i8086/app/bin/i386-win32")
    "Medium RTL build $(Get-Date -Format s); source=$sourcePath" |
        Tee-Object -FilePath obj/medium-rtl-build.log -Append
    foreach ($unit in @('msdos/system.pp','inc/strings.pp','msdos/dos.pp')) {
        $compileOptions = $options
        if ($unit -eq 'msdos/system.pp') { $compileOptions += '-Us' }
        & $compiler @compileOptions "$sourcePath/rtl/$unit" 2>&1 |
            Tee-Object -FilePath obj/medium-rtl-build.log -Append | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Get-Content obj/medium-rtl-build.log -Tail 25
            throw "Medium runtime build failed: $unit"
        }
        Write-Output "Built medium runtime unit: $unit"
    }
    # All six 3.2.2 startup objects ship with the existing compiler package.
    Copy-Item -LiteralPath tools/fpc-i8086/app/units/msdos/8086-small/rtl/prt0m.o -Destination $runtime
    Write-Output "Medium runtime ready: $runtime"
} finally { Pop-Location }
