"""Check filled shapes against a flood of the existing outline's exterior."""
from collections import deque
from pathlib import Path
import sys

root = Path(sys.argv[1])
for tool in (5, 6):
    for size in range(1, 6):
        def pixels(prefix):
            data = (root / f"{prefix}{tool}{size}.RAW").read_bytes()
            assert len(data) == 2048
            return bytes(v for b in data for v in (b >> 4, b & 15))

        outline, filled = pixels("O"), pixels("F")
        assert set(outline) == {3, 11}
        exterior = set()
        queue = deque((x, y) for x in range(64) for y in (0, 63))
        queue.extend((x, y) for y in range(64) for x in (0, 63))
        while queue:
            x, y = queue.popleft()
            if not (0 <= x < 64 and 0 <= y < 64):
                continue
            if (x, y) in exterior or outline[y * 64 + x] == 3:
                continue
            exterior.add((x, y))
            queue.extend(((x-1, y), (x+1, y), (x, y-1), (x, y+1)))
        for y in range(64):
            for x in range(64):
                i = y * 64 + x
                expected = 3 if outline[i] == 3 else 11 if (x, y) in exterior else 4
                assert filled[i] == expected, (tool, size, x, y, filled[i], expected)
print("PASS: filled circle/square pixels match existing borders and independently enclosed interiors at sizes 1-5")
