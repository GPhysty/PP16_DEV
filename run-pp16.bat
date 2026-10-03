@echo off
setlocal

set "DOSBOXX=C:\DOSBox\DOSBoxX\dosbox-x.exe"
set "PROJECT_DIR=%~dp0"

if not exist "%DOSBOXX%" (
    echo DOSBox-X was not found at:
    echo %DOSBOXX%
    pause
    exit /b 1
)

if not exist "%PROJECT_DIR%out\PP16.EXE" (
    echo PP16.EXE was not found at:
    echo %PROJECT_DIR%out\PP16.EXE
    echo.
    echo Build PP16 first, then run this launcher again.
    pause
    exit /b 1
)

pushd "%PROJECT_DIR%"
start "" "%DOSBOXX%" -nopromptfolder -conf "dosbox-x.conf" -conf "config\pp16.conf" -noautoexec -c "mount c out" -c "c:" -c "ver set 3 30" -c "PP16" -c "exit"
popd

endlocal
