"""Independently check exported PCX headers, RLE rows, palette and every pixel."""
import struct
import sys
from pathlib import Path

root = Path(sys.argv[1])
palette = bytes(v for rgb in (
    (0, 0, 0), (0, 0, 170), (0, 170, 0), (0, 170, 170),
    (170, 0, 0), (170, 0, 170), (170, 85, 0), (170, 170, 170),
    (85, 85, 85), (85, 85, 255), (85, 255, 85), (85, 255, 255),
    (255, 85, 85), (255, 85, 255), (255, 255, 85), (255, 255, 255),
) for v in rgb) + bytes(720)
original = bytes((x // 4 + y) % 16 for y in range(64) for x in range(64))
header = bytearray(128)
header[:4] = bytes((10, 5, 1, 8))
struct.pack_into('<HHHH', header, 4, 0, 0, 63, 63)
header[65] = 1
struct.pack_into('<HH', header, 66, 64, 1)
blocked = bytes(header) + original + b'\x0c' + palette


def decode(path):
    data = path.read_bytes()
    assert data[:4] == bytes((10, 5, 1, 8)), (path, 'must be version 5, RLE, 8 bit')
    assert struct.unpack_from('<4H', data, 4) == (0, 0, 63, 63), path
    assert data[64] == 0 and data[65] == 1, (path, 'one plane')
    assert struct.unpack_from('<HH', data, 66) == (64, 1), path
    assert data[-769] == 12 and data[-768:] == palette, (path, 'exact 256-entry palette')
    pixels = bytearray()
    position = 128
    for _ in range(64):
        row = bytearray()
        while len(row) < 64:
            assert position < len(data) - 769, (path, 'truncated row')
            value = data[position]
            position += 1
            count = 1
            if value >= 192:
                count = value & 63
                assert count and position < len(data) - 769, path
                value = data[position]
                position += 1
            assert len(row) + count <= 64, (path, 'run crosses row')
            row.extend([value] * count)
        pixels.extend(row)
    assert position == len(data) - 769, (path, 'unexpected image bytes')
    return bytes(pixels)


if len(sys.argv) == 2:
    (root / 'DIR.PCX').mkdir()
    (root / 'BLOCKED' / 'KEEP.PCX').write_bytes(blocked)
else:
    edited = bytearray(original)
    edited[:2] = bytes((12, 9))
    assert decode(root / 'COLORS.PCX') == edited
    assert decode(root / 'NEW.PCX') == original
    assert decode(root / 'BLACK.PCX') == bytes(4096)
    assert decode(root / 'WHITE.PCX') == bytes([15]) * 4096
    runs = bytes(0 if y == 0 else (15 if x < 63 else 3) if y == 1
                 else 3 + (x % 2) * 3 if y == 2 else (x // 2) % 16 if y == 3
                 else y % 16 for y in range(64) for x in range(64))
    assert decode(root / 'RUNS.PCX') == runs
    native = (root / 'PROD.P16').read_bytes()[20:]
    assert decode(root / 'PROD.PCX') == bytes(v for b in native for v in (b >> 4, b & 15))
    ui = bytearray((root / 'PP16UI.P16').read_bytes()[20:])
    ui[0] = (ui[0] & 0xf0) | 9
    assert decode(root / 'UIEXPORT.PCX') == bytes(v for b in ui for v in (b >> 4, b & 15))
    backups = list((root / 'TRASH').glob('*/*/COLORS.PCX'))
    assert any(decode(path) == original for path in backups), 'original PCX backup missing'
    assert any(decode(path) == edited for path in (root / 'TRASH').glob('*/*/NEW.PCX')
               if len(path.read_bytes()) >= 898), 'NEW.PCX original backup missing'
    assert (root / 'BLOCKED' / 'KEEP.PCX').read_bytes() == blocked
    partials = [path.read_bytes() for path in (root / 'TRASH').glob('*/*/NEW.PCX')]
    assert any(data[:4] == bytes((10, 5, 1, 8)) and 128 < len(data) <= 192
               for data in partials), 'partial PCX from failed write missing'
    print('PASS: 8-bit PCX headers, RLE boundaries, 256-entry RGBI palette, every pixel, retained originals')
