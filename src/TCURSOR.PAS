unit TCursor;
{$mode tp}{$H-}{$R+}{$Q+}
interface
procedure ShowCursor(X,Y:Integer);
procedure HideCursor;
function CursorOverlaps(X1,Y1,X2,Y2:Integer):Boolean;
implementation
uses TVideo;
const {Cursor glyph: W = white outline, B = black interior, . = transparent.}
      CursorGlyph:array[0..9] of String[8]=
        ('W.......',
         'WW......',
         'WWW.....',
         'WWWW....',
         'WWWWW...',
         'WWWWWW..',
         'WWWWWWW.',
         'WWWWW...',
         'WW.WW...',
         'W...WW..');
var Saved:array[0..9,0..4] of Byte;
    SavedX,SavedY,FirstByte,Top,Width,Height:Integer; Visible:Boolean;

function CursorOverlaps(X1,Y1,X2,Y2:Integer):Boolean;
begin
  {Include both nibbles of the saved edge bytes.}
  CursorOverlaps:=Visible and (X1<2*(FirstByte+Width)) and
    (X2>=2*FirstByte) and (Y1<Top+Height) and (Y2>=Top);
end;

procedure HideCursor;
var Y:Integer;
begin
  if not Visible then Exit;
  for Y:=0 to Height-1 do WriteVideoBytes(FirstByte,Top+Y,Width,Saved[Y]);
  Visible:=False;
end;

procedure ShowCursor(X,Y:Integer);
var Row:array[0..4] of Byte; I,J,P,L,R,B,SourceY:Integer; C:Byte; Pixel:Char;
begin
  if Visible and (X=SavedX) and (Y=SavedY) then Exit;
  HideCursor;
  if (X< -7) or (X>319) or (Y< -9) or (Y>199) then Exit;
  SavedX:=X; SavedY:=Y;
  L:=X; if L<0 then L:=0;
  R:=X+7; if R>319 then R:=319;
  Top:=Y; if Top<0 then Top:=0;
  B:=Y+9; if B>199 then B:=199;
  FirstByte:=L div 2; Width:=R div 2-FirstByte+1; Height:=B-Top+1;
  for J:=0 to Height-1 do
  begin
    ReadVideoBytes(FirstByte,Top+J,Width,Saved[J]);
    Move(Saved[J],Row,Width);
    SourceY:=Top+J-Y;
    for P:=L to R do
    begin
      Pixel:=CursorGlyph[SourceY][P-X+1];
      if Pixel<>'.' then
      begin
        if Pixel='B' then C:=0 else C:=15;
        I:=P div 2-FirstByte;
        if Odd(P) then Row[I]:=(Row[I] and $F0) or C
        else Row[I]:=(Row[I] and $0F) or (C shl 4);
      end;
    end;
    WriteVideoBytes(FirstByte,Top+J,Width,Row);
  end;
  Visible:=True;
end;
begin Visible:=False end.
