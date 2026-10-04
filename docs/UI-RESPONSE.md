# Canvas and pointer responsiveness

This follows the first [interface redraw checkpoint](UI-REDRAW.md). The user
reported slow grid redraws, pointer and coordinate flicker, and one-pixel panning
that took too many actions. The previous executable and sources are preserved in
`obj/before-canvas-20260920-075537`.

## Rendering

The canvas is assembled in an 8,320-byte conventional-memory buffer. Each packed
row includes the odd-aligned canvas and its two border nibbles. Repeated rows of
a zoomed document row are copied in RAM; completed rows replace video memory
without first clearing the canvas. Grid lines are part of the prepared pixels.
The pointer remains visible during canvas preparation, then hides for the copy
and related view updates. Unchanged or clamped views still skip redraw.

The existing explicit-segment 8086 copy routine now also transfers canvas and
cursor rows. Horizontal solid spans use `REP STOSB`, retaining clipped nibble
edges. Checked Pascal copies and fills remain available via `PP16_BYTE_COPY`.
This is a software canvas buffer, not a hardware page flip. The existing single
32 KB video reservation is unchanged; no EMS/XMS is needed.

The software pointer saves, composes and restores packed rows. An unchanged
position needs no redraw. Ordinary motion leaves it visible while independent
coordinate fields update. A coordinate update hides it only if its saved
background overlaps that readout. Other UI changes retain cursor protection.

Coordinates occupy fixed-width fields. Only changed characters are replaced,
with foreground and background pixels written together. Labels and unchanged
digits no longer disappear and reappear on every move.

This reduces visible redraw and cursor disappearance time. It does not promise
tear-free presentation: screen writes still reach the currently displayed page.
The user accepted the smoother emulator behavior on September 20. Physical HX
review remains pending; their screenshot uses a customized CRT shader/profile.

## Navigation

- Arrow keys move one document pixel; Shift+arrows move half a visible view.
- Click/drag in the actual-size preview to center the view at that point.
  Dragging beyond it clamps to the document edges. Release includes the final
  pointer position. Escape ends the gesture and consumes the held button until
  release; it leaves the view at its current position.
- Half-view steps are 16 document pixels at 4x and eight at 8x. At 1x/2x the
  entire 64x64 image already fits, so there is no further pan range.
- View navigation does not change document pixels, dirty state or undo history.

## Verification

`check-pp16.ps1` includes all previous milestones and `/RESP`. The canvas is
checked pixel by pixel against document data and grid rules at 1x/2x/4x/8x,
both pan extremes, and grid on/off, including unused gray space. Cursor checks
cover clipped and overlapping moves and negative top/left positions. Span
checks compare the assembly fill against independent per-pixel drawing.

`/RESP` measures 20 cursor-and-coordinate moves, then checks fine/coarse pan,
preview dragging, edge clamps, final release, Escape, unchanged document state,
and numeric transitions 9 -> 10 -> 9 -> outside. It compares coordinate pixels
to independent transparent-text redraws, including a pointer over the readout.
Its final `RESPONSE.BIN` is rendered as [this preview](screenshots/UI-response.png),
which is a DOS framebuffer rendering, not an emulator-window capture.

Run `check-pp16.ps1 -ResponseOnly -Cycles 750` for the focused check;
`-PerfOnly -Cycles 750` measures the ten existing UI scenarios and verifies their
incremental frames against full redraws. BIOS ticks are coarse emulator
measurements (about 55 ms), not a calibration of V20 clock speed.

Full M1-M5 plus response checks passed at 3,000 cycles in
`obj/pp16-20260920-080946-85b650`. All seven regression frames match the preceding
checkpoint. At 750 cycles, `obj/pp16-20260920-081202-7233c3` reduced the zoom/pan
sequence from 198 to 33 ticks (6x); all ten frames match full redraws and the
previous executable. Initial near heap is 15,754 bytes; the EXE is 74,640 bytes,
including 62,741 code bytes, with the existing 8 KB stack. Further features need
careful attention to the small-model code-segment limit.
