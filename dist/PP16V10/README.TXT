PP16 1.0 - START HERE
Release package: 23 October 2026
Copyright (C) 2026 Bartholomew Harner. All rights reserved.

PP16 edits one 64 x 64 pixel, 16-colour sprite frame at a time.
This is the ready-to-run DOS distribution. No compiler, source code,
PowerShell, Python or development tools are needed to install or use it.

REQUIREMENTS
------------
Tandy 1000HX-compatible hardware with 640 KiB installed conventional RAM,
Tandy 320 x 200 16-colour graphics, DOS, and a compatible DOS mouse driver.
The working directory must be writable. PP16 needs no GRAFIX TSR, ADJMEM,
EMS or XMS. It is a 16-bit DOS program; modern Windows cannot run it directly.

INSTALLATION
------------
1. Extract PP16V10.ZIP, keeping all ten supplied files in one directory.
   You can extract it on another computer and transfer the files to DOS.
2. At a DOS prompt, change to that package directory and type:

       INSTALL

   This creates C:\PP16. To choose another location, use for example:

       INSTALL D:\PP16

   Use a full DOS 8.3 path without spaces or quotation marks. The drive
   and parent directory must already exist. INSTALL /? shows usage.
3. Select the destination drive and directory, load your mouse driver,
   and run the editor. For the default destination:

       C:
       CD \PP16
       PP16

The installer refuses to overwrite any existing package file. Choose a
different folder if PP16 is already installed. It never deletes artwork,
changes PATH, or edits AUTOEXEC.BAT or CONFIG.SYS. If a copy fails, files
already copied remain; move the incomplete installation aside and retry.

You can also copy the supplied files into a new directory yourself.
PP16.EXE and PP16UI.P16 are the two required runtime files. Keep all supplied
documentation and notices with the program when passing the package on.

GETTING STARTED
---------------
Left-drag on the canvas to paint. Right-drag samples a colour. Select colours
from the palette with the left and right buttons. Use File / New for a blank
image. Use File / Save or Save As to write a DOS 8.3 name such as HERO.P16.
Use File / Open to reopen an image. Filenames are selected inside the editor;
PP16 does not open a filename passed on its command line.

F1 opens built-in help. HELP.TXT is a quick control reference; PP16.DOC is
the complete manual. TYPE HELP.TXT displays the quick reference under DOS.

WHAT IS INCLUDED
----------------
INSTALL.BAT     DOS-compatible installer. Run from the package directory.
PP16.EXE        Ready-to-run editor, including the optimized Clear actions.
PP16UI.P16      Required toolbar artwork; do not overwrite it with a drawing.
PP16.DOC        Complete user manual.
README.TXT      This installation and getting-started guide.
HELP.TXT        Quick controls and troubleshooting.
CREDITS.TXT     Author, reference and implementation credits.
FPCRTL.TXT      Free Pascal runtime redistribution exception, verbatim.
COPYING.TXT     GNU Library GPL accompanying the runtime notice, verbatim.
MANIFEST.TXT    SHA-256 checksums for the other nine package files.

SAVE AND RECOVERY
-----------------
Images and clipboard files are saved in the current directory. Replaced files
and failed temporary writes are retained under TRASH\YYYYMMDD\Snnnn. Keep
backups of your artwork and preserve TRASH when moving an installation.

The editor has one action of Undo, not a history list or Redo. Ctrl+Z consumes
that saved action. Escape cancels an unfinished stroke, shape or paste.

EMULATION AND VALIDATION
------------------------
DOSBox-X can run PP16 when configured as a Tandy with 640 KiB conventional
memory. Its built-in DOS can supply the mouse driver. Generic VGA emulation
is not the target configuration. Configure your emulator before starting.

This executable passed the project's complete DOSBox-X regression at
3,000 fixed cycles/ms. Physical HX timing and an actual DOS 3.3 boot remain
separate validation; changing an emulator's reported DOS version is not
a physical-hardware or genuine DOS 3.3 test.

Version 1.0 has no gradient/dither paint selector. That enhancement is planned
for version 1.1. No animation, variable-size editing or palette editor is
included in this release.

Project repository: https://github.com/GPhysty/PP16_DEV
