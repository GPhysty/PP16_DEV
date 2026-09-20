# M8 - bucket fill and clipboard design

## Bucket Fill

The Bucket Fill toolbar tool performs a four-connected flood fill on a left
click in the canvas. It replaces only pixels with the clicked pixel's original
color, using the foreground color. A color border, diagonal-only contact, or a
different region stops the fill. Right-click remains the universal color sampler.

The operation is immediate and atomic for the fixed 64 by 64 document: the
document changes only after the click is accepted, and the normal dirty-span
repaint updates the canvas and 1:1 preview. A fill that changes pixels is one
undo action. Filling with the existing color changes nothing and preserves the
previous undo action.

The implementation marks a pixel when it is queued, so it cannot be queued
twice. Its explicit coordinate stack packs each 12-bit 64 by 64 coordinate in
1.5 bytes, requiring at most 6,144 bytes and no EMS/XMS. This bounds an
all-canvas fill without recursion or a dependence on the DOS stack.

## Selection and clipboard contract (design only)

M8 does **not** activate Cut, Copy or Paste. It establishes the contract for a
later dedicated implementation milestone:

- A selection is an inclusive document-aligned rectangle, stored as `X`, `Y`,
  `Width`, and `Height`; valid sizes are 1 through 64 pixels. Its border is a
  UI overlay and never becomes an image pixel.
- Clipboard pixels are packed high-nibble-first at two pixels per byte. A
  fixed 2,048-byte conventional-memory buffer holds any selection up to the
  full 64 by 64 canvas, with width, height and validity metadata. It lasts for
  the current PP16 session and survives New/Open, but is never saved in `.P16`.
- Copy only replaces the clipboard; it does not dirty the document or consume
  undo. Cut copies first, then clears the selected pixels to the background
  color as one undoable document action.
- Paste begins at the chosen document top-left pixel and clips at the 64 by 64
  document edge. Its candidate rectangle should use the same non-destructive
  canvas overlay approach as M7 shapes. Release commits one undoable action;
  Escape cancels it without changing pixels or replacing the prior undo.
- The initial Paste mode is opaque: all clipboard pixels replace destination
  pixels. Transparency and Paste Behind remain explicitly deferred rather than
  inheriting ambiguous menu labels.

Adding this buffer requires no EMS/XMS, but the later implementation must
re-measure near-heap headroom with the production build and keep the 8086
small-model code segment within its 64 KB limit.

## Validation

The focused M8 check exercises a color barrier, a full 4,096-pixel fill and
undo through the actual pointer dispatch. The M1-M8 suite passed at 3,000
cycles/ms in `obj/pp16-20260920-165632-5fa365`, including native-file recovery,
missing-mouse/wrong-video profiles, independent file verification and exact DOS
memory-chain comparisons. The production launch reported 9,950 bytes of initial
near heap after the fill stack was added; the eventual clipboard implementation
must measure again after adding its own 2,048-byte buffer.
