# Staged PP16 implementation prompt for Codex in VS Code

I want you to build **PP16**, a **new** mouse-capable DOS sprite and bitmap editor for my **Tandy 1000 HX**, using **Free Pascal with compatible Turbo Pascal-era programming style and selected 8086 assembly drawing routines**. Recreate PIXELplus 256's useful editing functions and workflow in **16-color Tandy mode**. Design PP16's implementation for the HX from the outset, using PIXELplus 256 as the behavior reference and GRAF260 as a source of drawing routines to adapt.

This is an intentional new application, with its own architecture, UI implementation, and native document format. Functional similarity is the goal. Exact visual duplication, binary compatibility, and preservation of the original program's internal design or quirks are not requirements. Adapt individual source routines where useful, and make any selected legacy-file compatibility an explicit feature.

The first goal is a small, usable editor: choose one of 16 colors, draw and erase pixels with the mouse, zoom/pan, undo, save, reopen, and export usable sprite data. Basic bitmap editing follows within the core-editor phase. Animation, advanced filters, gradient tools, and a screen designer come later.

Work in small, measurable milestones. Each milestone must end with something I can run or inspect and a clear acceptance result. Do not attempt the whole application in one pass.

## 1. The environment is already configured and tested

**Do not redo environment setup.** Do not reinstall Free Pascal, DOSBox, VS Code extensions, assemblers, or other tools. Do not rerun general environment discovery or propose a replacement toolchain. Read the existing project settings only as needed to use them. Compilation and targeted tests for your actual changes are expected; reinstalling or re-proving the toolchain is not.

The inspected workspace is `E:\Projects\PP16_DEV`. Read its current `AGENTS.md`, README, and build/run/check entry points before editing. If this prompt is used in a relocated copy, use that current workspace and locate the same reference files by name.

The current project records:

- FPC 3.2.2 i8086 cross-compiler; 16-bit DOS MZ executables.
- `-Tmsdos`, `-Cp8086`, and `-WmSmall` in `hx8086.cfg`.
- Existing `build.ps1`, `run.ps1`, `check.ps1`, `.vscode` tasks, `out`, and `obj`.
- HX with NEC V20, 640 KB conventional RAM, PicoMEM disks, and DOS 3.3. Keep the baseline executable 8086-compatible; do not require V20-specific instructions.
- Emulator profile: Tandy video, 8086, no FPU, no EMS/XMS/UMB. Its fixed cycle count is not a measured hardware performance model.
- The current DOSBox run changes the reported DOS version to 3.30; it does not boot the real Microsoft DOS 3.3 kernel.
- A documented checked signed-LongInt multiplication problem in the existing runtime. Do not restart that investigation unless new work requires it; use suitable checked unsigned arithmetic for nonnegative dimensions and file sizes, and test overflow boundaries.

Preserve HXTEST and its established checks. Add a distinct PP16 target using the existing tools and output conventions; do not overwrite the smoke test or silently change its success criteria. Keep DOS-facing filenames within 8.3. Follow the project rule of moving cleanup items into dated `trash` folders, rather than permanently deleting them.

## 2. Inspect and observe the references before designing

The reference locations in this workspace are:

```text
references\pp256\PP.EXE
references\pp256\SD.EXE
references\pp256\PP256.DOC
references\pp256\PP256.HLP
references\pp256\USERSUBS.BAS
references\pp256\IMAGES\
references\pp256\CLIPS\
references\pp256\PALETTES\
references\pp256\SCREENS\
references\pp256\GRADS\
references\pp256\GRAF260\GRAFIX.DOC
references\pp256\GRAF260\PASCAL\GRAFIX.PAS
references\pp256\GRAF260\PASCAL\GRAFPAS.ASM
references\pp256\GRAF260\SOURCE\GRAFIX.ASM
references\pp256\GRAF260\PASCAL\
references\pp256\GRAF260\BASIC\
```

These extracted files have already been compared with the original archives and match. Inspect targeted files rather than repeatedly inventorying everything. Preserve original references and assets; work on copies when execution may create settings or alter images.

