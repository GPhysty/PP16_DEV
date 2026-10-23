# Milestone ledger â€” 2026-09-19

## M0 â€” source audit/design recorded; interactive reference review pending

See M0-DESIGN.md and CREDITS.md. PP256 launched on a working copy, but native
screen capture/control failed. Its resolution and interactive behavior are
not reported as observed. This does not block the source-based renderer.

## M1 â€” emulator automated acceptance passed

- Four corner pixels, distinct first/last eight scanlines, all 16 swatches.
- Bank addressing, even/odd neighbor preservation, readback, clipped pixels,
  span/reference equality, boxes, and untouched bank-padding guards.
- Actual B800 write aliases the protected physical 98000 address in DOSBox.
- Three graphics/text cycles, no failures; DOS memory chain restored exactly.
- Existing ADJMEM reservation/restoration independently verified; see
  ADJMEM-PROBE.txt. PP16 uses ordinary DOS allocations instead of changing BDA.
- `out/M1.EXE` retains the original passing renderer checkpoint (25,712 bytes).
- `screenshots/M1-frame.png` is a rendering of the DOS framebuffer dump,
  **not a captured emulator window**. Its corner/color/scanline values were
  independently checked by `tests/framecheck.py`.
- Individual GRAF algorithms are implemented in Pascal. No ASM optimization,
  far-buffer storage, packed-image blitter or editor tools are claimed yet.

## M2 â€” mouse implementation and automated checks passed; hands-on gate pending

Requested by the user during M1, explicitly before GUI design.

- DOSBox's built-in INT33 driver detected. No driver upload/install needed.
- Explicitly configured range, then measured raw maximum 639,199. X scale 2;
  checked every X coordinate 0..319 and Y coordinate 0..199 and all four corners.
  Unsupported ranges fail safely rather than silently using a guessed scale.
- Press/held/both-button/release transitions checked using synthetic states.
  These are not a claim of an actual human drag test.
- Software cursor saves/restores its own background; clipped and overlapping
  movement checks compare video bytes. Driver cursor stays hidden. Repaints
  happen only on input changes; redraw hides the cursor first.
- Missing-driver test disables INT33 in a separate emulator run. Wrong-video
  profile is refused before graphics access. Clean text-mode restoration.
- Current PP16.EXE:30,738 bytes; compiler reports 28,415 code bytes and 2,224
  initialized data bytes, plus 2,618 bytes of BSS. Stack 8,192 bytes, initial near heap about 52,414 bytes.
  No document/undo/clipboard allocation yet. A future 64x64 document and undo
  need 2,048 bytes each; a full-screen pair does not fit the small near segment.
- Reports: M1-TESTS.txt, M2-TESTS.txt and isolated `obj/pp16-*` runs.
  Automated checks used 3,000 cycles/ms; visible launch retains 300 cycles/ms.
  These are emulator throughput settings, not measured HX/V20 performance.
- Range checks and overflow checks remain enabled; target remains 8086,
  small-model real-mode DOS, with no FPU/EMS/XMS/UMB requirement.

## Hands-on check before M3

Run `run-pp16.ps1` (build first if edited). Move to each corner, confirm
coordinates 0,0 through 319,199, click/hold/drag/release left and right, and
watch for cursor trails. Press R under the pointer to verify redraw, then
Escape to leave. Re-run PP16 at the DOS prompt to verify another session.
If movement is not reaching the window edges, DOSBox's Ctrl+F10 captures or
releases the host mouse. Physical HX and real DOS 3.3 validation remain pending.

The next milestone is M3's GUI/view layout after reviewing mouse behavior.
Future controls must own their drag from initial press to release, consume
palette/dialog clicks, and cancel previews on Escape. No paint or GUI work
has been started. PicoMEM EMS/XMS support is recorded as optional future memory.

## M3 - reference-style interface and view

User accepted M2's mouse demonstration and supplied PP256 layout, dropdown
and file-dialog screenshots. M3 follows that visual reference; see
[M3 interface](M3-INTERFACE.md) and [preview](screenshots/M3-layout.png).
Navigation and UI selection work; the fixture remains read-only. Native .P16
save and legacy .PUT compatibility are separate future features.
Automated M1/M2/M3 checks passed at 3,000 cycles/ms. Hands-on M3 and physical
HX tests remain pending. Executable: 48,546 bytes. Compiler: 42,452 code bytes,
5,984 initialized data bytes; the stack remains 8,192 bytes. Initial near heap
is about 46 KB, including the allocated 2 KB fixture. No undo/clipboard yet.

