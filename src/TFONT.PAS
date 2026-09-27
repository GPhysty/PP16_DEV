unit TFont;
{$mode tp}{$H-}{$R+}{$Q+}
interface
procedure SmallText(X,Y:Integer; const S:String; C:Byte);
procedure SmallCharOpaque(X,Y:Integer; C:Char; FG,BG:Byte);
implementation
uses TVideo;
function Glyph(C:Char):String;
begin
  case UpCase(C) of
    'A':Glyph:='010101111101101'; 'B':Glyph:='110101110101110';
    'C':Glyph:='011100100100011'; 'D':Glyph:='110101101101110';
    'E':Glyph:='111100110100111'; 'F':Glyph:='111100110100100';
    'G':Glyph:='011100101101011'; 'H':Glyph:='101101111101101';
    'I':Glyph:='111010010010111'; 'J':Glyph:='001001001101010';
    'K':Glyph:='101101110101101'; 'L':Glyph:='100100100100111';
    'M':Glyph:='101111111101101'; 'N':Glyph:='101111111111101';
    'O':Glyph:='010101101101010'; 'P':Glyph:='110101110100100';
    'Q':Glyph:='010101101111011'; 'R':Glyph:='110101110101101';
    'S':Glyph:='011100010001110'; 'T':Glyph:='111010010010010';
    'U':Glyph:='101101101101111'; 'V':Glyph:='101101101101010';
    'W':Glyph:='101101111111101'; 'X':Glyph:='101101010101101';
    'Y':Glyph:='101101010010010'; 'Z':Glyph:='111001010100111';
    '0':Glyph:='111101101101111'; '1':Glyph:='010110010010111';
    '2':Glyph:='110001010100111'; '3':Glyph:='110001010001110';
    '4':Glyph:='101101111001001'; '5':Glyph:='111100110001110';
    '6':Glyph:='011100111101111'; '7':Glyph:='111001010010010';
    '8':Glyph:='111101111101111'; '9':Glyph:='111101111001110';
    ':':Glyph:='000010000010000'; '-':Glyph:='000000111000000';
    '+':Glyph:='000010111010000'; '=':Glyph:='000111000111000';
    '/':Glyph:='001001010100100'; '.':Glyph:='000000000000010';
    '[':Glyph:='110100100100110'; ']':Glyph:='011001001001011';
    '<':Glyph:='001010100010001'; '>':Glyph:='100010001010100';
    '^':Glyph:='010101000000000'; '?':Glyph:='110001010000010';
    else Glyph:='000000000000000';
  end;
end;

procedure SmallCharOpaque(X,Y:Integer; C:Char; FG,BG:Byte);
var G:String[15]; Row:array[0..1] of Byte; I,J:Integer; V:Byte;
begin
  {Four-pixel cell, even X. Replace each complete row without blanking first.}
  G:=Glyph(C);
  for J:=0 to 4 do
  begin
    Row[0]:=(BG shl 4) or BG; Row[1]:=Row[0];
    for I:=0 to 2 do
    begin
      if G[J*3+I+1]='1' then V:=FG else V:=BG;
      if Odd(I) then Row[I div 2]:=(Row[I div 2] and $F0) or V
      else Row[I div 2]:=(Row[I div 2] and 15) or (V shl 4);
    end;
    WriteVideoBytes(X div 2,Y+J,2,Row);
  end;
end;

procedure SmallText(X,Y:Integer; const S:String; C:Byte);
var I,J:Integer; G:String[15];
begin
  for I:=1 to Length(S) do
  begin
    G:=Glyph(S[I]);
    for J:=0 to 14 do if G[J+1]='1' then PutPixel(X+J mod 3,Y+J div 3,C);
    Inc(X,4); if X>319 then Exit;
  end;
end;
end.
