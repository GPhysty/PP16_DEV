"""Independent P16 fixtures and host-side roundtrip/backup verification."""
import struct
import sys
from pathlib import Path

root = Path(sys.argv[1])
header = struct.pack('<4s6HI', b'P16\x1a', 1, 20, 64, 64, 0, 0, 2048)
payload = bytes((((x // 4 + y) % 16) << 4) | (((x + 1) // 4 + y) % 16)
                for y in range(64) for x in range(0, 64, 2))
original = header + payload
if len(sys.argv) == 2:
    for name, data in [('EMPTY', b''), ('SHORT', header[:9]), ('TRUNC', original[:-1]),
                       ('EXTRA', original + b'x')]:
        (root / f'{name}.P16').write_bytes(data)
    for name, offset, value in [('MAGIC', 0, 0), ('VERSION', 4, 2), ('FLAGS', 12, 1),
                                 ('PALETTE', 14, 1), ('LENGTH', 16, 1),
                                 ('WIDTH', 8, 19), ('HEIGHT', 10, 0), ('HEADER', 6, 19)]:
        data = bytearray(original)
        data[offset] = value
        (root / f'{name}.P16').write_bytes(data)
    (root / 'ODD.P16').write_bytes(struct.pack('<4s6HI', b'P16\x1a', 1, 20, 19, 17, 0, 0, 170)
                                    + bytes(170))
    (root / 'DIR.P16').mkdir()
    blocked = root / 'BLOCKED'
    blocked.mkdir()
    (blocked / 'TRASH').write_bytes(b'Intentional save-directory obstruction')
    (blocked / 'KEEP.P16').write_bytes(original)
else:
    def demo_pixel(x, y):
        color = 7 if (x * 13 + y * 7) % 113 == 0 else 0
        distance = (x - 32) ** 2 + (y - 31) ** 2
        if distance <= 256:
            color = 1
        if distance <= 196:
            color = 14 if y < 25 else 6 if y < 31 else 12 if y < 37 else 4
            if y >= 36 and y > 43 - abs(x - 28):
                color = 0
            if 39 <= y < 43:
                color = 3
        return color
    demo = bytes((demo_pixel(x, y) << 4) | demo_pixel(x + 1, y)
                 for y in range(64) for x in range(0, 64, 2))
    assert (root / 'PROD.P16').read_bytes() == header + demo, 'Production save differs'
    current = (root / 'ROUND.P16').read_bytes()
    expected = bytearray(original)
    expected[20] = 0xc9
    assert current == expected, 'Final ROUND pixels/header differ'
    copies = list((root / 'TRASH').glob('*/*/ROUND.P16'))
    assert any(p.read_bytes() == original for p in copies), 'Original backup missing'
    assert (root / 'BLOCKED' / 'KEEP.P16').read_bytes() == original
    assert any(len(p.read_bytes()) == 1044 for p in (root / 'TRASH').glob('*/*/NEW.TMP'))
    for name in ('UITEST.P16', 'UICOPY.P16'):
        data = (root / name).read_bytes()
        assert len(data) == 2068 and data[:20] == header, name
        assert data[20] >> 4 == 12, name
    print('PASS: independent header/pixels, retained originals, and partial-write artifact')