M3 follow-up: corrected the eight tool meanings/order and redrew them as
recognizable pixel glyphs. Added all 14 Utilities entries, hover descriptions,
click/drag selection and cancel behavior, with unchanged document verification.
The Action menu follows the selected effect; applying effects remains deferred.

## M4 - first drawing checkpoint

Brush and eraser now modify the packed document, right-drag samples its colors,
and the canvas/preview update from changed row spans. Dirty state is visible.
Gesture capture prevents painting through controls, menu dismissal or canvas
exit/re-entry gaps. All automated M1/M2/M3/M4 checks passed. The 16-point
stroke repainted 46 cells in 1 BIOS tick at 3,000 cycles/ms; idle repaint is zero.
EXE: 58,338 bytes; code: 48,558 bytes; near heap: 42,606 bytes on /DRAWTEST.
See [M4 behavior](M4-DRAWING.md) and M4-TESTS.txt. Hands-on review is pending.
Save and undo remain M6/M5; M3.EXE preserves the previous passing interface.

## M5 - undo, cancellation and unsaved-change protection

Current checkpoint supersedes the historical status notes above. The user
accepted M4 drawing and selected 750 cycles for interactive PP16 launches.

M5 adds consumed one-level undo for completed brush/eraser strokes and Clear,
Escape rollback of an active stroke while preserving previous undo, black and
foreground-color Clear, blank New, and Cancel/Discard protection for dirty
New/Exit. Cancel is the default. Keyboard and mouse controls share tested
dispatch; modal clicks cannot leak to the canvas. Save remains M6.

Full M1-M5, missing-mouse and wrong-video checks passed at 3,000 cycles/ms in
`obj/pp16-20260919-220410-d721dc`. Focused M5 passed at 750 cycles/ms in
`obj/pp16-20260919-221131-ab1418`. Both runs restored the DOS memory chain
exactly. An earlier full 750-cycle attempt timed out in M3 under the old
180-second harness limit and is not counted as a pass. The runner now scales
its timeout with cycle settings and supports focused `-UndoOnly` checks.

EXE: 64,648 bytes; code: 53,363 bytes; initialized data: 11,174 bytes;
stack: 8,192 bytes; initial near heap: 37,006 bytes on /UNDOTEST. Two 2 KB
packed snapshots use conventional memory. No EMS/XMS requirement was added.
The M4 stroke fixture still repaints 46 cells (2 BIOS ticks at 3,000 cycles).
Frame assertions passed; the confirmation dialog was visually inspected from
its DOS framebuffer dump. M5 hands-on and physical HX/DOS 3.3 checks remain
pending. `out/M4.EXE` preserves the previous drawing build.

See [M5 behavior](M5-UNDO.md), [reports](M5-TESTS.txt), and
[confirmation frame](screenshots/M5-confirm.png). Next: M6 native save/open.

## Interface optimization checkpoint - 2026-09-20

Before M6, the user requested reducing interface redraw cost and confirmed the
HX's 128 KB video-capable system-RAM window. Saved-under popup rectangles,
targeted selection controls and preview-outline updates now replace unnecessary
full redraws. A 12 KB near-data buffer and a segment-aware 8086 row-copy routine
support popup restoration. A checked Pascal copy remains as a reference.

At the same 750 cycles/ms, six-menu switching improved from 876 to 94 BIOS ticks;
Help open/close from 278 to 16; color changes from 18 to 4; tool selection from
32 to 6; pan/zoom from 281 to 198. File opening alone stayed at 20 ticks.
All ten interaction frames equal full redraws, the old build and the Pascal-copy
reference byte for byte. Final M1-M5 regression passed at 3,000 cycles/ms, with
exact DOS memory restoration and all seven regression frames matching old M5.

EXE: 68,154 bytes; code: 56,806; initialized data: 11,239; stack: 8,192;
initial near heap: 24,618 bytes on /PERF. One 32 KB hardware page remains reserved.
64/128 KB reservations for two/four pages are documented options, requiring
expanded DOS ownership checks and a page synchronization design before use.
`out/M5.EXE` and the source snapshot in `obj/m5-before-ui-20260919-222734`
preserve the previous build. Physical HX and hands-on acceptance remain pending.

See [redraw design, timings and page options](UI-REDRAW.md) and
[test evidence](UI-PERF-TESTS.txt). Next remains M6 native save/open.

## M6 - native save/open

