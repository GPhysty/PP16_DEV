unit TFont;
{$mode tp}{$H-}{$R+}{$Q+}
interface
procedure SmallText(X,Y:Integer; const S:String; C:Byte);
procedure SmallCharOpaque(X,Y:Integer; C:Char; FG,BG:Byte);
implementation
uses TVideo;
function GlyphBits(C:Char):Word;
begin
  case UpCase(C) of
    'A':GlyphBits:=$2BED; 'B':GlyphBits:=$6BAE;
    'C':GlyphBits:=$3923; 'D':GlyphBits:=$6B6E;
    'E':GlyphBits:=$79A7; 'F':GlyphBits:=$79A4;
    'G':GlyphBits:=$396B; 'H':GlyphBits:=$5BED;
    'I':GlyphBits:=$7497; 'J':GlyphBits:=$126A;
    'K':GlyphBits:=$5BAD; 'L':GlyphBits:=$4927;
    'M':GlyphBits:=$5FED; 'N':GlyphBits:=$5FFD;
    'O':GlyphBits:=$2B6A; 'P':GlyphBits:=$6BA4;
    'Q':GlyphBits:=$2B7B; 'R':GlyphBits:=$6BAD;
    'S':GlyphBits:=$388E; 'T':GlyphBits:=$7492;
    'U':GlyphBits:=$5B6F; 'V':GlyphBits:=$5B6A;
    'W':GlyphBits:=$5BFD; 'X':GlyphBits:=$5AAD;
    'Y':GlyphBits:=$5A92; 'Z':GlyphBits:=$72A7;
    '0':GlyphBits:=$7B6F; '1':GlyphBits:=$2C97;
    '2':GlyphBits:=$62A7; '3':GlyphBits:=$628E;
    '4':GlyphBits:=$5BC9; '5':GlyphBits:=$798E;
    '6':GlyphBits:=$39EF; '7':GlyphBits:=$7292;
    '8':GlyphBits:=$7BEF; '9':GlyphBits:=$7BCE;
    ':':GlyphBits:=$0410; '-':GlyphBits:=$01C0;
    '+':GlyphBits:=$05D0; '=':GlyphBits:=$0E38;
    '/':GlyphBits:=$12A4; '.':GlyphBits:=$0002;
    '[':GlyphBits:=$6926; ']':GlyphBits:=$324B;
    '<':GlyphBits:=$1511; '>':GlyphBits:=$4454;
    '^':GlyphBits:=$2A00; '?':GlyphBits:=$6282;
    else GlyphBits:=0;
  end;
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
