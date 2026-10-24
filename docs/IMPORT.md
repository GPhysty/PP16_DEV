# PP16 1.1 indexed image import

The importer runs inside the Medium-model DOS editor. Choose **File > Import**
and select or type a DOS 8.3 filename in the current directory. An omitted
extension means `.PCX`. Prepare image dimensions and reduce to at most 256
source colors externally; no resize or crop operation is included.

The normal `run-pp16.ps1` launcher mounts `out/medium` as the DOS working
directory. Place copies of images and their palettes there before launching
the editor. The import dialog lists files in that directory; it does not
navigate host folders such as `assets`.

## Accepted inputs

- PCX: version 5, one plane and PCX RLE encoding. Packed 4-bit files use two
  pixels per byte, high nibble first, and the 16-entry RGB palette in the header.
  Eight-bit files use the trailing 256-entry RGB palette. Both support images
  with fewer used colors. GIMP may export 4-bit PCX when its palette has at most
  16 entries, even if indexed conversion was set to a maximum of 256 colors.
  Other versions, 1/2-bit storage, planar 16-color and true-color layouts are
  rejected with separate version, depth, plane or compression messages.
  Padded scanlines and RLE runs are bounded in decoded bytes; odd-width packed
  images ignore the unused low nibble of their last pixel byte. Neither layout
  permits extra data after its pixel stream and expected palette.
- PIXELplus 256 PUT: the 7-byte BLOAD wrapper followed by integer-aligned
  image records. Descriptors store width in bits and height in pixels. Files
  may contain up to 1,000 images and 65,536 payload bytes. The complete record
  structure is checked; only the selected image is converted. The original
  BLOAD segment/address fields are not used as memory destinations.
- Selected images must be 1..64 pixels in each dimension. Larger selected
  images are rejected. A small image is placed at the top left; every pixel
  outside it is black. An oversized unselected PUT record can be skipped.

## PUT image and palette selection

Choosing PUT opens its settings in the same dialog. Click `<` or `>` to choose
an image. Tab moves between palette name, image selector, OK and Cancel.
Up/Down changes the image; Page Up/Down moves ten. When the image selector has
focus, Left/Right and Home/End also navigate. The selected dimensions are shown.

The palette field initially contains `BASENAME.APF`. It is searched in this order:

1. Current directory.
2. `PALETTES` beneath the current directory.
3. Sibling `..\PALETTES`, for a current directory such as PP256's `IMAGES`.

Type a different `.APF` or `.PAL` DOS 8.3 name to supply a palette. The same
directory search applies to an explicit name. A missing associated palette
stays an error until a valid palette is selected; `STANDARD.PAL` is never
assumed. The file must contain exactly 256 four-byte entries: red, green,
blue VGA DAC channels in 0..63, then zero. Channels are rounded to 0..255
using `(channel * 255 + 31) div 63`, so DAC 63 becomes 255 and 42 becomes 170.
PCX palettes already contain 0..255 channels and use no DAC expansion.

## Result, Save and Undo

Conversion displays `CONVERTING... ESC TO CANCEL`. Escape is polled during
decoding and after each converted row. This is a synchronous operation;
completion time depends on image contents and CPU speed.

The reader validates, converts into the existing packed file staging buffer,
and closes the input successfully before committing any document change.
Cancellation or failure preserves document pixels, dirty state, filename,
previous undo, clipboard and active paint/tool settings. There is no discard
prompt because a successful import has its own undo snapshot.

A successful import is an unnamed, unsaved image, including when the incoming
pixels equal the current image. Save therefore opens the native filename
dialog; `.PCX`, `.PUT`, `.APF` and `.PAL` are not valid native save targets.
Source and palette files are opened read-only. Ctrl+Z restores the previous
pixels and dirty flag; the imported document remains unnamed. Clipboard pixels,
gradient endpoints, percentage, foreground/background, tool and brush size are
retained. Successful import resets the view and clears the selection marquee.

## Conversion and memory design

`TCONVERT` implements the selected fixed-point serpentine Floyd-Steinberg
variant: a 12-bit sRGB-to-linear lookup, Q4 signed 32-bit diffusion errors,
3:6:1 weighted linear RGB distance and stable target-index tie ordering.
Corrected values are clamped before quantization and residual calculation.
Exactly neutral source colors use only the four neutral Tandy entries. Exact
Tandy RGB colors retain their literal index, including brown #AA5500, while
their residual continues to propagate. The active painting gradient is not
consulted or rebuilt. Output remains ordinary P16-compatible packed indexes.

The 2,612-byte converter state is local to the import call and uses the
existing 8 KiB stack. It contains the source palette, shared flags, two
66-column RGB error rows and counters. The 608-byte lookup/target tables
remain static. The reader has a 256-byte input cache and 64-byte source /
32-byte packed row buffers; it does not allocate a full source image. Output
reuses `TFILES`' existing 2,048-byte stage. `TDOC.DocImport` makes one bulk
undo snapshot and commits the final packed buffer.