M6 adds native `.P16` Save, Save As and Open with keyboard and mouse filename
dialogs. Files use a documented, versioned 20-byte header and a 2,048-byte
packed 64x64 payload. Loads validate into staging storage before changing the
document. Saves write and verify a temporary file under a dated TRASH folder,
then preserve an existing destination there before replacement. Failed reads
and writes retain the document; failed replacement retains or restores the old
file. Save preserves undo, and undo after save correctly marks the image dirty.

The full M1-M6 suite passed at 3,000 cycles/ms in
`obj/pp16-20260920-105950-e43f5a`. It includes pixel-exact round trips across
separate DOS processes, malformed and unsupported files, invalid names,
read-only/directory targets, an obstructed TRASH path, and injected short-write,
rename and rollback failures. The actual production editor also completed
scripted Save and Open sessions. Independent host checks verified the header,
all pixels, retained originals and partial-write artifact. Missing-mouse and
wrong-video behavior still pass, and DOS memory chains restore exactly.

The production executable is 65,124 bytes (56,557 code and 8,466 initialized
data bytes), with an 8,192-byte stack and 16,094 bytes of initial near heap.
Regression harnesses are now separate EXEs so they do not consume production
code space. `out/M6.EXE` preserves this passing build. See [M6 behavior](M6-FILES.md)
and the [P16 format specification](P16-FORMAT.md). Physical HX/DOS 3.3 file I/O
and hands-on dialog acceptance remain pending. Next is M7 basic shape tools.

M6 follow-up: the user's save/restart report exposed runtime error 257 in the
FPC LFN search path when DOSBox offered long filenames. TFiles now explicitly
uses the DOS 8.3 API within PP16. Twelve production save/restart sessions passed
across LFN on/off and reported DOS 3.3/7.1 in the installed DOSBox executable;
see `obj/filecrash-20260920-112627`. The additional 750-cycle recovery rerun was
declined. The corrected PP16/M6 EXE is 65,140 bytes; the pre-fix executable and
affected sources are preserved in `obj/before-lfn-fix-20260920-112546`.

## M7 - basic shape tools

The existing Circle, Square and Line controls are now active outline tools.
They use the foreground color and commit only on release: Line joins its press
and release points, Square uses its press point as the first corner and stays
square, and Circle uses its press point as the centre and the farther drag axis
as its radius. Shapes are clipped safely at document boundaries. A completed
shape consumes the existing one-level undo slot; Escape cancels the pending
shape without changing pixels or replacing the prior undo.

The small-model regression harnesses are now compiled as focused DOS 8.3-named
executables. This keeps each test image below the 64 KB code-segment limit while
testing the same production units. M7 geometry, undo and cancellation checks
run through real pointer dispatch; M1-M6 coverage remains in the full suite.

The full M1-M7 suite passed at 3,000 cycles/ms in
`obj/pp16-20260920-155151-65e6ef`, including the native-file regression,
missing-mouse/wrong-video profiles, independent file verification, and exact
DOS memory-chain comparisons. The production EXE is 66,328 bytes (57,757 code
and 8,470 initialized-data bytes) with an initial near heap of 16,082 bytes.

See [M7 behavior and checks](M7-SHAPES.md). Next: M8 bucket fill and basic
selection/cut-copy-paste design.

M7 follow-up: shape drags now draw a live, canvas-only outline before release.
The M1-M7 suite passed again at 3,000 cycles/ms in
`obj/pp16-20260920-162338-3809ee`; its focused shape checks include live-preview
visibility and Escape cleanup. The corrected production EXE is 68,056 bytes
(59,478 code and 8,470 initialized-data bytes).

## M8 - bucket fill and clipboard design

Bucket Fill is now active. A left click replaces its four-connected source-color
region with the foreground color, preserving color borders and right-click
sampling. Each changed fill is one undoable action; a same-color click preserves
the prior undo. The implementation uses a bounded 6,144-byte packed-coordinate
stack and needs no EMS/XMS.

M8 also records the agreed selection/clipboard contract: a bounded 64 by 64
packed clipboard, rectangle metadata, opaque clipped paste, UI-only selection
and paste overlays, Copy without undo, and Cut/Paste as one undoable action.
Cut, Copy and Paste themselves remain a later dedicated implementation
milestone.

The full M1-M8 suite passed at 3,000 cycles/ms in
`obj/pp16-20260920-165632-5fa365`, including 4,096-pixel fill and undo checks,
file recovery, memory-chain comparisons and independent file verification. The
production EXE is 69,290 bytes (60,730 code and 8,456 initialized-data bytes),
with 9,950 bytes of initial near heap. See
[M8 behavior and clipboard design](M8-FILL-CLIPBOARD-DESIGN.md). Next: a
dedicated selection, Cut, Copy and Paste implementation milestone.

