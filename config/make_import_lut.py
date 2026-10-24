"""Generate the importer's 12-bit sRGB LUT and canonical Tandy target table."""
import argparse
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument('--check',action='store_true')
args=parser.parse_args()
palette=[(0,0,0),(0,0,170),(0,170,0),(0,170,170),(170,0,0),(170,0,170),(170,85,0),(170,170,170),
         (85,85,85),(85,85,255),(85,255,85),(85,255,255),(255,85,85),(255,85,255),(255,255,85),(255,255,255)]
lut=[round((v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4)*4095) for v in range(256)]
assert all(a<b for a,b in zip(lut,lut[1:])), 'Exact-color flags require an injective LUT.'
lines=['const LinearLUT:array[0..255] of Word=(']
for i in range(0,256,16):
    lines.append('  '+','.join(str(v) for v in lut[i:i+16])+(',' if i<240 else ');'))
lines.append('      Target:array[0..15,0..2] of Word=(')
for i,rgb in enumerate(palette):
    lines.append('  ('+','.join(str(lut[v]) for v in rgb)+('),' if i<15 else '));'))
text='\n'.join(lines)+'\n'
path=Path(__file__).resolve().parent.parent/'src/TCVTLUT.INC'
if args.check:
    assert path.read_text()==text, 'Regenerate src/TCVTLUT.INC.'
    print('Import LUT verified: 256 strictly increasing 12-bit entries and 16 canonical colors')
else:
    path.write_text(text,encoding='ascii')
