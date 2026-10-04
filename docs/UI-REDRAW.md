# Interface redraw checkpoint

The M5 source snapshot is retained in `obj/m5-before-ui-20260919-222734`,
and `out/M5.EXE` preserves its executable. This checkpoint changes rendering,
not the editor's document or undo semantics.

## Changes

- Menus and dialogs capture their underlying rectangle in a 12,288-byte packed
  buffer and restore it on close. Only one popup is active. Switching first
  restores the previous popup. Utility dismissal also restores the footer and
  updates its selected-effect caption. Full redraw remains the fallback if a
  future popup is too large for the buffer.
- Capture/restore copies whole packed scanline byte ranges using the existing
  bank-offset table. Odd horizontal edges include the adjacent nibble; background
  editing is blocked while the popup owns input, and the cursor is hidden first.
  A small 8086 `REP MOVSB` routine takes explicit source/destination segments and
  preserves DS, ES, SI, DI, CX, AX and flags (including the direction flag).
  Checked Pascal byte copies remain selectable with `PP16_BYTE_COPY` for reference.
  The small-model `Move` routine takes near references and must not be used for
  video copies; an initial candidate failed verification because of this mistake.
  Document/undo copies remain within near data and still use `Move` correctly.
- Tool selection changes the old/new button borders and caption without decoding
  all eight icons. Color selection updates affected boxes and swatches.
- Pan/zoom restores the old preview outline from document pixels and draws its
  replacement. It does not rebuild the complete preview. Unchanged/clamped views
  skip the view redraw. Full redraw invalidates all these caches.
- Live circle, square and line previews restore only their prior outline cells
  before drawing the replacement; they do not rebuild the 128 by 128 canvas for
  each mouse movement. Escape restores that temporary outline from document
  pixels.
- A full redraw of the 64 by 64 actual-size image preview packs each document
  row into the preview's 33 odd-aligned video bytes. This replaces 4,096
  individual pixel writes with 64 row writes; incremental preview updates are
  unchanged.
- Undo and canceled gestures mark every document row dirty. The change painter
  recognizes that complete-image case and uses the packed canvas and preview
  scanline renderers, rather than treating the restore as 4,096 incremental
  cell updates.
- At 1x zoom, full canvas construction likewise packs each visible document
  row directly into its odd-aligned canvas buffer. Higher zoom levels retain
  their scale/grid-aware renderer.

`/PERF` measures ten repeatable interaction cases using BIOS ticks. File I/O,
initialization and full-reference redraws are outside the measured intervals.
Each case writes an incremental frame and a full-redraw reference. The host
checker compares all 32,000 bytes, and can compare pre/post-optimization frames.
Run `check-pp16.ps1 -PerfOnly -Cycles 750`; then use `tests/uiperfcheck.py`
with the new run directory and the baseline run directory for the comparison.
The checker refuses a timing comparison between different cycle settings;
pixel comparisons still apply. Coarse BIOS-tick measurements are emulator
throughput results, not measured HX/V20 timings.

## Measured results

Both timing runs used the same 750-cycle Tandy profile. Baseline:
`obj/pp16-20260919-225938-2d3996`; optimized:
`obj/pp16-20260920-070601-8f56bc`. Each tick is approximately 55 ms.

| Interaction | Before, ticks | After, ticks | Approximate speedup |
| --- | ---: | ---: | ---: |
| File open/close twice | 302 | 42 | 7.2x |
| Switch six menus, close | 876 | 94 | 9.3x |
| Choose utility | 151 | 18 | 8.4x |
| Help open/close | 278 | 16 | 17.4x |
| Cancel dirty Exit, including focus changes | 310 | 48 | 6.5x |
| Change/swap colors | 18 | 4 | 4.5x |
| Select four tools | 32 | 6 | 5.3x |
| Zoom/pan sequence | 281 | 198 | 1.4x |
| Open File only | 20 | 20 | 1.0x |
| Open dirty Exit prompt | 147 | 16 | 9.2x |

All ten optimized 32,000-byte frames match both their full-redraw references
and the pre-change build exactly. They also match the checked Pascal-copy build
(`obj/pp16-20260920-045829-252881`, 3,000 cycles), which passed the full M1-M5
suite in `obj/pp16-20260920-050042-e856a4`. Timing comparisons are only made
between matching cycle settings. The Pascal-copy executable is retained at
`obj/UIBYTE.EXE`.

The optimized EXE is 68,154 bytes (56,806 code and 11,239 initialized data bytes),
with the existing 8,192-byte stack and 24,618 bytes of initial near heap on /PERF.
The popup buffer consumes 12 KB of ordinary program data, not another hardware
video page. Pan/zoom still redraws the main canvas; its improvement is smaller
than menu dismissal because most of that work remains necessary in this renderer.

The final assembly-backed build passed all M1-M5 checks at 3,000 cycles/ms in
`obj/pp16-20260920-071334-d5f031`, including cursor restoration, absent-driver
handling, wrong-video refusal and exact DOS memory-chain restoration. All seven
M1-M5 regression frame dumps also match the original M5 build exactly. The
[test report](UI-PERF-TESTS.txt) records the results, and the
[dialog frame](screenshots/UI-confirm.png) was rendered from DOS video memory
and visually inspected. Physical HX/DOS 3.3 and hands-on acceptance remain pending.

## Video pages and memory

The HX can use up to 128 KB of its system RAM for video. GRAFIX 2.60's PageCopy
documentation describes four 32 KB pages in 320x200x16, with separate active
(CPU drawing) and display selections. Its SetActivePage/SetDisplayPage source
shows how these fields share port 3DF. Tandy's hardware register documentation
also describes those separate fields. Sources: `references/pp256/GRAF260/GRAFIX.DOC`
(PageCopy and memory protection), its `SOURCE/GRAFIX.ASM`, and the
[Tandy service manual](https://ftp.oldskool.org/pub/drivers/Tandy/1000/Tandy_1000_Service_Manual.pdf).

64 KB for two pages or 128 KB for four is a viable future reservation on the
640 KB configuration, provided DOS has not allocated the required physical
range. The current guard protects only physical 98000..9FFFF (32 KB).
For this layout, two top pages span 90000..9FFFF and all four span 80000..9FFFF.
The DOS ownership checks must cover the entire chosen range before using it;
changing a page register does not reserve memory. Additional pages do not have
to fit inside the Pascal near heap. Near-heap headroom is not total free RAM.

Page flipping can present a completed frame without showing the redraw in
progress. It still needs rendering plus a strategy for keeping unchanged areas
and cursor backgrounds consistent between pages. Reducing work benefits either
single-page drawing or a later flipping implementation. This checkpoint keeps
one hardware page and does not change the memory guard or BIOS reservation.
