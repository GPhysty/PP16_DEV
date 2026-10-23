unit TFont;
{$mode tp}{$H-}{$R+}{$Q+}
interface
procedure SmallText(X,Y:Integer; const S:String; C:Byte);
procedure SmallCharOpaque(X,Y:Integer; C:Char; FG,BG:Byte);
implementation
uses TVideo;
function GlyphBits(C:Char):Word;
const Glyphs:array[32..94] of Word=($0000,$0000,$0000,$0000,$0000,$52A5,$0000,$0000,$0000,$0000,$0000,$05D0,$0000,$01C0,$0002,$12A4,$7B6F,$2C97,$62A7,$628E,$5BC9,$798E,$39EF,$7292,$7BEF,$7BCE,$0410,$0000,$1511,$0E38,$4454,$6282,$0000,$2BED,$6BAE,$3923,$6B6E,$79A7,$79A4,$396B,$5BED,$7497,$126A,$5BAD,$4927,$5FED,$5FFD,$2B6A,$6BA4,$2B7B,$6BAD,$388E,$7492,$5B6F,$5B6A,$5BFD,$5AAD,$5A92,$72A7,$6926,$0000,$324B,$2A00);
begin
  C:=UpCase(C); if (Ord(C)<32) or (Ord(C)>94) then GlyphBits:=0
  else GlyphBits:=Glyphs[Ord(C)];
end;

procedure SmallCharOpaque(X,Y:Integer; C:Char; FG,BG:Byte);
var G:Word; Row:array[0..1] of Byte; I,J:Integer; V:Byte;
begin
  {Four-pixel cell, even X. Replace each complete row without blanking first.}
  G:=GlyphBits(C);
  for J:=0 to 4 do
  begin
    Row[0]:=(BG shl 4) or BG; Row[1]:=Row[0];
    for I:=0 to 2 do
    begin
      if (G and $4000)<>0 then V:=FG else V:=BG;
      if Odd(I) then Row[I div 2]:=(Row[I div 2] and $F0) or V
      else Row[I div 2]:=(Row[I div 2] and 15) or (V shl 4);
      G:=G shl 1;
    end;
    WriteVideoBytes(X div 2,Y+J,2,Row);
  end;
end;

procedure SmallText(X,Y:Integer; const S:String; C:Byte);
var I,J:Integer; G:Word;
begin
  for I:=1 to Length(S) do
  begin
    G:=GlyphBits(S[I]);
    for J:=0 to 14 do
    begin
      if (G and $4000)<>0 then PutPixel(X+J mod 3,Y+J div 3,C);
      G:=G shl 1;
    end;
    Inc(X,4); if X>319 then Exit;
  end;
end;
end.
