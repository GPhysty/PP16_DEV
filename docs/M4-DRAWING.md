# M4 - drawing, erasing and sampling

Read the PP256.HLP sections for Paintbrush, Pixel Pointer, Airbrush, Eraser,
Colour Sampler, Brush Size Selector, Selected Colour Boxes and Palette Grid.
This was a targeted reference audit, not a claim to have read the entire help.

The reference Paintbrush draws continuous freehand strokes; its Pixel Pointer
can leave gaps on quick drags. PP16 joins sampled document points with an
integer Bresenham line, so fast brush/eraser drags remain continuous. The
right mouse button samples document color regardless of the selected tool,
matching the help. Sampling reads document pixels, never grid/cursor pixels.

Brush and eraser are opaque square stamps. The size selector directly below the
tool icons has decrement/increment buttons and supports sizes 1..5; it is
available for Brush, Eraser, Circle, Square and Line. A stamp is centred on the
pointer pixel (even sizes extend one extra pixel down and right), clips at the
document edge, and is frozen at press time with the color. The eraser writes
the selected background color. Original sizes 6..8, alternate brush shapes,
strength, and the original normal/color/undo eraser setup dialog remain
deferred. Palette left/right clicks retain PP16's established foreground/
background roles; Tab or clicking the background box swaps their values. This
differs from the original's movable Current Colour priority.

## Input ownership

- A new press must begin on a document pixel to start a drawing/sampling gesture.
- Brush and eraser freeze their color at press time. Additional button presses
  during a gesture cannot start another gesture or activate UI controls.
- A simultaneous two-button initial press is ignored until both are released.
- Each gesture includes its final release position. Leaving the canvas breaks
  the line; returning while held begins a new segment without connecting across
  the gap. It never paints the tool panels or hidden areas during that gap.
- A press originating on a palette, tool or menu cannot turn into a drawing
  stroke. Dismissal clicks are consumed. Remaining held buttons must be released
  before starting another gesture.
- View changes are ignored during a stroke. Escape ends it and waits for
  release; already painted pixels remain. Rollback and undo belong to M5.

## Storage and repaint

TDOC still owns a separate 2048-byte packed 64x64 image. Checked writes preserve
the neighbor nibble, reject out-of-bounds positions, and mask color to 0..15.
The changed flag is set only when a pixel actually changes. There is one
minimum/maximum changed span per document row (256 bytes total).

The UI repaints changed spans in the zoomed canvas and 1:1 preview. A diagonal
stroke therefore need not repaint its whole bounding rectangle. Cursor
background is restored before painting and saved again afterward. Grid lines
and the preview viewport indicator are UI overlays and never enter the image.
Idle polling causes no repaint; same-color writes create no dirty span.

## Verification

`check-pp16.ps1` now also invokes `PP16 /DRAWTEST`. It checks packed nibbles,
all sixteen selected colors, full document edges, diagonal interpolation,
background-color erasing, sampling without image changes, every zoom's corners,
canvas departure/re-entry, UI capture, menu dismissal, simultaneous buttons,
and held-button suppression after a gesture ends. It checks actual canvas and
preview readback plus one-cell repaint and zero additional idle/same-color
repaint. Existing M1/M2/M3 checks remain in the runner.

The final fixture records a 16-point stroke and reports BIOS ticks and changed
cells repainted. Timing is a coarse emulator measurement, not HX calibration.
The host frame check compares a newly painted pixel in both canvas and preview.

Saving, undo, new/clear, fill, shapes, selections and applied special effects
remain later milestones. The screen explicitly says NO SAVE YET and marks
edited data UNSAVED. The passing M3 executable is retained as `out/M3.EXE`.
Next is hands-on M4 review, then M5 undo/cancellation and M6 native save/open.
Physical HX and actual DOS3.3 checks remain pending; EMS/XMS stay optional.

## Measured checkpoint

All M1/M2/M3/M4 automated checks passed in the 8086 Tandy profile at 3,000
cycles/ms, with range and overflow checks enabled. The 16-point test stroke
repainted 46 document cells and measured 1 BIOS tick (coarse resolution).
Executable size: 58,338 bytes; compiler code: 48,558 bytes; initialized data:
9,680 bytes. Stack: 8,192 bytes. Initial near heap: 42,606 bytes in /DRAWTEST.
Only the 2048-byte document and 256-byte changed-row tracking are added here;
no full-screen backbuffer or undo buffer is allocated. See M4-TESTS.txt and
[the rendered drawing frame](screenshots/M4-drawing.png). Interactive launch
uses the user-selected 750-cycle setting. Performance on the physical HX still
needs hands-on verification; the faster automated run does not establish it.
