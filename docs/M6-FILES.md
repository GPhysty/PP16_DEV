# M6: native image files

The accepted canvas/pointer baseline is preserved, with sources and executable,
in `obj/accepted-ui-20260920-103556`. The user accepted its smoother emulator
behavior and requested the next milestone. Their CRT shader/profile is unchanged.

## Workflow

File > Save writes the current filename. An unnamed image opens Save As;
File > Save As always opens it. File > Open opens a filename dialog. New clears
the filename. The title shows the filename and
an asterisk while the document is dirty. Saving preserves one-level undo;
undoing away from the saved pixels correctly marks the image dirty again.

The blue dialogs follow the reference layout at 320x200. Type an 8.3 filename,
or select a listed `.P16` or `.CLP` file. Tab cycles filename, list, OK and Cancel.
Arrows/Page Up/Down move through the list. Home/End move through the filename
or list; Backspace/Delete edit the filename. Enter accepts, Escape cancels,
and the corresponding mouse controls work. Up to 64 names are listed; additional
files can still be opened by typing their names. This increment uses the current
directory; it does not include a directory browser.

Save As checks before replacing an existing file and defaults to Cancel.
Canceling replacement returns to the filename dialog. Save to an already named
document updates that file directly, retaining its previous version in TRASH.
New/Exit on a dirty image retain the established Cancel/Discard prompt.
Open first selects a filename, then offers Discard only when replacing a dirty
image with a `.P16`. Cancel is the default. A failed read leaves the current
pixels, filename, dirty flag and undo intact. Opening `.CLP` loads only the
clipboard; Save As with a `.CLP` name saves only the clipboard. Both keep the
current image and its filename, edits, undo and view. An omitted extension still
defaults to `.P16`; File > Save continues to save the current document.

## Storage and recovery

See [P16 format](P16-FORMAT.md). M6 keeps the existing 64x64 document size and
identity palette. Odd-width and other unsupported dimensions are rejected;
variable-size editing remains M9. `.PUT` is not the native format.

Writes use a fresh `TRASH\YYYYMMDD\Snnnn\NEW.TMP`, checked byte counts and checked
close. The file is then reopened and compared against the header and every
packed document byte. Only a verified file can replace the destination.
Existing files move into the same subfolder under their original names. If the
final rename fails, restoration to the original filename is attempted. A failed
restoration leaves the original safely in that TRASH subfolder and reports it.
No previous files, temporary files or backups are deleted by this implementation.

Loads validate the entire file in a separate 2 KB staging buffer before replacing
the document. Successful loads start clean with no undo snapshot. Errors appear
inside the filename dialog; recoverable I/O errors do not terminate the editor.

## Verification approach

`check-pp16.ps1 -FileOnly` runs menu-driven UI dispatch, actual editor processes
driven through simulated mouse menu clicks, and independent file tests. A saved
image is reopened in a new DOS process and all 4,096 pixels are compared. Python independently writes
invalid input fixtures and checks output headers, pixels and retained originals.

Tests cover empty/short/truncated files, wrong signature/version/flags/palette/
payload length, trailing bytes, unsupported odd dimensions, missing files,
invalid/device/path filenames, read-only files, directory targets and an unusable
TRASH path. A test-only build injects a short write, replacement-rename failure
and rollback-rename failure. These are deterministic fault tests, not a claim
of physically filling a disk or interrupting power. The production build has
no fault-injection hooks. The DOS memory chain is compared before and after.

The editor and regression harnesses share the same production units. Harnesses
are separate 8086/small-model EXEs so tests no longer consume the editor's code
segment. `PPSTART.EXE` additionally executes the actual `PP16.EXE` through its
File menu and filename dialog; its saved demo is independently checked pixel for pixel.
Physical HX and Microsoft's DOS 3.3 remain separate validation targets.

The menu-only shortcut cleanup passed this full file workflow in
`obj/pp16-20261003-092556-3e24f4`.

The complete M1-M6 run passed at 3,000 cycles/ms in
`obj/pp16-20260920-105950-e43f5a`, including exact DOS memory-chain restoration.
The visually inspected file-dialog framebuffer is [M6-open.png](screenshots/M6-open.png).

## Save/restart crash fix - September 20

The user reported being returned to DOS after saving, and file dialogs failing
until the saved `.P16` was removed. The earlier full-suite pass used a host with
long filenames disabled. Reproduction with LFNs enabled produced runtime error
257 when an existing image was found, on both the bundled DOSBox and the installed
`C:\DOSBox\DOSBoxX\dosbox-x.exe`. Failure logs are under
`obj/filecrash-20260920-112138/long71` and `long33`.

TFiles now sets the process-local `System.LFNSupport` flag to False during unit
initialization. This keeps file operations on the DOS 8.3 interface already
required by PP16. It does not change the emulator's settings or the file format.
The [FPC 3.2.2 DOS unit](https://raw.githubusercontent.com/fpc/FPCSource/release_3_2_2/rtl/msdos/dos.pp)
selects its normal or LFN search routines using that flag. This is a workaround
for the failing runtime path, not a claim that the LFN implementation was repaired.

The fixed production EXE passed twelve save/restart sessions in the installed
DOSBox executable: create `DEMO.P16`, create `PLANET.P16` with the first file
present, reopen PLANET, and cancel replacement of it. All four sequences passed
under reported DOS 7.1 with LFNs, reported DOS 3.3 with LFNs, and reported DOS 3.3
without LFNs. Saved files were 2,068 bytes and matched byte for byte. Reports:
`obj/filecrash-20260920-112627`. The additional 750-cycle M6 recovery-suite rerun
was declined and is not counted as a pass; the earlier full-suite result above
belongs to the pre-fix build.

`check-file-crash.ps1` preserves this reproduction and can accept `-DosBoxPath`.
The normal file-test profiles now enable LFNs so future regression runs cover
this host configuration. `PPSTART` also accepts a test filename and sends enough
Escape keys to cancel a replacement prompt, close the dialog and exit.

The pre-fix executable, map and file units remain in
`obj/before-lfn-fix-20260920-112546`. The corrected EXE is 65,140 bytes, with
56,562 code bytes and the same 16,094-byte initial near heap. Both
`out/PP16.EXE` and `out/M6.EXE` contain the corrected build.

## Current I/O cleanup

Both formats share one reader. Open and save verification read the complete
bounded payload into a 2,048-byte stack buffer in one DOS block read. Open
stages it; verification compares it byte-for-byte against the staged source.
Shared CompareByte calls also replace the header and saved-undo comparison
loops. This recovered 291 linked code bytes before extending the format, while
retaining range/overflow checks and rollback/recovery behavior. The stack remains
8,192 bytes; the additional read buffer is temporary, not another persistent clip.
