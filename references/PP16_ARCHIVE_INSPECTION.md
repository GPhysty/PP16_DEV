# PP256 and GRAF260: archive inspection

Inspected September 19, 2026. This report is based on the original attachments recovered from the referenced ChatGPT conversation, not replacement downloads. The `/mnt/data/` paths belonged to that conversation; the attachments were made available locally for this inspection.

**Main finding:** PP256 is **PIXELplus 256**, by Chris Chadwick. The requested project is **a new Free Pascal editor recreating its useful functions in 16-color Tandy mode**, with selected drawing code adapted from GRAF260. PP256 serves as a behavior reference; its editor source is absent. Legacy-file import is an optional later feature. GRAF260 contains the actual drawing-engine assembly source, but its supplied Pascal object is an interface to a resident driver.

## 1. What was inspected

| Archive | Files, excluding directories | Uncompressed bytes | SHA-256 |
|---|---:|---:|---|
| `pp256.zip` | 83 | 1,424,877 | `CD547AAA02A7C64D1574C6A90B5603E5A27112B21ABA16854503A3C643567325` |
| `graf260.zip` | 66 | 664,355 | `402B3ECFDAD0554F0A94F18C279ADA3F9893246F924728FDE3FCEE05CABF05D0` |

The existing project is `E:\Projects\PP16_DEV`. Its copies of all 83 PP256 files and all 66 GRAF260 files match the corresponding recovered archive files byte for byte. GRAF260 is nested at `references\pp256\GRAF260`, rather than in a separate sibling reference folder. The project also has a `GRAFIX.err` file outside the original archives containing assembler directive warnings; it does not establish that a graphics integration works.

This was static inspection of documentation, BASIC/Pascal/ASM source, executable strings, and binary assets. I did not run the editors, build GRAF260, or test anything on the physical HX. UI descriptions below come from the supplied help. The original editor's implementation language, event-loop design, and memory layout cannot be established from the available source. The accompanying prompt incorporates the user's confirmed ability to run PP.EXE in DOSBox from VS Code: it asks the implementing agent to observe the application and capture useful screenshots with a separate VGA reference run while retaining the PP16 Tandy test profile.

## 2. PP256 structure and source availability

| Files/directories | Role and evidence |
|---|---|
| `PP.EXE` | Image editor with integrated animation tester; 301,206 bytes. |
| `SD.EXE` | Separate screen-layout designer; 131,312 bytes. The two applications can invoke each other. |
| `DEMO.EXE` | Demonstration; 72,950 bytes. An embedded string says the demo was written entirely in BASIC; this is not proof of the editor's compiler. |
| `USERSUBS.BAS` | The only `.BAS` source in this archive. QBASIC/QuickBASIC/Visual BASIC for MS-DOS support routines plus demonstration code and DATA. It is not editor, filter, or mouse source. |
| `PP256.DOC` | Overview, requirements, installation-era notes, file formats, BASIC integration, and freeware notice. |
| `PP256.HLP` | Readable text with formatting/link markers such as `C14` and `H171`, and `@` topic separators. Extensive behavioral specification. |
| `PP256IMG.DAT`, `PP256CHR.DAT` | Binary application resources. Their filenames and contents suggest image and character resources, but their full schema was not established. They are not source. |
| `IMAGES` | 11 `.PUT` files and four `.DEM` files, including sprite sequences and character sets. |
| `PALETTES` | Two `.PAL` files and three associated `.APF` palettes. |
| `CLIPS` | 21 single-image clipboard files; another `CLIPBRD.CLP` is at the root. |
| `GRADS` | 32 gradient files, `.000` through `.031`. |
| `SCREENS` | One supplied screen design, `GAMEOVER.DES`. |

No PP256 `.PAS`, `.ASM`, `.C`, or editor BASIC source is present. Do not invent source modules for its menus, tools, animation tester, or filters.

The documentation lists 18 tools: scissors, paste brush, effects brush, flood/tile/gradient fill, paintbrush, pixel pointer, airbrush, eraser, ellipse and filled/gradient ellipse, rectangle and filled/gradient rectangle, line, and curve; it also provides a color sampler. The 14 named effects are BRIGHT, DARK, TINT, FUR, MIX, SOFT, UNZAG, HOLLOW, TILE, XOR, GREY, SWEEP, SWAP, and EDGE. The help describes behavior; the implementation code is absent.

