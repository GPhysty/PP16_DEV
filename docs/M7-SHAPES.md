# M7 - basic shape tools

Circle, Square and Line are active outline tools. Select one of the three
bottom-row icons, then press and drag inside the document canvas with the left
mouse button. The foreground color is captured at press time, so palette
changes cannot affect a held gesture.

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

While the button is held, PP16 draws a live outline directly over the canvas.
Moving the pointer first restores the original canvas and grid, then draws the
new candidate outline. This overlay does not touch the document or the 1:1
image preview; those update only on release. Escape removes the overlay.

`check-pp16.ps1` runs the focused `PPTDRAW` harness and verifies the canvas-only
live preview and its Escape cleanup, line endpoints, square outline/interior,
circle cardinal radius pixels, undo, cancellation and right-drag sampling,
alongside the prior drawing and UI-capture checks.
The focused harnesses use distinct build-unit directories and DOS 8.3 executable
names, which avoids the 16-bit small-model code-segment limit without changing
the production executable.
