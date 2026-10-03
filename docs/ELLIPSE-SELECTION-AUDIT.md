# Ellipse selection and code-space audit

Date: 2026-10-02

This audit records the ellipse/scale checkpoint. The subsequent
[CLP compaction checkpoint](CLP-COMPACTION.md) adds shared native clipboard
save/load; the latest production build is 64,902 code bytes with 634 bytes free.
The size tables below retain their original measurement history.

Status: implemented and compiled on 2026-10-02. The isolated variants remain in
`obj/ellipse-audit-20261002-183457` as measurement evidence; the selected
refactors and corrected ellipse behavior are now in the working source.

## Conclusion

The corrected ellipse selection fits the existing 8086 small-model build
without removing working tools or disabling range/overflow checks. Five
measured refactors recover 1,114 code bytes. The completed editor, including
accurate ellipse geometry, shape-aware clipboard operations, matching grey
stipple, stationary-Ctrl updates and overlay restoration. With Paste Behind,
menu cleanup and scaled Paste, it builds at 64,541 code bytes. That is 1,166
bytes above the pre-change 63,375-byte build and leaves 995 bytes below the
65,536-byte code-segment ceiling.

The earlier suggestion that a larger memory model was necessarily required was
premature.

## Why the previous marquee was inaccurate

1. the previous TUI.SelectionEllipsePixel implementation scales coordinates from
   a fixed radius-31 circle using integer division by 62. It does not rasterize
   the requested ellipse directly. Floor truncation biases opposite sides
   differently. Reproducing this mapping found reflection asymmetry in 3,970
   of the 4,096 width/height combinations from 1 through 64. A 5-by-5 outline is:

   ```text
   ####.
   #..##
   #..##
   ####.
   .##..
   ```

2. The callback uses PreviewShapePixel (line 1038), painting zoom-sized document
   cells in yellow. The rectangular marquee instead uses alternating gray
   screen pixels. At high zoom the ellipse is a thick shape preview, not the
   same thin marquee used by rectangular selection.

3. CopySelection and CutSelection (lines 698 and 707) still use rectangular
   clipboard operations. The oval outline does not define which pixels are
   copied, cut, or pasted: the corners of the bounding rectangle participate.
   ShowPasteOverlay (line 665) also remains rectangular.

4. RunUI (line 1309) does not treat a modifier-only change as an input change.
   Pressing or releasing Ctrl with a stationary pointer can leave the
   constraint stale until another mouse/key event occurs.

5. Some view/grid redraw paths repaint the canvas without restoring the
   selection overlay. This can hide a still-valid selection.

6. The existing ellipse test checks mode and equal dimensions, not actual
   marquee pixels or excluded clipboard corners. Passing it did not establish
   correct ellipse behavior.

## Measured code-space opportunities

All figures are linked code bytes from isolated builds with the existing
settings, not Pascal source length or EXE file length. Individual savings
are relative to the same baseline.

| Refactor | Code bytes saved | Scope and caveat |
| --- | ---: | --- |
| Replace the font glyph case statement with an indexed constant table | 323 | Preserve every supported/blank glyph; modest code/data tradeoff |
| Share mirror/rotate/flip traversal | 232 | Keep all three buttons and their distinct coordinate mappings |
| Remove unreachable menu shortcut-label branches | 214 | Branches beyond actual menu rows, not implemented shortcuts |
| Reuse RasterLine for UI lines | 208 | Removes duplicate raster logic; benchmark callback overhead |
| Share identical UI/file-dialog border drawing | 137 | One implementation instead of two |
| **All five together** | **1,114** | **Measured combined build** |

| Build | Code bytes | Remaining code space |
| --- | ---: | ---: |
| Pre-change editor | 63,375 | 2,161 |
| Five refactors, no ellipse redesign | 62,261 | 3,275 |
| Completed ellipse implementation | 63,592 | 1,944 |
| Current editor including Paste Behind, menu cleanup and scaled Paste | 64,541 | 995 |

