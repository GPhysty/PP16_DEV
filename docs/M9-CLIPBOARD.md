# M9 - selection, Cut, Copy and Paste

The first toolbar control is now **Select**. Dragging on the canvas creates an
inclusive, document-aligned rectangle; holding **Ctrl** while dragging constrains
it to a square. Its alternating dark/light-grey, one-screen-pixel border is an
overlay only: it never changes image pixels, dirtiness or undo history.

Right-clicking **Select** toggles the button to an ellipse selector. Its drag
box defines the oval; holding **Ctrl** constrains that box to a square and the
oval to a circle. Pressing or releasing Ctrl while the pointer is stationary
updates the active marquee immediately. The ellipse uses the same stippled grey
marquee as the rectangular selector. Ellipse Copy, Cut and Paste affect only
pixels whose centers are inside the oval; included palette-zero pixels remain
opaque black rather than acting as transparency.

The current session has a fixed 2,048-byte conventional-memory clipboard. It
stores up to a 64 by 64 selection high-nibble-first, with width, height and
validity metadata. It survives New and `.P16` Open but is not part of a `.P16` file.
Use the existing **Save As** dialog with a name such as `SPRITE.CLP` to save it.
The existing **Open** dialog lists `.CLP` alongside `.P16`; opening a clip
replaces the clipboard and preserves the open image, undo, unsaved edits and
view. Paste, mirror, rotate and scale then work normally. Rectangle/ellipse
shape and opaque black pixels survive the file round trip. Empty clips cannot
be saved. Both formats retain verified writes and recoverable overwritten files.

- **Ctrl+C** or **Edit > Copy** copies the selection without changing the
  document or replacing its undo action.
- **Ctrl+X** or **Edit > Cut** copies first, then replaces selected pixels with
  the current background color as one undoable action.
- The **Cut toolbar button** performs the same action without changing the
  currently selected drawing tool.
- **Ctrl+V** or **Edit > Paste** enters floating placement mode with the
  outline initially centered in the visible canvas. Move it with the mouse or
  arrow keys; left-click or Enter commits. The outline is the only repeated
  render work: moving it restores the old border and draws the new one without
  redrawing the canvas or clipboard image. Opaque paste clips at the 64 by 64
  document edge and is one undoable action. Escape cancels without changing
  pixels or replacing the prior undo action.
- **Edit > Paste Behind** is a persistent checked toggle. When enabled, a
  clipboard pixel is written only where the destination currently matches the
  selected background color. This lets any of PP16's 16 colors serve as the
  canvas "behind" color; source black remains an ordinary opaque color.
- The three buttons at the right side of the Clipboard panel are always visible.
  They mirror the session clipboard left/right, rotate it 90° clockwise, or
  scale the clipboard itself; clicks do nothing until a clipboard image exists.
  Mirror, rotation and scaling redraw the preview immediately and never change
  the document, selection or undo history.
- On **Scale**, left-click adds one pixel to both clipboard dimensions and
  right-click subtracts one pixel from both dimensions. Each dimension is
  clamped independently to the 1 through 64 pixel range. Scaling uses centered
  nearest-neighbor sampling and preserves the ellipse mask. Narrow ellipses map
  to the nearest source row containing interior pixels, preventing black holes
  where the resized oval gains a new top or bottom pixel.

Edit menu availability reflects the selection, clipboard and undo states.
Right-click remains the universal foreground-color sampler.

## Current implementation note

The clipboard remains a fixed 2,048-byte packed buffer with a second 2,048-byte
transform scratch buffer. A clipboard-shape Boolean and the existing dimensions
are sufficient for an axis-aligned ellipse: mirror preserves its shape and
clockwise rotation swaps its width and height. Scale samples the packed source
directly, so it needs no third buffer or per-pixel mask.

One shared pixel-center ellipse calculation supplies the included left/right
bounds of each row. The selection marquee, Copy, Cut, Paste and floating Paste
outline all use those bounds. Excluded preview corners are cleared for display,
but paste inclusion comes from geometry rather than color, preserving opaque
black pixels. Copy retains the packed-row fast path for aligned source rectangles;
ellipse rows clear only their excluded edge pixels afterward.

Mirror and rotate share one transform traversal. Scale uses that existing
scratch buffer to replace the clipboard with a centered nearest-neighbor copy;
it does not enter a canvas mode or touch selection state.

## Validation

`check-pp16.ps1 -ClipOnly -Cycles 3000` runs the M9 UI/dispatch harness,
the standalone real-mode ellipse/scale harness and CLP file tests. M9 checks Ctrl-constrained
selection, Copy neutrality, floating paste, cancellation, clipboard grow/shrink,
extension-based save/open over an edited image, view preservation,
and pasting/undoing a loaded clip. CLP file tests exercise separate-process
round trips, malformed files, read-only input, failed writes/renames, and
independent host-generated files and byte comparisons.
The separate geometry harness performs 39,244 checks over tiny, rectangular
and 64-pixel ellipses, mirror/rotation, nearest-neighbor scaling, clipping,
undo, opaque black pixels, and switching back to rectangular clipboard semantics.

The focused suite passed in `obj/pp16-20261002-221719-bc9c9e`. The complete
M1-M9 regression passed in `obj/pp16-20261002-221828-3a80ca`, including mouse,
missing-mouse and wrong-video profiles, drawing/undo/UI response, native-file
recovery, independent file verification, production startup, and exact DOS
memory-chain comparisons.

The subsequent shared P16/CLP build passed the full suite in
`obj/pp16-20261002-230918-993318`; see [compaction measurements](CLP-COMPACTION.md).

The clipboard-only one-pixel Scale revision passed its focused UI, geometry and
CLP suite in `obj/pp16-20261003-083819-cf9f73`.
The final revision, including direct rectangular palette-color scaling checks,
passed all 39,244 geometry checks and the complete M1-M9 suite in
`obj/pp16-20261003-084037-7a38dc`.
Removing the redundant Clipboard-panel `CLICK: PASTE` label passed the focused
suite in `obj/pp16-20261003-085054-42f2fb`.
The subsequent menu-only shortcut cleanup passed the complete M1-M9 suite in
`obj/pp16-20261003-093101-3377ec`.