**You can run PP.EXE in DOSBox through the existing VS Code/DOSBox capability. Use that to see the actual application.** Use a separate VGA-capable reference launch/profile for PP256; retain the established Tandy configuration for PP16. This is a reference-app run using installed tools, not an environment-setup task. Do not expect PP256 to run in the Tandy-only profile.

Capture useful screenshots if the existing tools permit, and record the observed display resolution rather than assuming it. Inspect the initial editor, a loaded small sprite, zoom/grid behavior, color selection, mouse drawing, menu/file interaction, and undo. A few representative captures are enough. Briefly inspect the animation tester to understand future workflow, without implementing it. If SD.EXE can be observed cheaply, record its relationship to the editor for later work. Store observations and screenshots in the project's documentation area. If interactive viewing or screenshot capture is unavailable, state the exact limitation and continue from the supplied help; do not claim to have seen an unobserved screen.

Use observed behavior to decide what fits a 320×200 Tandy screen. Preserve useful workflow, not necessarily every original panel or exact screen position.

## 3. Facts established by archive inspection

### PIXELplus 256

PP256 means **PIXELplus 256**, by Chris Chadwick. The archive contains 83 files: three executables, documentation/help, one BASIC source file, image/clipboard/palette/gradient resources, and a screen-design example. It does **not** contain the editor, filter, or GUI source. Treat this as a new implementation inspired by its documented and observed behavior, with selective translation of the supplied support routines. Do not promise a line-by-line port of missing source.

`PP.EXE` is the image editor plus animation tester; `SD.EXE` is a separate screen designer. `USERSUBS.BAS` is QBASIC/QuickBASIC/Visual BASIC for DOS support code, not the editor. Its most useful routines are:

- `InitImageData`, `MakeImageIndex`, `GetWidth`, `GetDepth`: image decoding and indexing.
- `InitPaletteData`: palette decoding.
- `InitDesignData`, `DisplayDesign`: later scene loading and display actions.
- `CharPrint`, `CharPrintXY`, `GraphicText`: bitmap-font layout ideas.
- `RotatePalette`, `FadePalette`, `Scroller`, `WizzText`: later behavioral references.

The BASIC routines explicitly omit error checking. Rewrite loading and bounds checks. Do not port the VGA DAC writes or floating-point fades directly to Tandy.

`PP256.HLP` is readable text with formatting/link markers. It describes a menu bar, status bar, left tool/palette panel, central zoomable Edit Grid, and image display/selector panel. It documents left/right click, drag, double-click, keyboard shortcuts, panning, and both image-relative and grid-relative coordinates. It does not reveal the original event-loop implementation. Its original STORE/undo workflow differs from per-stroke undo; PP16 should initially use one clearly documented undo transaction per completed action.

### Established legacy file formats

- `.PUT` and `.DEM`: seven-byte BASIC BLOAD header, then consecutive image records. Header fields are `FDh`, saved segment, saved offset, payload length; words are little-endian. Each image has word `width*8`, word `height`, then `width*height` one-byte palette indices. Round the complete image record up to an even byte count. No count field precedes the records.
- `.CLP`: the same representation, containing one image. There are 22 supplied clipboard files including root `CLIPBRD.CLP`.
- All 37 supplied `.PUT`/`.DEM`/`.CLP` files parsed to exact EOF under that rule. Examples: TILE1 is 16×16; SMILEY is 19×17; RUNNER has four 32×32 frames; BOUNCE has eight 64×64 frames; each GLOBE has 25 frames of 43×39; CHARSET1 has 96 8×8 glyphs.
- `.PAL`/`.APF`: 1,024 bytes, 256 little-endian long integers encoding `R + 256*G + 65536*B`, with VGA component values 0–63. `.APF` associates with the same-base-name image. Do not read these as 768-byte palettes.
- `.DES`: BLOAD header and eight-byte records: four 16-bit integers for image number, X, Y, action. Action low byte: 1=PSET, 2=PRESET, 3=OR, 4=XOR, 5=AND. `GAMEOVER.DES` contains one initial zero record plus 276 placement records. The original BASIC loader/renderer has an extra-iteration indexing trap; implement explicit file bounds instead.
- `.IMG` screen snapshots and BASIC DATA exports are documented. No `.IMG` sample is supplied.
- Gradient files have 10,000-byte payloads after BLOAD headers; their full semantics are deferred. The two `.DAT` resource schemas are also not fully established.

