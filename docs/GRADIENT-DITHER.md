# PP16 1.1 gradient/dither paint

Status: implemented on `v1.1`; the user approved the rendered layout.
The existing 1.0 installation package remains the stable release. This
development build uses the Medium memory model and ordinary conventional RAM.

## Use the selector

The shorter 4x4 palette leaves room for a permanent selector at the bottom
left. Click the left endpoint box, then left-click its palette colour; repeat
with the right endpoint. The selected box is outlined yellow while awaiting
a colour. Escape cancels that assignment.

Click the ramp between the boxes to select 0%, 10%, ... 100% of the **right**
endpoint colour. A marker shows the selected step. The existing foreground
swatch displays the active pattern and percentage. Assigning an endpoint also
activates gradient paint using the retained percentage.

Brush, Line, Circle, Square, Bucket Fill and Clear to Colour all use the mix.
Brush sizes 1-5 use the same image-anchored pattern. Shape tools show a thin
dashed gray positioning guide; their pattern and thickness appear on release. An
ordinary left palette click or canvas eyedropper selects solid paint again,
while retaining both endpoints and the step. Right palette clicks set the
solid background. Tab (or clicking the background swatch) swaps solid colours;
from gradient paint it selects the background as solid foreground, retaining
the background. The previous foreground colour is not saved separately.

Clear and Alt+C still clear to black. Cut uses the solid background; Paste
and clipboard transformations preserve literal pixels. P16 and CLP files
save those pixels with their existing formats. Gradient control settings are
session state, not extra image metadata or hardware palette entries.

## Pattern and memory

`TPaint` combines an ordered 2x2 pattern with a dispersed 5x5 rank permutation.
The resulting 10x10 tile contains every threshold rank from 0 to 99 once.
Each selected 10% step therefore changes exactly ten pixels per complete tile
to the right endpoint. At image edges or inside small strokes, a partial
tile's local coverage can differ. Equal endpoints and 0%/100% remain solid.

The active pattern caches ten packed 32-byte rows, plus a 64-byte row-index
lookup. Pixel resolution uses the lookup and nibble extraction without division
in the painting loop. `DocSetPixel` stays literal; paint paths resolve the
gradient token. Positioning guides do not. This preserves the phase of pasted art.
The UI ramp uses the same rank pattern for each of its eleven selectable steps.

Bucket Fill uses a 512-byte visited bitmap, because some painted pixels can
retain their original colour. Its existing bounded packed coordinate stack
is retained. Clear to Colour compares and copies packed rows, snapshots once,
and uses full-image scanline redraw. The solid `FillChar` path remains intact;
an identical clear preserves the clean/dirty state and the previous undo.

| Measurement | Pre-gradient Medium | Gradient build |
| --- | ---: | ---: |
| Linked code bytes | 67,804 | 70,882 |
| Initialized data bytes | 4,456 | 4,564 |
| Data group including 8 KiB stack | 57,872 | 58,896 |
| Startup near heap bytes | 7,662 | 6,650 |
| EXE bytes | 78,378 | 81,926 |

The data group grew by 1,024 bytes; 896 bytes are the row cache, index lookup
and fill bitmap. The remaining change includes state, constants and alignment.
The largest logical code section is `TUI_TEXT`, 23,506 bytes. Medium removes
the shared code ceiling; individual segments and near data remain bounded.
The development EXE SHA-256 is
`17ddc88bcedec8ac9dda434f1bed668c4ae6e96172110a331ff625c5583ecaaa`.

## Build and validation

Prepare the matching FPC 3.2.2 runtime as described in
[MEDIUM-MODEL.md](MEDIUM-MODEL.md). The build, check and launch scripts now
default to Medium and use `out/medium/`. Current source requires Medium;
the Small configuration is retained for the earlier release history.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build-pp16.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\check-pp16.ps1 -GradientOnly -Cycles 3000
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\check-pp16.ps1 -Cycles 3000
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run-pp16.ps1
```

The focused run passed in `obj/pp16-medium-20261023-035655-c12485` with
838,208 assertions: all 256 endpoint pairs and eleven ratios, exact coverage,
tiling, packed-row agreement, control hit regions and swatches, solid/gradient
selection, clear/undo/no-op, full-document fill from unchanged seeds, barriers,
all paint tools and brush sizes, preview/commit agreement with zoom/pan/grid,
overlapping/clipped strokes, cancellation, and literal clipboard/file pixels.
The independent host check verifies native headers, exact 30% tile coverage,
full-image repetition, odd-width clipboard padding and copied source phase.

The final complete regression passed at 3,000 cycles/ms in
`obj/pp16-medium-20261023-041244-43a210`, including 838,210 gradient assertions,
existing video/mouse, view, drawing, undo, clipboard/ellipse, dialogs and
native/clipboard file recovery, unsupported video, missing mouse, production
Save/Open sessions and exact DOS memory-chain restoration. The 16-point
solid-stroke case measured two BIOS ticks in this run (one in the initial
full run); these short measurements have coarse tick resolution.

An initial UI performance run exposed unnecessary ramp rebuilding on ordinary
colour changes. The selector now redraws only when gradient parameters,
endpoint assignment, activation or a full UI redraw require it. This preserves
the permanent selector without adding its drawing cost to every solid pick.
The final UI performance run passed at 750 cycles/ms in
`obj/pp16-medium-20261023-040947-9c16f5`: all ten incremental frames equal full
redraws byte for byte. Colour change/swap returned from 15 ticks to 2 ticks;
all ten final UI timings are within one tick of the pre-gradient Medium run
`obj/pp16-medium-20261023-023754-2e1a03`. BIOS ticks are about 55 ms and these
are coarse emulator measurements, not physical HX timing.

`GRADUI.BIN` and `GRADUI.PNG` in the focused run are the raw framebuffer and
its rendered preview used for layout review. The test harness does not start
the mouse driver, so its footer reports NO MOUSE; this is not a production
mouse failure. Physical HX/DOS 3.3 validation remains outstanding.
