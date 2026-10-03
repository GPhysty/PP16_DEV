# Shared file I/O and clipboard persistence - 2026-10-02

The existing File menu and dialogs handle both extensions. Save As `NAME.CLP`
serializes the clipboard; Open `NAME.CLP` replaces only the clipboard. `.P16`
still means the 64x64 document, and remains the default extension. See
[the format specification](P16-FORMAT.md) for the native CLP header.

Measured production builds with the unchanged `-O1 -Os` small-model settings:

| Checkpoint | Code bytes | Free below 65,536 |
| --- | ---: | ---: |
| Prior scale build | 64,541 | 995 |
| Shared read/verify path and CompareByte loops | 64,250 | 1,286 |
| Shared P16/CLP workflow | 64,902 | 634 |

Compaction saved 291 code bytes; the complete feature then added 652, for a
net increase of 361 bytes. Final EXE size is 69,122 bytes and initialized data
is 4,112 bytes. Those figures do not include BSS or the 8 KB stack.

No range/overflow checks were disabled and no file-recovery steps were removed.
Read and verification now share a 2 KB stack buffer, with header and pixel
comparisons using CompareByte. A clip's width, height and ellipse flag are
encoded in the existing header layout with a distinct CLP signature.

The clipboard UI tests use a focused launcher instead of the older multi-mode
test launcher, preserving the selection/paste/scale assertions and adding CLP
dialog assertions. File tests remain in a separate small-model executable.
This keeps test scaffolding out of the production segment and allows the
production checks to remain enabled.

The complete regression suite passed at 3,000 cycles/ms in
`obj/pp16-20261002-230918-993318`: drawing, undo, mouse/video, UI response,
file dialogs, production Save/Open sessions, P16/CLP corruption and recovery,
38,963 ellipse/scale checks, independent file-byte verification, and exact DOS
memory-chain restoration. Physical HX acceptance remains a separate check.