Primary archive evidence: `PP256.DOC` sections 1–5, 6, 8–9; `USERSUBS.BAS` introduction and declarations; complete archive inventory.

## 3. Image, sprite, palette, and screen formats

### PP256 `.PUT`, `.CLP`, and `.DEM`

The documentation identifies `.PUT` as BASIC BLOAD format, with a seven-byte header. `.CLP` has the same representation but one image; the `.DEM` examples are image files under a different extension.

Inspection of `InitImageData`, `MakeImageIndex`, `GetWidth`, and `GetDepth`, followed by parsing all **37** supplied files with these extensions, established:

1. Header: byte `FDh`, then three little-endian 16-bit fields: saved segment, saved offset, payload byte count. All 37 samples have offset zero and a payload count matching their file length minus seven.
2. Payload: consecutive image records, with no separate image-count field in this representation.
3. Each record starts with a little-endian word equal to **width × 8**, followed by a height word.
4. Pixels follow as width × height one-byte palette indices, using the mode-13 BASIC GET/PUT representation.
5. Each complete record occupies `round_up_even(4 + width*height)` bytes. An odd pixel count therefore adds one record padding byte; it does not imply row padding.
6. A loader must validate lengths and dimensions, and ignore the saved segment as an allocation destination. It should never write to an address supplied by a file.

All 37 samples parsed to exact end-of-file without an invalid descriptor or truncated record.

| Sample | Confirmed contents |
|---|---|
| `CLIPS\TILE1.CLP` | One 16×16 image; 267-byte file. |
| `CLIPS\SMILEY.CLP` | One 19×17 image; useful odd-size/padding fixture. |
| `IMAGES\RUNNER.PUT` | Four 32×32 frames. |
| `IMAGES\BOUNCE.PUT` | Eight 64×64 frames. |
| `IMAGES\GLOBE1.PUT`, `GLOBE2.PUT` | 25 frames each, 43×39 pixels. |
| `IMAGES\CHARSET1.PUT` | 96 characters, 8×8 each. |
| `IMAGES\CHARSET3.PUT` | 96 characters, variable widths 3–9, height 8. |
| `IMAGES\SOLDIER.DEM`, `SOLDMASK.DEM` | Eight 32×32 images each. |

Sprite frames are ordinary images in sequence. This representation does not establish frame durations, pivots, layers, or per-pixel alpha. The supplied soldier mask is separate image data; mask semantics need explicit treatment during color conversion.

Evidence: `USERSUBS.BAS` lines 874–890, 1052–1091, 1133–1166; binary sample inspection.

### Palettes and exports

`.PAL` and `.APF` samples are exactly 1,024 bytes: 256 little-endian BASIC long integers. The code decomposes each as `R + G*256 + B*65536`, with VGA components in the 0–63 range. This is not a 768-byte raw RGB palette. An `.APF` belongs to the same-base-name image file and is stored under `PALETTES`.

The documentation also describes ASCII BASIC DATA exports for images/palettes and screen designs, and BLOAD `.IMG` screen snapshots. No `.IMG` example is included. `USERSUBS.BAS` contains DATA demonstrations, rather than a separate generated-export sample file.

The gradient samples have seven-byte BLOAD headers and 10,000-byte payloads; the inspected `.000` file has saved offset four. Their use as gradient styles is documented, but their complete meaning should be investigated when gradient tools are actually scheduled. Do not treat them as ordinary `.PUT` image records.

Evidence: `PP256.DOC` section 5; `USERSUBS.BAS` lines 787–868, 1101–1123; binary inspection.

### `.DES` screen designs

The BASIC `DesignType` is four 16-bit integers: image number, X, Y, and display action. The low byte of the action selects **1=PSET, 2=PRESET, 3=OR, 4=XOR, 5=AND**. The consumer masks off the high byte; its complete meaning was not established.

`GAMEOVER.DES` has a seven-byte BLOAD header and a 2,216-byte payload: **277 eight-byte records**, consisting of an initial all-zero record and 276 subsequent placements. There is a useful indexing trap: the original file loader allocates `0..277`, loads 277 records, and the renderer loops `1..277`. A new parser should explicitly handle the leading record and real file bounds, rather than reproduce the extra iteration or rely on zero-filled memory.