Treat old saved segment/offset fields as metadata, never as permission to write to an arbitrary memory address. Do not confuse the original VGA formats with PP16's native format or with GRAF260 GET/PUT records.

### GRAF260

GRAF260 is **GRAFIX 2.60**, by Joseph A. Albrecht. It includes the engine's assembly source, Pascal interfaces, BASIC interfaces, paired demos, and binary samples.

The original architecture is a TSR: GRAFIX.COM handles INT 10h requests with `AH=EEh` and AL=function number. `GRAFPAS.OBJ` is a Turbo Pascal/QuickPASCAL wrapper, not the engine. Its old far procedures and VAR-pointer layout are not automatically compatible with the installed FPC small-model ABI.

Useful functionality includes point/readback, lines, boxes and fills, circles/ellipses, clipping, image capture/blits, logical operations, graphics text, palette mapping, and video-page helpers. It also has sound and timer features that are out of scope initially. The supplied cursor functions are graphics/text cursor support, not a mouse library.

`MediumGraphics` selects 320×200×16, BIOS mode 09h. `HighGraphics` and TANDY11 provide SL/TL 640×200×16 and must not become HX requirements. `SOURCE\GRAFIX.ASM` provides the mode-9 mapping:

```text
video segment: B800h, with correct Tandy page setup
offset = (y AND 3)*8192 + (y DIV 4)*160 + (x DIV 2)
even x uses high nibble; odd x uses low nibble
```

GRAF GET/PUT records start with pixel width and height, followed by packed 4-bit rows of `ceil(width/2)` bytes. Unlike PP256, width is not multiplied by eight. Some `.BIN` samples contain additional stored bytes; validate their specific use rather than infer an exact file-size rule from minimum pixel storage.

GRAF operation numbers differ from `.DES`: 1=PRESET, 2=PSET, 3=AND, 4=OR, 5=XOR. Translate through named operations, never pass legacy integers blindly between APIs.

Keep the authors' notices with adapted material and record provenance in a credits file. Preserve the distinct distribution notices in PP256.DOC and GRAFIX.DOC.

## 4. Target and architecture constraints

Use Tandy 320×200×16 and 8086-compatible integer code. No VGA/EGA requirement, 386 instructions, protected mode, DPMI, 8087, EMS/XMS, or modern GUI framework. Use procedural Pascal units, explicit records and arrays, short strings, and small well-defined interfaces. Turbo Pascal-era style is desired; literal Turbo Pascal compilation is not a second mandatory target. Isolate any necessary FPC-specific pointer or compiler features.

Use the 16 hardware colors initially with an identity palette mapping. A Tandy palette register can select from the hardware color set; it cannot reproduce arbitrary VGA RGB edits. Defer palette cycling and remapping that would also recolor the UI. Document the pixel-aspect choice; keep document coordinates exact, and treat any preview correction separately.

### Drawing backend

Prefer a small application-owned backend adapting selected GRAF260 algorithms. Start with mode setup/restore, pixel/readback, horizontal spans, filled rectangles, clipped packed-image blits, and simple bitmap text. Do not transplant the entire TSR into the application or implement two complete backends.

If using the resident driver is materially simpler for the first working increment, document that temporary choice, required launch order, and a minimal FPC-safe wrapper. Do not assume the old `.OBJ` links correctly merely because it exists. Keep the public drawing API independent of that choice so selected routines can move into the application later.

