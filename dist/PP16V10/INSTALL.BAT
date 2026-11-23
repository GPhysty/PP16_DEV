@echo off
echo.
echo =============================================================
echo                     PP16 1.0 INSTALLER
echo              64 x 64 Tandy sprite-frame editor
echo =============================================================
echo.
if "%1"=="/?" goto HELP
if "%1"=="?" goto HELP
if not "%2"=="" goto HELP
if "%1"=="" goto DEFAULT
set PP16DST=%1
goto CHECK
:DEFAULT
set PP16DST=C:\PP16
:CHECK
if not exist PP16.EXE goto SOURCE
if not exist PP16UI.P16 goto SOURCE
if not exist PP16.DOC goto SOURCE
if not exist README.TXT goto SOURCE
if not exist HELP.TXT goto SOURCE
if not exist CREDITS.TXT goto SOURCE
if not exist FPCRTL.TXT goto SOURCE
if not exist COPYING.TXT goto SOURCE
if not exist MANIFEST.TXT goto SOURCE
echo Destination: %PP16DST%
echo.
if exist %PP16DST%\PP16.EXE goto EXISTS
if exist %PP16DST%\PP16UI.P16 goto EXISTS
if exist %PP16DST%\PP16.DOC goto EXISTS
if exist %PP16DST%\README.TXT goto EXISTS
if exist %PP16DST%\HELP.TXT goto EXISTS
if exist %PP16DST%\CREDITS.TXT goto EXISTS
if exist %PP16DST%\FPCRTL.TXT goto EXISTS
if exist %PP16DST%\COPYING.TXT goto EXISTS
if exist %PP16DST%\MANIFEST.TXT goto EXISTS
if exist %PP16DST%\NUL goto COPY
md %PP16DST%
if not exist %PP16DST%\NUL goto DIRFAIL
:COPY
echo Copying the editor and user documentation...
copy PP16.EXE %PP16DST%\PP16.EXE > NUL
if errorlevel 1 goto COPYFAIL
copy PP16UI.P16 %PP16DST%\PP16UI.P16 > NUL
if errorlevel 1 goto COPYFAIL
copy PP16.DOC %PP16DST%\PP16.DOC > NUL
if errorlevel 1 goto COPYFAIL
copy README.TXT %PP16DST%\README.TXT > NUL
if errorlevel 1 goto COPYFAIL
copy HELP.TXT %PP16DST%\HELP.TXT > NUL
if errorlevel 1 goto COPYFAIL
copy CREDITS.TXT %PP16DST%\CREDITS.TXT > NUL
if errorlevel 1 goto COPYFAIL
copy FPCRTL.TXT %PP16DST%\FPCRTL.TXT > NUL
if errorlevel 1 goto COPYFAIL
copy COPYING.TXT %PP16DST%\COPYING.TXT > NUL
if errorlevel 1 goto COPYFAIL
copy MANIFEST.TXT %PP16DST%\MANIFEST.TXT > NUL
if errorlevel 1 goto COPYFAIL
echo.
echo Installation complete.
echo Switch to the destination drive, then type:
echo.
echo     CD %PP16DST%
echo     PP16
echo.
echo Load your DOS mouse driver before starting the editor.
echo Read README.TXT first. HELP.TXT is the quick reference.
echo PP16.DOC is the complete user manual.
goto END
:HELP
echo Run this installer from the extracted PP16 package directory.
echo.
echo     INSTALL             Install into C:\PP16
echo     INSTALL D:\PP16     Install into another directory
echo     INSTALL /?          Display this help
echo.
echo Use a full DOS 8.3 path without spaces or quotation marks.
echo The drive and parent directory must already exist.
echo Existing program or documentation files are never replaced.
goto END
:SOURCE
echo ERROR: An installation file is missing from this directory.
echo Change into the extracted package directory and run INSTALL.
echo Keep every supplied file together. No destination files copied.
goto END
:EXISTS
echo ERROR: The destination already contains a PP16 package file.
echo Nothing was copied or replaced. Choose a different directory.
echo Keep your existing artwork and TRASH recovery files safe.
goto END
:DIRFAIL
echo ERROR: Could not create or access %PP16DST%.
echo Check the drive, parent directory, free space and write protection.
goto END
:COPYFAIL
echo ERROR: A file could not be copied. Installation is incomplete.
echo Check free space and write protection. Files already copied remain.
echo Move the incomplete installation aside before trying again.
:END
set PP16DST=