Evidence: `USERSUBS.BAS` `DesignType`, `DisplayDesign` at line 743, `InitDesignData` at line 1000; `GAMEOVER.DES` bytes.

## 4. UI and input: known behavior versus unknown internals

The help describes a menu bar, status bar, left tool/palette panel, central zoomable Edit Grid, and right image display/selector panel. The grid is a view into the current image, rather than the entire document. The interface displays both grid and image coordinates, supports panning, and has five preset zoom buttons plus a maximize button. Palette/tool controls change with the selected tool.

Mouse use includes left and right click, left double-click, and dragging with either button. The documentation requires a Microsoft-compatible mouse driver. Relevant keyboard behavior includes F1 help, F4 grid, F6 tool/palette switching, F7 animation tester, F8 screen designer, F10 all images, brackets for colors, `<`/`>` for image navigation, Tab for selected-color priority, and Backspace for undo.

Original undo is unusual: drawing-tool changes can accumulate from the time the tool was selected; STORE refreshes the undo image, and repeated undo toggles versions. A new editor should explicitly choose simpler per-stroke undo for its initial version, rather than accidentally claim identical behavior.

The archive does **not** establish whether PP.EXE polls the mouse, uses callbacks, or uses a particular GUI library. It also does not establish the editor window's video mode from the BASIC example's `SCREEN 13`; that statement describes graphics used by client programs. A new event loop and UI architecture must be designed for the HX.

Evidence: `PP256.HLP` lines 297–467, 991–1025, 4218–4268, 4355–4386, 6886–6943.

## 5. BASIC routines worth adapting

| Routines | Use in the new editor |
|---|---|
| `InitImageData`, `MakeImageIndex`, `GetWidth`, `GetDepth` | Best starting points for a validated PP256 importer and image-directory model. Replace unchecked BLOAD and fixed 1,000-entry scratch assumptions. |
| `InitPaletteData`, `ChangePalette` | Decode palettes and construct a 256-to-16 lookup table. The VGA hardware-writing behavior must be replaced. |
| `InitDesignData`, `DisplayDesign` | Later scene-composition import and display-action interpretation. Keep after the core editor. |
| `CharPrint`, `CharPrintXY`, `GraphicText` | Fixed/proportional bitmap-font layout ideas. Adapt glyph drawing and clipping to 4-bit pixels. |
| `RotatePalette` | Later palette-cycle or index-remapping idea, under the fixed Tandy color set. |
| `FadePalette` | Behavioral reference only: floating-point interpolation and VGA DAC writes at 3C8h/3C9h are unsuitable as an HX implementation. |
| `Scroller`, `WizzText` | Later demos or text effects, not core editor dependencies. |

There are 16 routine definitions. The file explicitly states that the routines omit error checking. It contains no ready-made source for PP256's paint tools, filters, or UI.

## 6. GRAF260 drawing and ASM capabilities

GRAF260 is **GRAFIX 2.60**, by Joseph A. Albrecht. It contains:

- `SOURCE\GRAFIX.ASM`: 124,787 bytes of the resident graphics/sound engine.
- `PASCAL\GRAFIX.PAS`: Turbo Pascal/QuickPASCAL interface source, including Pascal convenience routines.
- `PASCAL\GRAFPAS.ASM` and `.OBJ`: old Pascal calling wrappers. The unit links the object with `{$L GRAFPAS.OBJ}`.
- BASIC interfaces for QuickBASIC, Turbo BASIC, and PowerBASIC; QuickBASIC ASM/object/library files.
- 17 `.PAS` demos and 17 corresponding `.BAS` demos, plus eight `.BIN` assets.
- `SOURCE\TANDY11.ASM`, `ADJMEM.ASM`, and `DEMO.ASM`, with associated `.COM` executables.

**Architecture:** GRAFIX.COM hooks INT 10h. Calls use `AH=EEh` and a function number in AL. GRAFPAS.ASM exports far Pascal procedures that fill registers and invoke that interrupt. The small wrapper object is not the drawing engine. `MediumGraphics` checks the resident signature and selects 320×200×16; `HighGraphics` requires TANDY11 and is for SL/TL 640×200×16, not the HX.

