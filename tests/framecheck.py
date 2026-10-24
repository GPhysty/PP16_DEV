"""Verify the DOS-generated M1 page and render it; not an emulator screenshot."""
import struct
import sys
import zlib
from pathlib import Path

source, destination = map(Path, sys.argv[1:3])
ui = len(sys.argv) > 3 and sys.argv[3] in ("ui", "drawing")
data = source.read_bytes()
assert len(data) == 32000, len(data)
pixels = bytes(v for b in data for v in (b >> 4, b & 15))
if len(sys.argv) > 3 and sys.argv[3] == 'confirm':
    assert pixels[49*320+36] == 9 and pixels[143*320+283] == 9
    assert pixels[78*320+40] == 1  # Opaque dialog interior.
    assert pixels[110*320+166] == 4  # Cancel has the default focus outline.
elif len(sys.argv) > 3 and sys.argv[3] == 'file':
    assert pixels[36*320+50] == 9 and pixels[145*320+269] == 9
    assert pixels[56*320+104] == 15  # Filename starts selected.
    assert pixels[71*320+70] == 1  # Opaque file list.
elif len(sys.argv) > 3 and sys.argv[3] == 'import':
    assert pixels[36*320+50] == 9 and pixels[145*320+269] == 9
    assert pixels[71*320+71] == 14  # PUT image selector has keyboard focus.
    assert pixels[72*320+198] == 7 and pixels[72*320+232] == 7
    assert pixels[112*320+257] == 1  # Settings remain inside the modal panel.
elif len(sys.argv) > 3 and sys.argv[3] == 'utility':
    assert pixels[62*320] == 15 and pixels[70*320] == 1
elif len(sys.argv) > 3 and sys.argv[3] == 'menu':
    assert pixels[9*320+1] == 9 or pixels[9*320+64] == 9
elif ui:
    assert pixels[0] == 1 and pixels[192*320] == 1
    assert pixels[28*320+84] == 7 and pixels[157*320+213] == 7
    for color in range(16):
        assert pixels[(130+(color//4)*11)*320+10+(color%4)*19] == color
else:
    assert [pixels[i] for i in (0, 319, 199*320, 63999)] == [15, 12, 10, 9]
    for color in range(16):
        assert pixels[65*320+17+color*19] == color
    for y in range(8):
        assert pixels[y*320+160] == y+1
        assert pixels[(192+y)*320+160] == 15-y
if len(sys.argv) > 3 and sys.argv[3] == 'drawing':
    assert pixels[125*320+93] == 15  # New stroke in the zoomed canvas.
    assert pixels[77*320+240] == 15  # Same document pixel in the 1:1 preview.
palette = bytes.fromhex(
    "000000 0000aa 00aa00 00aaaa aa0000 aa00aa aa5500 aaaaaa "
    "555555 5555ff 55ff55 55ffff ff5555 ff55ff ffff55 ffffff")

def chunk(kind, payload):
    return (struct.pack('>I', len(payload)) + kind + payload
            + struct.pack('>I', zlib.crc32(kind + payload)))

scanlines = b''.join(b'\x00' + pixels[y*320:(y+1)*320] for y in range(200))
png = (b'\x89PNG\r\n\x1a\n'
       + chunk(b'IHDR', struct.pack('>IIBBBBB', 320, 200, 8, 3, 0, 0, 0))
       + chunk(b'PLTE', palette) + chunk(b'IDAT', zlib.compress(scanlines))
       + chunk(b'IEND', b''))
destination.write_bytes(png)
print('PASS: framebuffer checks for', source.name)
print('Rendered raw video-memory dump (not a screenshot):', destination)