**Video-memory ownership is part of the renderer milestone.** The HX uses system RAM for graphics. Mode 9 needs a properly reserved 32-KiB video area, although visible pixel data is 32,000 bytes. Establish how the existing runtime/launch configuration protects that area before writing to it. Setting mode 9 or writing B800h alone is not evidence that DOS allocations cannot overlap video memory. Do not casually patch the BIOS memory-size word after allocations already exist. Start with one reserved hardware page; defer page flipping and ADJMEM-style system changes. If a launch-time reservation helper is needed, make it a narrow, documented graphics requirement using the existing tools, with clear ownership and checks.

Port one ASM routine at a time. Verify actual FPC parameter passing, near/far addresses, symbol naming, register preservation, stack balance, segment-register handling, and direction-flag expectations. Use 8086 instructions only. GRAF's interrupt entry initializes engine state/segments and its boundary-fill routine uses a private stack; those assumptions do not automatically survive extraction. Retain a simple Pascal reference implementation for meaningful comparison of optimized pixel/span/blit routines.

### Document storage and memory

Separate document pixels from hardware video memory. Begin with one 64×64 sprite, stored as packed row-major 4-bit pixels, high nibble first, with `stride=(width+1) DIV 2`. Define unused low-nibble padding for odd widths. Wrap storage behind pixel/span operations so tools do not depend on segment layout.

Budget code, near data, stack, heap, document, undo, clipboard, UI assets, file buffers, mouse driver, and reserved video RAM. Report actual executable and available-memory figures where measurable. A 64×64 image is 2,048 bytes; 320×200 is 32,000 bytes. A full image plus a full undo image must not be casually placed in the small model's near-data area. Keep code-size limits in the budget too. Before expanding to full bitmaps, choose a verified far-buffer/segmented-storage or bounded-undo approach. If measured limits require a memory-model change, explain the specific requirement and preserve the working target; do not silently replace the established model.

Use widened, checked arithmetic for sizes before allocating or multiplying dimensions. Reject impossible dimensions, partial reads, truncated files, invalid indices, and allocations that exceed the documented budget. DOS file I/O must report errors without losing the current document. Do not use recursion for flood fill; use a bounded scanline/seed structure with explicit exhaustion handling.

### Input, UI, and editor state

Use a small polling event loop: collect mouse and keyboard state, derive button/key transitions, dispatch the active tool or UI command, update the document, repaint dirty regions, and draw the cursor. Keep polling responsive during idle and dragging. Long operations must have bounded work or an abort path when practical.

Use a DOS mouse driver through INT 33h and BIOS/DOS-era keyboard handling. Detect an absent driver safely and leave a usable exit path. Verify the driver's actual coordinate range and normalize it exactly once: do not blindly assume a 0–319 X range or always divide X by two. Some driver/mode combinations expose a wider logical range. Test all screen edges and document coordinates at each zoom.

Use a software cursor with background restoration if the driver cannot draw correctly in mode 9; choose only one visible cursor implementation. Hide/restore it around updates, and never let it modify document pixels. Define click, drag, release, cancellation, capture outside the canvas, and keyboard focus explicitly. A palette click or dialog dismissal must never leak into a drawing stroke.

Build a compact 320×200 UI with readable labels/icons, a 16-color selector, foreground/background indication, zoomable canvas, small actual-size preview, and status coordinates. Menus or simple dialogs are sufficient. Do not spend the first milestone building a general widget toolkit. Redraw changed rectangles; do not repaint all 64,000 screen pixels every idle loop.

Suggested boundaries, adjusted to existing project conventions: video/backend, mouse/keyboard input, document/storage, view mapping, tools, UI, native file I/O, later legacy import. Keep DOS filenames short. Define inclusive/exclusive rectangle conventions once and translate explicitly when calling GRAF-derived routines.

### Native save and export

Give PP16 its own versioned format, for example `.P16`, with a magic value, explicit little-endian fields, dimensions, flags, payload length, and the packed pixel representation. Specify fields and limits before coding; write fields explicitly rather than dumping compiler-dependent records. Initially use one image per file and a fixed palette. Reserve extensibility without prematurely implementing frames, layers, or compression.

