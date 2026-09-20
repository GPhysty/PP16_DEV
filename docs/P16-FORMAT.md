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

The first filename dialog operates in the current DOS directory with 8.3 names.
It adds `.P16` when no extension is given and rejects other extensions, paths,
wildcards and DOS device names. It lists up to 64 `.P16` files; other names can
still be typed. Directory browsing and legacy `.PUT` import are later features.

A save writes and closes a temporary file in a new subfolder of
`TRASH\YYYYMMDD`, then reopens and verifies its header, length and every pixel
byte. Only then does it rename an existing target into that folder under its
original name and rename the temporary file into place. Replacement failure
attempts to restore the old name; the original is retained even if rollback
fails. Failed saves leave the document dirty and its current filename unchanged.
Replaced files and failed temporary writes remain in TRASH for recovery.