## M9 - selection, Cut, Copy and Paste

The Cut toolbar control is now Select: drag an inclusive document-aligned
rectangle with a canvas-only border. A fixed 2,048-byte conventional-memory
clipboard stores up to a full 64 by 64 selection high-nibble-first. It survives
New/Open for the current session and is never saved in `.P16`.

Copy is document-neutral. Cut copies then clears the selection to the current
background color as one undoable action. Paste is opaque: Ctrl+V or Edit > Paste
opens a floating outline centered in the visible canvas. Mouse movement and the
arrow keys move it; left click or Enter commits one clipped action; Escape
cancels without replacing an earlier undo. Each move restores and redraws only
the outline, rather than the full canvas or clipboard pixels. Ctrl+C and Ctrl+X
provide Copy and Cut; menu availability follows selection, clipboard and undo
state.

The focused M9 harness passed at 3,000 cycles/ms in
`obj/pp16-20260926-091226-732e8a`. The full M1-M9 suite passed at 3,000
cycles/ms in `obj/pp16-20260926-091250-98e9ee`, including file recovery,
missing-mouse/wrong-video profiles, independent file verification and exact DOS
memory-chain comparisons. Production EXE: 73,208 bytes; code: 64,600 bytes;
initialized data: 8,502 bytes; initial near heap: 7,826 bytes. No EMS/XMS
requirement was added. See [M9 behavior and checks](M9-CLIPBOARD.md).

Next: live interaction acceptance of selection/clipboard behavior on DOSBox-X
and physical HX/DOS 3.3 validation; transparency, Paste Behind and persistent
clipboard files remain intentionally deferred.

## M9 optimization checkpoint - 2026-09-27

The accepted M9 source was compacted and its repeated rendering paths were
measured before each change was retained. FPC now uses `-O1 -Os`; the compact
3x5 UI font stores 15-bit glyph values rather than temporary strings. Line,
Square and Circle use one shared rasterizer for committed document pixels and
temporary preview pixels. Live shape movement restores only the prior outline,
rather than rebuilding the full canvas. Full actual-size preview redraws use
packed rows, and even-aligned/even-width clipboard copies use packed document
rows; odd cases retain their pixel-accurate fallback.

The complete M1-M9 suite passed at 3,000 cycles/ms in
`obj/pp16-20260927-125542-e24c91`, including Clipboard, file recovery,
missing-mouse/wrong-video profiles, production Save/Open sessions and DOS
memory-chain verification. The production executable is 69,782 bytes: 61,758
code bytes and 7,924 initialized-data bytes, leaving 3,778 bytes of headroom
below the 65,536-byte small-model code-segment ceiling. `out/M9.EXE` preserves
this optimized M9 checkpoint; `out/PP16.EXE` remains the current working build.

M9 rendering follow-up: the 1x canvas builder now copies each packed source row
into its odd-aligned canvas row instead of decoding 64 pixels one at a time.
Higher zoom modes continue using the existing scale/grid-aware path. The full
M1-M9 suite passed at 3,000 cycles/ms in `obj/pp16-20260927-130614-1b45a2`.
The current production build is 69,878 bytes (61,845 code bytes and 7,924
initialized-data bytes), leaving 3,691 code bytes below the small-model limit.

M9 file-buffer follow-up: normal `.P16` Open now reads its 2,048-byte payload
directly into the staging document buffer, replacing 32 row reads and staging
copies. Save verification intentionally remains row-by-row. The complete suite
passed at 3,000 cycles/ms in `obj/pp16-20260927-131718-3061eb`; the current
production EXE is 69,910 bytes (61,873 code bytes, 7,924 initialized data),
leaving 3,663 bytes of code headroom.

M9 interface cleanup: removed the dead-end file, palette, animation, screen
designer, printer and fixed-size Image-management placeholders. Utilities and
all future-capable image/clipboard operations remain deferred. The full suite
passed at 3,000 cycles/ms in `obj/pp16-20260927-133646-a95369`. The production
build is 69,864 bytes (61,860 code bytes and 7,894 initialized-data bytes),
leaving 3,676 bytes of code headroom.

