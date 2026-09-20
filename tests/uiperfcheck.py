"""Compare incremental UI frames to full redraws and optional pre-change frames."""
import re
import sys
from pathlib import Path

run = Path(sys.argv[1])
baseline = Path(sys.argv[2]) if len(sys.argv) > 2 else None
names = (
    "File open/close twice", "Switch six menus", "Choose utility", "Help open/close",
    "Cancel dirty Exit", "Change/swap colors", "Select four tools", "Zoom/pan",
    "Open File", "Open dirty Exit",
)

def same(a, b):
    left, right = a.read_bytes(), b.read_bytes()
    assert len(left) == len(right) == 32000, (a, b)
    if left != right:
        mismatch = next(i for i, pair in enumerate(zip(left, right)) if pair[0] != pair[1])
        y, byte_x = divmod(mismatch, 160)
        raise AssertionError(f"{a.name} != {b}: byte at x={byte_x*2}, y={y}: "
                             f"{left[mismatch]:02x} != {right[mismatch]:02x}")

for n in range(10):
    same(run / f"P{n}.BIN", run / f"R{n}.BIN")
    if baseline:
        same(run / f"P{n}.BIN", baseline / f"P{n}.BIN")
print("PASS: all 10 incremental frames equal full redraws byte for byte")
if baseline:
    print("PASS: all 10 frames also equal the comparison build")
    def cycles(path):
        return int(re.search(r"cycles=fixed (\d+)", (path / "perf.conf").read_text())[1])
    if cycles(run) != cycles(baseline):
        print("Timing comparison omitted: runs use different cycle settings")
        sys.exit(0)
    def times(path):
        return {int(n): int(t) for n, t in re.findall(r"UI case (\d+) ticks=(\d+)",
                                                     (path / "PERF.TXT").read_text())}
    old, new = times(baseline), times(run)
    print(f"BIOS ticks at {cycles(run)} cycles/ms (about 55 ms each); coarse emulator measurements")
    for n, label in enumerate(names):
        print(f"{label}: {old[n]} -> {new[n]}")
