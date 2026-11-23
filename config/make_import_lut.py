"""Generate the importer's sRGB, Tandy and integer CIELAB/D65 tables."""
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
# Q15 XYZ rows normalized to the D65 reference white. Each row sums to 32768.
xyz=((.4124564,.3575761,.1804375),(.2126729,.7151522,.0721750),(.0193339,.1191920,.9503041))
white=(.95047,1,1.08883)
matrix=[]
for row,w in zip(xyz,white):
    coefficients=[round(v/w*32768) for v in row]
    coefficients[max(range(3),key=coefficients.__getitem__)]+=32768-sum(coefficients)
    matrix.append(coefficients)
def curve(t):
    d=6/29
    return t**(1/3) if t>d**3 else t/(3*d*d)+4/29
curve_lut=[min(32767,round(curve(i/256)*32768)) for i in range(257)]
def rounded(v,denominator):
    return (v+denominator//2)//denominator if v>=0 else -((-v+denominator//2)//denominator)
def fixed_lab(rgb):
    f=[]
    for row in matrix:
        v=(sum(lut[c]*k for c,k in zip(rgb,row))+2048)//4096
        i,part=divmod(v,128)
        f.append((curve_lut[i]*(128-part)+curve_lut[i+1]*part+64)//128)
    return (rounded(116*f[1]-524288,2048),rounded(500*(f[0]-f[1]),2048),rounded(200*(f[1]-f[2]),2048))
lines.append('      LabMatrix:array[0..2,0..2] of Integer=(')
for i,row in enumerate(matrix):
    lines.append('  ('+','.join(map(str,row))+('),' if i<2 else '));'))
lines.append('      LabCurveLUT:array[0..256] of Integer=(')
for i in range(0,257,16):
    lines.append('  '+','.join(map(str,curve_lut[i:i+16]))+(',' if i<256 else ');'))
lines.append('      TargetLab:array[0..15,0..2] of Integer=(')
for i,rgb in enumerate(palette):
    lines.append('  ('+','.join(map(str,fixed_lab(rgb)))+('),' if i<15 else '));'))
text='\n'.join(lines)+'\n'
path=Path(__file__).resolve().parent.parent/'src/TCVTLUT.INC'
if args.check:
    assert path.read_text()==text, 'Regenerate src/TCVTLUT.INC.'
    print('Import LUT verified: sRGB, canonical colors and integer CIELAB/D65 tables')
else:
    path.write_text(text,encoding='ascii')