M9 Utilities cleanup: removed BRIGHT, DARK, TINT, GREY and XOR from the
Utilities selector, and removed View's Brighter/Darker Shade entries. Those
operations either require an explicit mapping of the fixed 16-colour palette or
are unreliable when applied to palette indices. The nine retained effects
(FUR, MIX, SOFT, UNZAG, HOLLOW, TILE, SWEEP, SWAP and EDGE) remain visible as
future-capable previews. The full M1-M9 suite passed at 3,000 cycles/ms in
`obj/pp16-20260927-134703-61b850`. Production build: 69,500 bytes (61,860 code
bytes and 7,530 initialized-data bytes), retaining 3,676 bytes of code
headroom.

M9 single-image panel cleanup: removed the static `NO - 1 +` strip and the
`TOTAL/BYTES/ZOOM/CLEAN` information panel below the preview. PP16 has exactly
one fixed-size image, no multi-image facility, and these controls had no input
or document behavior behind them. At that M9 checkpoint, the title's dirty `*`,
working zoom buttons, pan controls and preview navigation remained. The full M1-M9 suite passed at
3,000 cycles/ms in `obj/pp16-20260927-135901-938d35`. Production build:
68,988 bytes (61,416 code bytes and 7,466 initialized-data bytes), leaving
4,120 bytes of code headroom.

## M10 start - sprite-focused clipboard layout

The nonfunctional Utilities selector and its Action-menu placeholders were
removed. Image-wide effects are a poor fit for independent sprite frames:
they cannot preserve deliberate pixel continuity across an animation. The
former toolbar slot is now a non-selecting Clipboard control that begins the
existing Paste placement operation. The right column now holds compact,
actual-size Image and Clipboard previews; the clipboard panel shows dimensions
and also begins Paste. The colour controls remain unchanged. When Select is
active, its label shows the current selection dimensions.

The M10-start full M1-M9 regression passed at 3,000 cycles/ms in
`obj/pp16-20260927-144955-427deb`. Production build: 67,718 bytes (60,837 code
bytes and 6,772 initialized-data bytes), leaving 4,699 code bytes. Transparent
paste, Paste Behind, and persistent clipboard files remain the next, separate
clipboard work; this entry does not claim them as implemented.

M10 preview follow-up: moving the Image preview to an even X coordinate left a
stale 33-byte packed-row write, which erased its right panel edge. It now copies
the exact 32-byte document row and preserves the border. A further viewport
restoration fix redraws the fixed Image frame after its temporary outline: at
1x that outline shares the panel's top, left and right edges, so restoring it
to image pixels previously erased three walls on a later zoom change. The view
harness checks all four Image and Clipboard frame edges at 1x, 4x and 8x. The
full M1-M9 regression passed at 3,000 cycles/ms in
`obj/pp16-20260927-201235-639031`. Production build: 67,478 bytes (60,604 code
bytes and 6,772 initialized-data bytes), leaving 4,932 code bytes.

## PP16 1.0 distribution checkpoint - 2026-10-23

The accepted editor, including packed-buffer Clear and Clear to Colour, is
packaged for end users in `dist/PP16V10/` and `dist/PP16V10.ZIP`. The package
includes the required toolbar atlas, a DOS batch installer, user manual,
quick help, installation instructions, credit/runtime notices and checksums.
See [the distribution record](../dist/README.md) for source provenance and
validation. The production EXE and atlas match the full passing regression
from `obj/pp16-20261022-231640-28f570`; isolated installer checks and installed
editor Save/Open passed in `obj/dist-1.0-20261023-5aa6eba2`.

Version 1.1 is the next development line for gradient/dither paint. Neither
that feature nor a memory-model migration is part of the 1.0 distribution.

## PP16 1.1 Medium compatibility checkpoint - 2026-10-23

Before adding gradient/dither paint, an isolated `-WmMedium` build of the
existing editor was added. FPC 3.2.2 Medium runtime units were built from the
matching release sources; exit hooks use model-dependent `CodePointer`.
Build/check/run scripts accept `-MemoryModel Medium`; Small remains the
default and the frozen 1.0 distribution is unchanged.

The Medium production build contains 67,804 linked code bytes in multiple
segments, 4,456 initialized-data bytes and a 7,662-byte initial near heap.
Focused clipboard/ellipse/file checks passed in
`obj/pp16-medium-20261023-023323-85e779`; the full regression, production
Save/Open and exact DOS memory restoration passed at 3,000 cycles/ms in
`obj/pp16-medium-20261023-023447-68d547`. All nine full-regression framebuffer
dumps match the Small baseline. Rebuilding Small produces the exact 1.0
executable bytes. See [the trial record](MEDIUM-MODEL.md) for setup and results.
Physical HX and interactive acceptance remain outstanding. Gradient painting
is not implemented by this checkpoint.
