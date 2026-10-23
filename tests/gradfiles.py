"""Check that gradient image/clipboard files contain literal palette pixels."""
import struct
import sys
from pathlib import Path

root = Path(sys.argv[1])
image = (root / 'GRAD.P16').read_bytes()
clip = (root / 'GRAD.CLP').read_bytes()
assert image[:20] == struct.pack('<4s6HI', b'P16\x1a', 1, 20, 64, 64, 0, 0, 2048)
assert clip[:20] == struct.pack('<4s6HI', b'CLP\x1a', 1, 20, 11, 9, 0, 0, 54)
assert len(image) == 2068 and len(clip) == 74

def pixel(payload, stride, x, y):
    return (payload[y * stride + x // 2] >> (0 if x & 1 else 4)) & 15

payload = image[20:]
tile = [pixel(payload, 32, x, y) for y in range(10) for x in range(10)]
assert tile.count(14) == 30 and tile.count(1) == 70
for y in range(64):
    for x in range(64):
        assert pixel(payload, 32, x, y) == tile[(y % 10) * 10 + x % 10]
for y in range(9):
    for x in range(11):
        assert pixel(clip[20:], 6, x, y) == pixel(payload, 32, x + 1, y + 3)
    assert clip[20 + y * 6 + 5] & 15 == 0  # Odd-width padding stays zero.
print('PASS: literal gradient P16/CLP headers, exact coverage, tiling and source phase')
