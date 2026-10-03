"""Independent CLP fixtures, byte-level format and recovery checks."""
import struct
import sys
from pathlib import Path

root = Path(sys.argv[1])

def clip(w, h, ellipse=False):
    payload = bytearray(((w + 1) // 2) * h)
    for y in range(h):
        for x in range(w):
            inside = ((2*x + 1 - w)**2 * h*h + (2*y + 1 - h)**2 * w*w <= w*w*h*h)
            color = (x + 3*y) & 15 if not ellipse or inside else 0
            payload[y*((w+1)//2) + x//2] |= color << (0 if x & 1 else 4)
    return struct.pack('<4s6HI', b'CLP\x1a', 1, 20, w, h, int(ellipse), 0, len(payload)) + payload

host = clip(3, 2)
if len(sys.argv) == 2:
    (root / 'HOST.CLP').write_bytes(host)
    (root / 'CLIP.P16').write_bytes(host)
    (root / 'DCLIP.CLP').mkdir()
    bad = [b'', host[:19], host[:-1], host + b'x']
    for offset, value in [(0, ord('P')), (4, 2), (6, 19), (8, 0), (8, 65),
                          (9, 1), (10, 0), (11, 1), (12, 2), (14, 1), (16, 255)]:
        data = bytearray(host)
        data[offset] = value
        bad.append(data)
    bad.append(struct.pack('<4s6HI', b'P16\x1a', 1, 20, 64, 64, 0, 0, 2048) + bytes(2048))
    for i, data in enumerate(bad):
        (root / f'BAD{i}.CLP').write_bytes(data)
else:
    for name, w, h, ellipse in [('OVAL', 5, 7, True), ('TINY', 1, 1, False), ('FULL', 64, 64, False)]:
        assert (root / f'{name}.CLP').read_bytes() == clip(w, h, ellipse), name
    assert (root / 'RECT.CLP').read_bytes() == host, 'Replacement differs'
    backups = list((root / 'TRASH').glob('*/*/RECT.CLP'))
    assert any(p.read_bytes() == clip(5, 2) for p in backups), 'Original clip backup missing'
    assert not (root / 'EMPTY.CLP').exists(), 'Empty clipboard created file'
    assert any(len(p.read_bytes()) == 22 for p in (root / 'TRASH').glob('*/*/NEW.TMP')), 'Partial-write fixture missing'
    print('PASS: independent CLP headers, pixels, ellipse mask, and retained originals')
