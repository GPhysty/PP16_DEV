# M9 - selection, Cut, Copy and Paste

The first toolbar control is now **Select**. Dragging on the canvas creates an
inclusive, document-aligned rectangle. Its yellow border is an overlay only:
it never changes image pixels, dirtiness or undo history.

The current session has a fixed 2,048-byte conventional-memory clipboard. It
stores up to a 64 by 64 selection high-nibble-first, with width, height and
validity metadata. It survives New and Open but is not part of a `.P16` file.

- **Ctrl+C** or **Edit > Copy** copies the selection without changing the
  document or replacing its undo action.
- **Ctrl+X** or **Edit > Cut** copies first, then replaces selected pixels with
  the current background color as one undoable action.
- **Ctrl+V** or **Edit > Paste** enters placement mode. Drag on the canvas to
  choose the clipboard's top-left corner; the candidate is canvas-only until
  release. Opaque paste clips at the 64 by 64 document edge and is one
  undoable action. Escape cancels a pending paste without changing pixels or
  replacing the prior undo action.

Edit menu availability reflects the selection, clipboard and undo states.
Right-click remains the universal foreground-color sampler.

## Validation

`check-pp16.ps1 -ClipOnly -Cycles 3000` runs the M9 harness through the actual
pointer and keyboard dispatch. It checks inclusive selection geometry,
odd-width high-nibble-first packing, Copy neutrality, background-color Cut,
undo, clipped opaque Paste, canvas-only placement preview and Escape
cancellation.

The focused run passed at 3,000 cycles/ms in
`obj/pp16-20260925-204512-8daf42`. The full M1-M9 regression passed at 3,000
cycles/ms in `obj/pp16-20260925-204531-d411e5`, including missing-mouse and
wrong-video profiles, native-file recovery, independent file verification and
exact DOS memory-chain comparisons.
