"""Independent indexed decoders/full-image FS oracle and DOS import fixtures."""
import hashlib
import json
import struct
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ROOT = Path(sys.argv[1]).resolve()
TARGET = [(0,0,0),(0,0,170),(0,170,0),(0,170,170),(170,0,0),(170,0,170),(170,85,0),(170,170,170),
          (85,85,85),(85,85,255),(85,255,85),(85,255,255),(255,85,85),(255,85,255),(255,255,85),(255,255,255)]
LUT = [round((v/255/12.92 if v/255 <= .04045 else ((v/255+.055)/1.055)**2.4)*4095) for v in range(256)]
assert all(a < b for a,b in zip(LUT,LUT[1:]))
LINEAR = [tuple(LUT[v] for v in c) for c in TARGET]


def oracle(rows, palette):
    """Full-image error grid, deliberately distinct from the DOS two-row ring."""
    h, w = len(rows), len(rows[0])
    errors = [[[0,0,0] for _ in range(w+2)] for _ in range(h+1)]
    out = bytearray(2048)
    exact = {c:i for i,c in enumerate(TARGET)}
    def rounded(v):
        return (v+8)//16 if v >= 0 else -((-v+8)//16)
    for y, row in enumerate(rows):
        direction = -1 if y & 1 else 1
        for x in (range(w-1,-1,-1) if y & 1 else range(w)):
            rgb = tuple(palette[row[x]])
            corrected = [min(65520,max(0,LUT[rgb[c]]*16+errors[y][x+1][c])) for c in range(3)]
            quant = [(v+8)//16 for v in corrected]
            if rgb in exact:
                chosen = exact[rgb]
            else:
                candidates = [0,7,8,15] if rgb[0] == rgb[1] == rgb[2] else range(16)
                chosen = min(candidates, key=lambda i: sum(weight*(quant[c]-LINEAR[i][c])**2 for c,weight in enumerate((3,6,1))))
            out[y*32+x//2] |= chosen << (4 if x % 2 == 0 else 0)
            for c in range(3):
                residual = corrected[c]-LINEAR[chosen][c]*16
                errors[y][x+1+direction][c] += rounded(residual*7)
                errors[y+1][x+1-direction][c] += rounded(residual*3)
                errors[y+1][x+1][c] += rounded(residual*5)
                errors[y+1][x+1+direction][c] += rounded(residual)
    return bytes(out)


def pcx(rows, palette, stride=None):
    w, h = len(rows[0]), len(rows)
    stride = stride or (w+1)//2*2
    header = bytearray(128)
    header[:4] = bytes((10,5,1,8))
    struct.pack_into('<HHHH',header,4,0,0,w-1,h-1)
    header[65] = 1
    struct.pack_into('<H',header,66,stride)
    encoded = bytearray()
    for row in rows:
        # Literal packets exercise high-valued escapes and padded scanlines.
        for value in list(row)+[231]*(stride-w):
            if value >= 192:
                encoded.extend((193,value))
            else:
                encoded.append(value)
    pal = list(palette)+[(0,0,0)]*(256-len(palette))
    return bytes(header+encoded+bytes((12,))+bytes(c for rgb in pal for c in rgb))


def pcx4(rows, palette, stride=None):
    w, h = len(rows[0]), len(rows)
    row_bytes = (w+1)//2
    stride = stride or (row_bytes+1)//2*2
    header = bytearray(128)
    header[:4] = bytes((10,5,1,4))
    struct.pack_into('<HHHH',header,4,0,0,w-1,h-1)
    header[16:64] = bytes(c for rgb in list(palette)+[(0,0,0)]*(16-len(palette)) for c in rgb)
    header[65] = 1
    struct.pack_into('<H',header,66,stride)
    encoded = bytearray()
    for row in rows:
        packed = [(row[x]<<4) | (row[x+1] if x+1<w else 15) for x in range(0,w,2)]
        packed += [225]*(stride-row_bytes)
        pos = 0
        while pos < len(packed):
            count = 1
            while pos+count < len(packed) and count < 63 and packed[pos+count] == packed[pos]:
                count += 1
            value = packed[pos]
            if count > 1 or value >= 192:
                encoded.extend((192+count,value))
            else:
                encoded.append(value)
            pos += count
    return bytes(header+encoded)


def decode_pcx(data):
    bits = data[3]
    assert bits in (4,8) and data[65] == 1
    xmin,ymin,xmax,ymax = struct.unpack_from('<HHHH',data,4)
    w,h = xmax-xmin+1,ymax-ymin+1
    stride = struct.unpack_from('<H',data,66)[0]
    pos = 128
    rows = []
    for _ in range(h):
        row = []
        while len(row) < stride:
            value = data[pos]; pos += 1; count = 1
            if value & 192 == 192:
                count = value & 63; value = data[pos]; pos += 1
            assert count and len(row)+count <= stride
            row.extend([value]*count)
        if bits == 4:
            row = [v for byte in row for v in (byte>>4,byte&15)]
        rows.append(row[:w])
    if bits == 4:
        assert pos == len(data)
        pal = [tuple(data[i:i+3]) for i in range(16,64,3)]
    else:
        assert pos == len(data)-769 and data[pos] == 12
        pal = [tuple(data[i:i+3]) for i in range(pos+1,len(data),3)]
    return rows,pal


def put(images):
    payload = bytearray()
    for rows in images:
        payload.extend(struct.pack('<HH',len(rows[0])*8,len(rows)))
        payload.extend(bytes(v for row in rows for v in row))
        if len(rows)*len(rows[0]) % 2:
            payload.append(165)  # Alignment is not a pixel or required to be zero.
    assert len(payload) <= 65536
    return bytes((253,))+struct.pack('<HHH',0x1234,0,len(payload) & 65535)+payload


def decode_put(data, image):
    pos=7; count=0
    while pos < len(data):
        bits,h=struct.unpack_from('<HH',data,pos); w=bits//8; count+=1
        if count == image:
            return [list(data[pos+4+y*w:pos+4+(y+1)*w]) for y in range(h)]
        pos += 4+(w*h+1)//2*2
    raise AssertionError('No such PUT record')


def palette_dac(palette):
    return bytes(v for c in palette for v in (*c,0))


def expanded(dac):
    return [tuple((v*255+31)//63 for v in c) for c in dac]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def setup():
    assert not (ROOT/'IMPORTS.JSON').exists(), 'Use a fresh disposable test drive.'
    cases=[]
    def save(name, data):
        (ROOT/name).write_bytes(data)
    def expected(name, image, palette, rows, colors):
        n=len(cases); raw=f'E{n:02}.RAW'; output=f'I{n:02}.P16'
        save(raw,oracle(rows,colors))
        cases.append(dict(name=name,image=image,palette=palette,expected=raw,output=output))
    dac = [(c[0]//85*21,c[1]//85*21,c[2]//85*21) for c in TARGET]
    dac += [(i%64,(i*13)%64,(i*29)%64) for i in range(16,256)]
    colors = expanded(dac)
    save('GOOD.PAL',palette_dac(dac)); save('GEN.APF',palette_dac(dac))
    identity = [[(x//4+y)%16 for x in range(64)] for y in range(64)]
    save('IDENT.PCX',pcx(identity,colors)); expected('IDENT.PCX',1,'',identity,colors)
    generated = [[(x*7+y*11)%256 for x in range(64)] for y in range(64)]
    save('GEN.PCX',pcx(generated,colors)); save('GEN.PUT',put([generated]))
    expected('GEN.PCX',1,'',generated,colors); expected('GEN.PUT',1,'',generated,colors)
    permuted = [[255-v for v in row] for row in generated]
    save('PERM.PCX',pcx(permuted,list(reversed(colors))))
    expected('PERM.PCX',1,'',permuted,list(reversed(colors)))
    small = [[1,6,12,255,15],[8,170,200,14,3],[5,250,9,4,7]]
    other = [[2,2,2],[2,6,2],[2,2,2]]
    save('SMALL.PCX',pcx(small,colors,8)); save('MULTI.PUT',put([other,small]))
    save('MULTI.APF',palette_dac(dac))
    expected('SMALL.PCX',1,'',small,colors); expected('MULTI.PUT',2,'',small,colors)
    save('PADWIDE.PCX',pcx(small,colors,4096)); expected('PADWIDE.PCX',1,'',small,colors)
    grays=[(v,v,v) for v in ((i*255+31)//63 for i in range(64))]
    gray_rows=[list(range(64)) for _ in range(64)]
    save('GRAY.PCX',pcx(gray_rows,grays)); expected('GRAY.PCX',1,'',gray_rows,grays)
    ramp_colors=[]
    for channel in range(4):
        for i in range(64):
            v=(i*255+31)//63
            ramp_colors.append((v,v,v) if channel==0 else tuple(v if c==channel-1 else 0 for c in range(3)))
    ramp_rows=[[y//16*64+x for x in range(64)] for y in range(64)]
    save('RAMPS.PCX',pcx(ramp_rows,ramp_colors)); expected('RAMPS.PCX',1,'',ramp_rows,ramp_colors)
    save('MIXED.PUT',put([[[1]*256 for _ in range(128)],small]))
    expected('MIXED.PUT',2,'GOOD.PAL',small,colors)
    save('MISSING.PUT',put([small]))
    save('ASSOC.PUT',put([small])); (ROOT/'PALETTES').mkdir()
    save('PALETTES/ASSOC.APF',palette_dac(dac)); expected('ASSOC.PUT',1,'',small,colors)
    (ROOT/'IMAGES').mkdir(); save('IMAGES/ASSOC.PUT',put([small]))
    save('IMAGES/EXPECT.RAW',oracle(small,colors))
    # Header palettes, high/low nibble order, RLE of packed pairs, unused low
    # nibbles on odd widths, sub-898-byte images and long padded scanlines.
    packed_identity = pcx4(identity,TARGET)
    packed_permuted = pcx4([[15-v for v in row] for row in identity],list(reversed(TARGET)))
    odd4 = [[15,12,15,12,15,12,3],[1,2,3,4,5,6,7],[8,8,8,8,8,8,8]]
    packed_cases = [('PACK4',packed_identity),('PERM4',packed_permuted),
                    ('ODD4',pcx4(odd4,colors[16:32])),
                    ('PAD4',pcx4(odd4,colors[16:32],4096)),('ONE4',pcx4([[6]],TARGET))]
    for name,data in packed_cases:
        rows,pal = decode_pcx(data)
        save(name+'.PCX',data); expected(name+'.PCX',1,'',rows,pal)
    for name in ['BIRDN','BIRDFSN','BIRDFSRB','BIRDP']:
        data=(REPO/'assets'/f'{name}.pcx').read_bytes(); rows,pal=decode_pcx(data)
        save(f'{name}.PCX',data); expected(f'{name}.PCX',1,'',rows,pal)
    for name,index in [('BOUNCE',8),('GLOBE1',25)]:
        data=(REPO/'references/pp256/IMAGES'/f'{name}.PUT').read_bytes()
        pal=(REPO/'references/pp256/PALETTES'/f'{name}.APF').read_bytes()
        save(f'{name}.PUT',data); save(f'PALETTES/{name}.APF',pal)
        colors_real=expanded([tuple(pal[i:i+3]) for i in range(0,1024,4)])
        expected(f'{name}.PUT',index,'',decode_put(data,index),colors_real)
    base=pcx(small,colors,8)
    mutations = {'PCXVER':(1,3),'PCXBPP':(3,2),'PCXPLN':(65,3),'PCXENC':(2,2),
                 'PCXWIDE':(8,64),'PCXHIGH':(10,64),'PCXLINE':(66,3),'PCXXMIN':(4,6)}
    for name,(offset,value) in mutations.items():
        b=bytearray(base); b[offset]=value; save(name+'.PCX',b)
    save('PCXZERO.PCX',base[:128]+bytes((192,1))+base[-769:])
    save('PCXRUN.PCX',base[:128]+bytes((201,1))+base[-769:])
    save('PCXTRUNC.PCX',base[:128]+bytes((193,))+base[-769:])
    save('PCXEXTRA.PCX',base[:-769]+bytes((1,))+base[-769:])
    save('PCXPAL.PCX',base[:-769]+bytes((11,))+base[-768:])
    save('PCXSHORT.PCX',base[:127])
    base4 = pcx4(odd4,colors[16:32])
    b=bytearray(base4); b[66]=2; save('P4LINE.PCX',b)
    b=bytearray(pcx4([[6]],TARGET)); b[66]=3; save('P4ODD.PCX',b)
    save('P4ZERO.PCX',base4[:128]+bytes((192,1)))
    save('P4RUN.PCX',base4[:128]+bytes((197,1)))
    save('P4TRUNC.PCX',base4[:128]+bytes((193,)))
    save('P4EXTRA.PCX',base4+bytes((0,)))
    p=put([small]); save('PUTSHORT.PUT',p[:-1]); save('PUTEXTRA.PUT',p+bytes((0,)))
    b=bytearray(p); b[0]=0; save('PUTMAGIC.PUT',b)
    b=bytearray(p); b[7]=41; save('PUTBITS.PUT',b)
    b=bytearray(p); b[9]=0; save('PUTZERO.PUT',b)
    save('PUTPAD.PUT',bytes((253,))+struct.pack('<HHH',0,0,19)+p[7:-1])
    b=bytearray(palette_dac(dac)); b[0]=64; save('BADDAC.PAL',b)
    b=bytearray(palette_dac(dac)); b[3]=1; save('BADFOUR.PAL',b)
    save('SHORT.PAL',b[:1023])
    lines=[str(len(cases))]
    for c in cases:
        lines.extend(str(c[k]) for k in ['name','image','palette','expected','output'])
    (ROOT/'CASES.TXT').write_text('\n'.join(lines)+'\n',encoding='ascii')
    inputs={str(p.relative_to(ROOT)):digest(p) for p in ROOT.rglob('*')
            if p.suffix.upper() in ('.PCX','.PUT','.PAL','.APF')}
    protected={str(p.relative_to(REPO)):digest(p) for directory in ['assets','dist']
               for p in (REPO/directory).rglob('*') if p.is_file()}
    (ROOT/'IMPORTS.JSON').write_text(json.dumps(dict(cases=cases,inputs=inputs,protected=protected),indent=2)+'\n')
    print(f'Import fixtures: {len(cases)} golden conversions, malformed inputs, palettes, directory layouts')


def verify():
    data=json.loads((ROOT/'IMPORTS.JSON').read_text())
    for c in data['cases']:
        output=(ROOT/c['output']).read_bytes()
        assert len(output)==2068 and output[:4]==b'P16\x1a', c
        assert output[20:]==(ROOT/c['expected']).read_bytes(), c
    for directory,protected in [(ROOT,data['inputs']),(REPO,data['protected'])]:
        for relative,sha in protected.items():
            assert digest(directory/relative)==sha, relative
    assert (ROOT/'I01.P16').read_bytes()==(ROOT/'I02.P16').read_bytes()==(ROOT/'I03.P16').read_bytes()
    by_name = {c['name']: c for c in data['cases']}
    assert (ROOT/by_name['PACK4.PCX']['output']).read_bytes() == (ROOT/by_name['PERM4.PCX']['output']).read_bytes()
    print('INDEPENDENT IMPORT VERIFICATION PASSED: golden pixels, format/permutation equality, unchanged inputs and release')


verify() if len(sys.argv)>2 and sys.argv[2]=='verify' else setup()