Save through a checked temporary file and preserve the previous good file until the replacement succeeds; handle DOS rename/write failures. Failed loads leave the current image intact. Export a documented packed sprite and/or Pascal data include with a tiny independent DOS display example. A native file is not automatically compatible with either BASIC PUT or GRAF ExtPut.

## 5. Milestones and acceptance gates

Implement one milestone at a time. Split any milestone further if it cannot produce a small reviewable increment. Keep the previous passing executable available. Do not start optional feature phases before the core editor passes its acceptance gate.

| Milestone | Deliverable | Measurable acceptance |
|---|---|---|
| **M0 — Reference audit and design note** | Read the targeted source/help, run PP256 in the existing VGA DOSBox capability, capture useful screens where available, and record backend, memory, and UI decisions. | Distinguish observed behavior, source evidence, and unknowns; identify original editor source as absent; record exact build/run commands to reuse; list the next small change. No installation work. |
| **M1 — Tandy rendering foundation** | A minimal PP16 executable showing all 16 colors, corner markers, pixels, spans, a filled box, and a small text label; clean return to text mode. | Correct pixels at (0,0), (319,0), (0,199), (319,199); distinct scanlines across y=0..7 and near the bottom; even/odd nibble writes preserve their neighbor; clipped writes stay in bounds; video memory ownership is established; repeated enter/exit succeeds. No editor tools yet. |
| **M2 — Mouse and keyboard** | Pointer, coordinate display, button transitions, keyboard exit, and missing-driver handling. | Cursor reaches all corners; left/right press/drag/release work; cursor leaves no trails after redraw; absent driver causes a clear message and safe exit; Escape cancels or exits according to current state. |
| **M3 — Editor shell and view** | 16 swatches, selected colors, tool indication, canvas, actual-size preview, status bar; a fixed test image with 1×/2×/4×/8× zoom and panning as needed. | Canvas-to-document mapping is exact at edges and after pan/zoom; UI hit areas do not overlap canvas actions; test image pixels remain unchanged by navigation; labels remain legible. |
| **M4 — First usable pixel editor** | One 64×64 document; pencil, background-color erase, eyedropper, foreground/background selection, dirty flag. | Draw continuous fast drags by connecting sampled document points; draw all four document edges; use all 16 colors; erase/sample correctly; preview updates; leaving/re-entering the canvas cannot paint UI or create an unintended cross-canvas line. |
| **M5 — Undo and cancellation** | One-level undo per completed stroke/action, clear/new behavior, unsaved-change handling. | One undo restores an entire long stroke; canceled preview operations do not alter the document; clear is reversible; new/exit can preserve unsaved work; memory use stays within budget. Document whether undo toggles or consumes its snapshot. |
| **M6 — Native save/open** | New/open/save/save-as and a documented native format. | Create, save, exit, reopen and compare every pixel/dimension; test odd widths, empty/truncated/invalid files, unsupported version, failed save and overwrite handling; failed operations preserve the current document or previous file. |
| **M7 — Basic shape tools** | Line, outline/filled rectangle, bounded flood fill; each as a separate increment if needed. | Preview then commit/cancel works; all line directions and reversed rectangle corners work; fill handles same-color, edge-connected and bounded regions without recursive stack overflow; each action undoes as one transaction. |
| **M8 — Selection and clipboard** | Rectangle select, copy/cut/paste, horizontal/vertical flip; visible paste preview. | Paste clips safely on all edges; cancel preserves the document; overlap copies are correct; odd-width selections preserve neighbor pixels; each operation undoes; transparent paste, if offered, has explicit semantics distinct from color zero. |
| **M9 — Bitmap sizes and export** | Verified storage for variable sizes through 320×200, pan/zoom for images larger than the editing viewport, and documented sprite export plus a small display example. | Exercise 1×1, 19×17, 32×32, 64×64 and 320×200; validate allocation/undo limits; exact save/open round trips; separate DOS example displays exported pixels correctly; record memory headroom. Split storage, full-size editing and export into separate increments if necessary. |
| **M10 — Core-editor release gate** | Usable PP16 build, concise controls/help, file specification, credits, and reproducible checks. | Complete the end-to-end workflow below; record emulator results separately from real-HX/DOS-3.3 results; list remaining limitations without presenting unrun tests as passed. |

