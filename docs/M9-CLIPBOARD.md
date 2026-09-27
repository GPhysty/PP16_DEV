# M9 - selection, Cut, Copy and Paste

The first toolbar control is now **Select**. Dragging on the canvas creates an
inclusive, document-aligned rectangle. Its alternating dark/light-grey border is an overlay only:
it never changes image pixels, dirtiness or undo history.

The current session has a fixed 2,048-byte conventional-memory clipboard. It
stores up to a 64 by 64 selection high-nibble-first, with width, height and
validity metadata. It survives New and Open but is not part of a `.P16` file.

- **Ctrl+C** or **Edit > Copy** copies the selection without changing the
  document or replacing its undo action.
- **Ctrl+X** or **Edit > Cut** copies first, then replaces selected pixels with
  the current background color as one undoable action.
- **Ctrl+V** or **Edit > Paste** enters floating placement mode with the
  outline initially centered in the visible canvas. Move it with the mouse or
  arrow keys; left-click or Enter commits. The outline is the only repeated
  render work: moving it restores the old border and draws the new one without
  redrawing the canvas or clipboard image. Opaque paste clips at the 64 by 64
  document edge and is one undoable action. Escape cancels without changing
  pixels or replacing the prior undo action.

Edit menu availability reflects the selection, clipboard and undo states.
Right-click remains the universal foreground-color sampler.

## Current implementation note

The clipboard remains a fixed 2,048-byte packed buffer. Copy now takes a
packed-row path when both the selection origin and width are even: each source
row is moved directly from the packed document into the clipboard. Odd-aligned
or odd-width selections retain the pixel-accurate fallback, so selection and
paste semantics are unchanged. Cut and Paste continue to use the normal
document mutation path to preserve one-level undo and dirty-row tracking.

## Validation

`check-pp16.ps1 -ClipOnly -Cycles 3000` runs the M9 harness through the actual
pointer and keyboard dispatch. It checks Copy neutrality, Cut and undo,
floating paste movement by arrow and mouse, click placement, and Escape
cancellation.

The focused run passed at 3,000 cycles/ms in
`obj/pp16-20260926-091226-732e8a`. The full M1-M9 regression passed at 3,000
cycles/ms in `obj/pp16-20260926-091250-98e9ee`, including missing-mouse and
wrong-video profiles, native-file recovery, independent file verification and
exact DOS memory-chain comparisons.

The optimized M9 full suite also passed at 3,000 cycles/ms in
`obj/pp16-20260927-125542-e24c91`.