The ellipse implementation adds 1,331 code bytes over the refactored baseline.
With Paste Behind, menu cleanup and scaled Paste, the current build is 2,280
bytes over that baseline, for a net growth of 1,166 bytes over the pre-change
editor. Its compiler-reported data figure is 4,062 bytes versus 5,112 for the
pre-change editor; these are not total runtime memory figures including BSS,
stack, and heap.

The pre-change audit baseline was concentrated in TUI (20,765 bytes) and the
linked SYSTEM runtime (19,661 bytes). Other units account for 22,949 bytes. The runtime is
not simply disposable: it includes functionality and safety support in use.

Changing O1 to O2 saved only six bytes in the measured build. Removing comments
or already-unlinked routines saves no executable code. Compacting menu-label
tables mainly targets data, not code. Removing file safety, undo, or runtime
checks is not recommended.

## Implemented design

Use one row-bound calculation to define selected pixels. For each document
row, calculate the left inset; the right edge follows by symmetry. The
implementation uses pixel-center inclusion:

```text
(2*x + 1 - width)^2 * height^2
  + (2*y + 1 - height)^2 * width^2 <= width^2 * height^2
```

Draw a one-screen-pixel stippled boundary around exactly those included
cells. Use the same row bounds for copy, cut, paste, and the paste outline.
Pixel-sized steps at high zoom are intentional: they show precisely which
document pixels belong to the selection.

Store the clipboard shape as a Boolean plus its existing width/height.
An axis-aligned ellipse remains an ellipse under mirror, flip, and quarter-turn
rotation. Rotation swaps width/height; no extra per-pixel mask or separately
transformed mask is necessary for this feature. Arbitrary freeform selections
would need a different representation.

Do not use palette index zero as a transparency key. Included black pixels
must paste as black; only geometric exclusion preserves the destination.
The implementation clears excluded thumbnail corners for presentation but uses
geometry, not color, to decide what gets pasted.

Use bounded integer squares and nonnegative DWord products. A first signed
LongInt formulation hit runtime error 215 on the target at a 5-by-64 case,
despite the mathematical values fitting 32 bits. The revised formulation
passed the real-mode proof with range/overflow checks still enabled. This
audit did not isolate the precise compiler/runtime cause of the signed
formulation's failure; it should not be generalized as a compiler defect.

## Validation and remaining work

- Host geometry checks matched an independent ellipse equation for all 4,096
  dimensions, including reflection and rotation relationships.
- The replacement font table matched every supported and blank entry.
- The focused M9 UI/clipboard suite passes in real-mode DOSBox.
- The permanent standalone ellipse/scale harness passes 38,963 real-mode
  checks. It covers 36 size combinations drawn from 1, 2, 5, 6, 9, and 64;
  mirror, rotation and scaling; per-pixel paste results including opaque black;
  cut and undo; clipped pastes; document-neutral copy; shape preservation; and
  rectangle-mode reset.
- The complete drawing, UI, undo, file, clipboard, mouse and video regression
  suite passes, including independent file verification, production startup,
  wrong-video refusal, missing-mouse handling and exact DOS memory-chain checks.
- The production build reports 64,541 code bytes and 4,062 initialized-data
  bytes. The M9 harness reports 65,464 code bytes, leaving 72 bytes, so the
  exhaustive ellipse/scale checks remain in their own 21,442-byte harness.

Stationary Ctrl transitions and overlay restoration after zoom, pan, grid,
full-UI and dirty-cell redraws are implemented. Both rectangle and ellipse
marquees go through the same alternating light/dark-grey screen-pixel painter.

Hands-on appearance and target-speed acceptance on the physical HX remain
useful final checks. The shared line callback and repeated ellipse row geometry
are performance candidates only if target measurements show a problem; a small
row-inset cache is an optional future optimization.

The audit directory is retained as measurement evidence. The release
implementation is in the normal source tree and is covered by
`tests/ELLIPSETEST.PAS`.