Bounded shifts/additions and a named-parameter 8086 IMUL square helper avoid
the bundled FPC 3.2.2 checked signed LongInt multiply defect. The compiler
and installed RTL are unchanged; range and overflow checks remain enabled.

## Validation

Run from PP16_DEV:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./build-pp16.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./check-pp16.ps1 -ImportOnly -Cycles 3000
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./check-pp16.ps1 -Cycles 3000
python config/make_import_lut.py --check
git diff --check
```

`tests/importfixtures.py` provides independent indexed decoders and a
full-image scalar FS oracle, distinct from the DOS two-row implementation.
The suite checks 22 golden conversions: five packed 4-bit PCXs (including odd
widths, RLE pairs, palette permutation and padded rows), all four supplied bird PCXs, a
Tandy identity image, generated gradients, a palette permutation, equivalent
PCX/PUT content, grayscale/channel ramps, small/odd images, wide padded rows, and actual BOUNCE/GLOBE1
PUT records. It also checks malformed headers, RLE, descriptors, alignment,
palettes, dimensions, missing files, record selection, cancellation, previous
undo, active-action rejection, native Save and source/release hashes.
The UI harness checks File dispatch, modal behavior, palette editing, image
selection, Save, undo and active paint/clipboard preservation. Stack watermarks
must leave at least 1 KiB untouched; DOS memory chains must restore exactly.

The implementation checkpoint and final run evidence are recorded in
[MILESTONES.md](MILESTONES.md). Emulator results are separate from visual
acceptance and physical Tandy 1000HX verification. The frozen 1.0 package
remains unchanged.

### 2026-10-23 checkpoint

Focused import checks passed in `obj/pp16-medium-20261023-141749-78ecee`.
The final Medium build and full 3000-cycle regression passed in
`obj/pp16-medium-20261023-142217-bfda07`, including the expanded 17-case scalar
comparison, 323 importer assertions, five sibling-palette assertions, UI
checks, 838,210 gradient assertions, native/clipboard files, production
Save/Open, and exact DOS arena restoration. Import heap availability was
unchanged before/after the file checks. The LUT generator check and final
`git diff --check` passed. Framebuffer renders of the imported bird and PUT
dialog passed their border/palette/layout checks; user visual review is separate.

| Production measurement | Before importer | With importer |
| --- | ---: | ---: |
| Linked code | 70,882 bytes | 82,653 bytes |
| Initialized data | 4,564 bytes | 6,358 bytes |
| DGROUP including reserved 8 KiB stack | 58,896 bytes | 61,344 bytes |
| Recorded startup near heap | 6,650 bytes | 4,198 bytes |
| EXE size | 81,926 bytes | 96,536 bytes |

The largest logical unit remains `TUI_TEXT`, 23,526 bytes. The converter unit
is 4,515 code bytes. Stack watermarks in the importer checks left 3,588 bytes
untouched for file paths and 3,396 bytes for UI paths (estimated high-water
usage 4,602 / 4,794 bytes in the RTL's 8,190-byte usable stack). These are
observed margins for the tested paths, not a mathematical bound for arbitrary
future callers. A first static-state version hit the gradient harness's data
limit; the caller-owned stack state avoids that permanent allocation.

Integrated import observations below include file reading, decoding, palette
preparation, conversion, closing and bulk commit. Each is one observation in
the full regression, not a repeated timing benchmark. BIOS ticks are about
54.925 ms; differences of one tick are below useful precision.

| Input | Size / selection | Ticks | Approximate seconds |
| --- | --- | ---: | ---: |
| BIRDN.PCX | 64x64 | 125 | 6.87 |
| Other three bird PCXs | 64x64 | 126 each | 6.92 |
| Exact Tandy identity PCX | 64x64 | 74 | 4.06 |
| Generated PCX / equivalent PUT | 64x64 | 124 / 123 | 6.81 / 6.76 |
| Gray / channel ramps | 64x64 | 94 / 119 | 5.16 / 6.54 |
| BOUNCE.PUT | Image 8, 64x64 | 86 | 4.72 |
| GLOBE1.PUT | Image 25, 43x39 | 46 | 2.53 |

These DOSBox-X timings do not establish speed on a physical HX or at the
interactive configuration's different fixed-cycle setting. Production SHA-256:
`92fc6e6dfa2fd3ee15723c222b3e5af8fa81b9278018979f7a1b165a4e3a86c0`.

## Format and algorithm references

- [ZSoft PCX technical reference](https://techheap.packetizer.com/compression/graphics/pcxfmt.html),
  revision 5: indexed header, row RLE, even stride and trailing palette.
- Local `references/pp256/PP256.DOC` and `USERSUBS.BAS`, especially
  `InitImageData`, `MakeImageIndex` and `InitPaletteData`: PUT alignment,
  palette layout and associated palette locations, checked against samples.
- [Floyd-Steinberg lecture reference](https://research.cs.wisc.edu/graphics/Courses/559-s2004/docs/floyd-steinberg.pdf)
  and [W3C sRGB definition](https://www.w3.org/TR/css-color-4/#predefined-sRGB).
  The conversion code is an independent implementation; no external dithering
  implementation was copied. PP256 artwork remains reference/test input.