Capabilities include pixels/readback, lines, relative drawing, rectangles/fills, ellipses/circles with aspect ratio, boundary fill, viewport clipping, image capture/blitting, PSET/PRESET/AND/OR/XOR operations, graphics text and text cursor, palette mapping, active/display pages, page copying, animation helpers, sound/noise, and timer-rate changes. No mouse API appears in the supplied interface/source inventory; graphics cursor functions are not a mouse subsystem.

**Most useful adaptation targets:** `Set320`/`Make320`, `PointC`/`GetPoint`, `FillBoxC`, clipping helpers, image GET/PUT routines, and text drawing. Keep sound, TSR installation, timer hooks, and extra video pages out of the first editor implementation.

The source establishes mode-9 addressing through B800h with:

```text
offset = (y AND 3)*8192 + (y DIV 4)*160 + (x DIV 2)
even x: high nibble; odd x: low nibble
```

The 32,000 bytes of visible pixels occupy an interleaved 32-KiB video allocation. A contiguous packed document buffer is therefore not already a hardware screen buffer. GRAFIX's installer normally protects 32 KiB on this class of machine; its memory-reservation logic is significant because video uses system RAM. Advertising four possible graphics pages does not mean four pages have been reserved.

GRAF260 GET records also differ from PP256: their first two words are **pixel width and height**, followed by packed nibbles with `ceil(width/2)` bytes per row. Its `.BIN` samples include extra stored bytes beyond minimum pixel payload; do not assume every file is precisely one minimally sized record. More importantly, GRAF action numbers are **1=PRESET, 2=PSET, 3=AND, 4=OR, 5=XOR**—different from PP256 `.DES` numbers. Explicit mapping is required.

The Pascal ABI must be adapted: old wrappers use far procedures and four-byte VAR addresses, while the configured FPC small model cannot be assumed to match those declarations. Preserve segment registers, stack balance, direction flag expectations, and 8086 instruction compatibility. The original boundary fill changes SP to an internal paint stack; it should not be transplanted blindly into a Pascal application's stack model. Original `BLoad` uses seven-byte file records and has no destination-size parameter; replace it with a checked byte reader.

Evidence: `GRAFIX.DOC` chapters 1–4 and final notes; `PASCAL\GRAFIX.PAS` interface and lines 261–272, 458–478; `GRAFPAS.ASM`; `SOURCE\GRAFIX.ASM` lines 341–368, 580–643, 1862–1902, 2434–2509, 3701–3732, 3837–3868, 3898–3935, and installation code from line 4569.

## 7. Consequences for the staged implementation

The existing project already documents FPC 3.2.2 i8086 real-mode DOS, `-Cp8086`, small memory model, no FPU, and a Tandy emulator profile. Its README identifies the actual target as an HX with V20, 640 KB, PicoMEM disks, and DOS 3.3. These are project-recorded facts, not hardware observations from this inspection. Keep baseline code 8086-compatible.

Do not redo compiler installation or environment tests. Read and reuse the existing build/run/check scripts. Their current entry point is HXTEST, so an editor target can be added without losing that established smoke test.

A single 64×64 packed image needs 2,048 bytes and makes a manageable first editor document. A 320×200 packed image needs 32,000 bytes; adding a full undo copy leaves little room in a 64-KiB near-data segment. Require an explicit storage/memory budget before full-screen documents and multiple frames. Free Pascal documents a distinct far-pointer facility for segmented targets, but actual types and calling conventions must be checked against the installed compiler and model. [Free Pascal FarPointer documentation](https://www.freepascal.org/docs-html/rtl/system/farpointer.html).

Start with a mouse-controlled 16-color sprite editor that draws, zooms, undoes, and saves/reopens. Then add bitmap-sized documents and a usable export. Schedule PP256 import, animation, effects, gradient styles, and screen design as later milestones. Tandy palette remapping chooses among its hardware colors; it does not provide VGA's arbitrary RGB DAC editing.

Preserve source attribution: PP256.DOC says the package became freeware in 1997, retains copyright, requests credit, and conditions redistribution on no charge for package content. GRAFIX.DOC describes its source as public domain while asking that the author's name and copyright remain included in modified versions. Record those notices verbatim in project provenance; do not assume identical terms for the two packages.
