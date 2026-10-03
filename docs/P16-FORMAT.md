# Native P16 version 1

One image, fixed identity Tandy palette, row-major packed pixels. Multi-byte
values are unsigned little-endian. Files are written field by field, never by
serializing a Pascal record. This is unrelated to BASIC PUT or GRAF GET/PUT.

| Offset | Bytes | Meaning |
|---|---:|---|
| 0 | 4 | Magic: `50 31 36 1A` (P16, DOS EOF marker) |
| 4 | 2 | Version: 1 |
| 6 | 2 | Header bytes: 20 |
| 8 | 2 | Width in pixels |
| 10 | 2 | Height in pixels |
| 12 | 2 | Flags: 0 |
| 14 | 2 | Palette identifier: 0, standard 16 Tandy colors |
| 16 | 4 | Payload length: `ceil(width/2) * height` |
| 20 | payload | Rows from top to bottom; even X in the high nibble |

The M6 editor accepts **64x64 only**, matching its current document model:
2,048 payload bytes, exactly 2,068 file bytes. Unsupported sizes (including
odd widths), versions, header sizes, flags, palettes, wrong lengths, trailing
bytes and short reads are rejected before changing the document. Every nibble
is already a valid 0..15 palette index. Future odd-width support must require
zero in the unused low nibble at the end of each row. Variable-size editing is M9.

The filename dialog operates in the current DOS directory with 8.3 names.
It adds `.P16` when no extension is given and accepts `.P16` or `.CLP`, rejecting
other extensions, paths, wildcards and DOS device names. It lists up to 64 files
of these two types; other names can
still be typed. Directory browsing and legacy `.PUT` import are later features.

A save writes and closes a temporary file in a new subfolder of
`TRASH\YYYYMMDD`, then reopens and verifies its header, length and every pixel
byte. Only then does it rename an existing target into that folder under its
original name and rename the temporary file into place. Replacement failure
attempts to restore the old name; the original is retained even if rollback
fails. Failed saves leave the document dirty and its current filename unchanged.
Replaced files and failed temporary writes remain in TRASH for recovery.

## Native CLP version 1

`.CLP` uses the same 20-byte header layout and packed pixel ordering, with
magic `43 4C 50 1A` (`CLP` plus DOS EOF marker). Width and height are each 1..64.
Flags at offset 12 are 0 for a rectangle or 1 for an ellipse; all other bits
are rejected. Version remains 1 and palette remains 0. Payload length is
`ceil(width/2) * height`; the total file length must match exactly. An odd row's
unused low nibble is ignored. Native copies/rotations write that nibble as zero.
Pixels outside the ellipse are excluded by geometry, never by color.

The filename extension and header signature must agree. A CLP load replaces
only the clipboard after complete validation and successful close. A CLP save
takes pixels and dimensions from the clipboard and follows the same temporary
file, read-back verification, backup and recovery procedure as a P16 save.
Neither operation changes the document filename, dirty state, undo or view.
Empty clipboards cannot be saved. This is PP16's native format, not an assertion
of compatibility with another program's `.CLP` format.
