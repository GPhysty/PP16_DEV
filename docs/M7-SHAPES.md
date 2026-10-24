# M7 - basic shape tools

Circle, Square and Line are active drawing tools. Select one of the three
bottom-row icons, then press and drag inside the document canvas with the left
mouse button. The foreground color is captured at press time, so palette
changes cannot affect a held gesture.

Right-click the Circle or Square toolbar button to toggle that tool between
outline and filled mode. Right-click also selects it; left-click selects it
without changing its mode. The tool label reads `FILLED CIRCLE` or
`FILLED SQUARE` while enabled. Modes are independent and last for the session.
Filled shapes use the primary paint for their border and the solid secondary
color for their interior. Dithered primary paint and 1..5-pixel border sizes
are supported. Both colors, size and mode are captured when dragging begins.
Fill covers existing artwork, including when the secondary color is black.
Very small shapes may be entirely border, with no interior left to fill.

- Line connects the press and release document pixels using the existing
  integer Bresenham renderer.
- Square treats the press point as its first corner and uses the longer drag
  dimension for both axes. It reduces the side when necessary to stay in the
  64 by 64 document.
- Circle treats the press point as its centre. The larger drag component is the
  radius, so a diagonal drag still produces a circle on the square-pixel grid.

Shapes are committed only at release. Escape before release cancels the pending
shape, preserves document pixels and retains the previous undo action. A shape
that changes pixels is one one-level undo action, exactly like a brush stroke;
right-drag continues to sample a document color for every tool.

The shared size selector supports 1..5-pixel square stamps. Shape outlines use
the selected size, frozen when the drag begins. Even sizes extend one extra
pixel down and right of each raster point. In v1.1, the positioning guide is
always one screen pixel wide; thickness and paint appear on release.

While the button is held, PP16 draws an alternating light/dark-gray guide
directly over the canvas, without brush stamps or dither lookup. Moving into a
different document pixel restores the old guide's artwork and grid, then draws
the new guide. The square shares the committed renderer's constrained endpoint;
the circle uses the same centre and radius. This overlay does not touch the
document or the 1:1 image preview; those update only on release. Release and
Escape both restore the guide before finishing the gesture, including when
the final paint changes no document pixels.

`check-pp16.ps1` runs the focused `PPTDRAW` harness and verifies the canvas-only
live preview and its Escape cleanup, line endpoints, square outline/interior,
circle cardinal radius pixels, undo, cancellation and right-drag sampling,
alongside the prior drawing and UI-capture checks.
Filled-shape checks cover toggles, sizes, clipping, color capture, black fill,
cancel and undo. `tests/filledshapecheck.py` independently floods the exterior
of each saved outline and checks every pixel of its matching filled shape.
The focused harnesses use distinct build-unit directories and DOS 8.3 executable
names, which avoids the 16-bit small-model code-segment limit without changing
the production executable.