M4 is the first interactive drawing checkpoint. M6 is the first persisted sprite-editor checkpoint. M10 is the end of the core editor phase, not permission to start every advanced feature.

The core acceptance workflow is: launch on the Tandy profile; create and edit a sprite with mouse tools and all 16 colors; zoom/pan and sample colors; undo mistakes; copy/paste/flip a selection; save and reopen exact pixels; edit and save a larger bitmap; export a sprite and display it in the separate example; exit cleanly. Repeat the relevant checks on the physical HX when I can run the build. Continue work that does not need the machine, but keep real-hardware validation explicitly pending until actual results exist.

## 6. Later milestones, only after the core editor

1. **PP256 import:** validated `.CLP`, then single/multiple `.PUT`/`.DEM` records, then associated palettes. Convert through a deterministic 256-to-16 lookup table; nearest hardware color is an initial policy, optional dithering is separate. Never reduce indices with `AND 15` or modulo 16. Test TILE1, SMILEY, RUNNER and GLOBE fixtures. Respect masks/transparency explicitly. Stream frames when an entire source set exceeds the storage budget; do not require 1,000 resident frames.
2. **Sprite collection editing:** append, select, duplicate and delete bounded frames, with defined dimensions and save semantics. Do not add playback until frame editing/storage works.
3. **Animation tester:** bounded playback with frame selection, delay, loop and responsive stop; start with ordinary timer ticks and no timer IRQ replacement. Test timing wraparound. Optimize only after measurement.
4. **Simple transforms/effects:** color replace/remap, pixel shifts, rotate 90°, tile preview, then selected effects reconstructed from help. A 16-color adaptation must say what it preserves and what differs. Palette indices are not brightness values; do not implement BRIGHT/DARK by simply incrementing/decrementing an index.
5. **Advanced brushes/fills:** tile fill, airbrush, dithering/gradient tools, and selected edge/softening effects, one at a time with small before/after fixtures and undo. Design results around the Tandy color set, not arbitrary VGA palette ramps.
6. **Screen designer:** composition model, sprite placement, then `.DES` import with explicit display-action translation and handling of the leading record. Validate export/runtime display before adding additional composition features.

Sound, arbitrary layers, scripting, a general plugin system, additional video modes, and elaborate file browsers are not initial requirements.

## 7. Verification and how to report progress

Run the relevant existing build path after code changes. Add focused checks for pixel addressing, nibble preservation, clipping, view mapping, file round trips and malformed input, and ASM/Pascal equivalence. Host-side checks can help with file fixtures, but they do not prove 16-bit runtime or hardware correctness. Do not create a huge generic test framework before the first usable program.

Keep a short milestone ledger with the current scope, acceptance checks, results, and next step. For each checkpoint report:

- What is now usable and the files changed.
- How to build/run it through the existing tasks or scripts.
- Checks actually run and their results; screenshots when useful.
- Executable size and relevant memory/performance measurements, with emulator settings identified.
- Known issues, hardware checks still pending, and the next single milestone.

For performance, measure dirty-rectangle updates and a representative pencil drag under fixed emulator settings; use those figures to detect regressions, not to claim real HX speed. Keep idle redraws at zero unless the UI changes. Optimize measured hot drawing paths in ASM, one routine at a time, with pixel-exact comparison against the reference path.

Resolve routine coding decisions autonomously and state them briefly. Ask only about a decision that materially changes the requested behavior or an actual blocker. Do not turn every small reversible change into a permission request.

**Begin with M0. If the inspection exposes no blocker, implement M1 only, using the existing configured toolchain. Stop at that completed rendering checkpoint and report the evidence. Do not proceed to M2 or advanced features in the same pass.**
