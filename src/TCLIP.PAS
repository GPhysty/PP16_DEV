unit TClip;
{$mode tp}{$H-}{$R+}{$Q+}
interface
uses TDoc;
const ClipBytes=2048;
var ClipboardValid:Boolean;
    ClipboardWidth,ClipboardHeight:Integer;
procedure ClearClipboard;
procedure ClipboardCopy(X,Y,W,H:Integer);
procedure ClipboardCut(X,Y,W,H:Integer; Background:Byte);
procedure ClipboardPaste(X,Y:Integer);
procedure ClipboardRotateClockwise;
function ClipboardPixel(X,Y:Integer):Byte;
implementation
type TClipPixels=array[0..ClipBytes-1] of Byte;
var ClipPixels,RotatePixels:TClipPixels;

function RowBytes:Integer;
begin RowBytes:=(ClipboardWidth+1) div 2 end;

procedure ClearClipboard;
begin ClipboardValid:=False; ClipboardWidth:=0; ClipboardHeight:=0 end;

procedure BufferSetPixel(var Data:TClipPixels; Width,X,Y:Integer; C:Byte);
var A:Word;
begin
  A:=Word(Y)*Word((Width+1) div 2)+Word(X div 2); C:=C and 15;
  if Odd(X) then Data[A]:=(Data[A] and $F0) or C
  else Data[A]:=(Data[A] and $0F) or (C shl 4);
end;

function BufferPixel(const Data:TClipPixels; Width,X,Y:Integer):Byte;
var A:Word; B:Byte;
begin
  A:=Word(Y)*Word((Width+1) div 2)+Word(X div 2); B:=Data[A];
  if Odd(X) then BufferPixel:=B and 15 else BufferPixel:=B shr 4;
end;

procedure ClipSetPixel(X,Y:Integer; C:Byte);
begin BufferSetPixel(ClipPixels,ClipboardWidth,X,Y,C) end;

function ClipboardPixel(X,Y:Integer):Byte;
begin
  ClipboardPixel:=0;
  if (not ClipboardValid) or (X<0) or (Y<0) or
     (X>=ClipboardWidth) or (Y>=ClipboardHeight) then Exit;
  ClipboardPixel:=BufferPixel(ClipPixels,ClipboardWidth,X,Y);
end;

procedure ClipboardCopy(X,Y,W,H:Integer);
var I,J,Bytes:Integer; Source:TDocRow;
begin
  ClearClipboard;
  if (X<0) or (Y<0) or (W<1) or (H<1) or
     (X+W>DocWidth) or (Y+H>DocHeight) then Exit;
  ClipboardWidth:=W; ClipboardHeight:=H;
  FillChar(ClipPixels,SizeOf(ClipPixels),0);
  if not Odd(X) and not Odd(W) then
  begin
    Bytes:=W div 2;
    for J:=0 to H-1 do
    begin
      DocReadRow(Y+J,Source);
      Move(Source[X div 2],ClipPixels[J*Bytes],Bytes);
    end;
  end else
    for J:=0 to H-1 do for I:=0 to W-1 do
      ClipSetPixel(I,J,DocPixel(X+I,Y+J));
  ClipboardValid:=True;
end;

procedure ClipboardCut(X,Y,W,H:Integer; Background:Byte);
var I,J:Integer;
begin
  ClipboardCopy(X,Y,W,H);
  if not ClipboardValid then Exit;
  DocBeginAction;
  for J:=0 to H-1 do for I:=0 to W-1 do
    DocSetPixel(X+I,Y+J,Background);
  DocCommitAction;
end;

procedure ClipboardPaste(X,Y:Integer);
var I,J:Integer;
begin
  if not ClipboardValid then Exit;
  DocBeginAction;
  for J:=0 to ClipboardHeight-1 do for I:=0 to ClipboardWidth-1 do
    if (X+I>=0) and (Y+J>=0) and (X+I<DocWidth) and (Y+J<DocHeight) then
      DocSetPixel(X+I,Y+J,ClipboardPixel(I,J));
  DocCommitAction;
end;

procedure ClipboardRotateClockwise;
var X,Y,OldWidth,OldHeight:Integer;
begin
  if not ClipboardValid then Exit;
  OldWidth:=ClipboardWidth; OldHeight:=ClipboardHeight;
  FillChar(RotatePixels,SizeOf(RotatePixels),0);
  for Y:=0 to OldHeight-1 do for X:=0 to OldWidth-1 do
    BufferSetPixel(RotatePixels,OldHeight,OldHeight-1-Y,X,
      BufferPixel(ClipPixels,OldWidth,X,Y));
  Move(RotatePixels,ClipPixels,ClipBytes);
  ClipboardWidth:=OldHeight; ClipboardHeight:=OldWidth;
end;

end.
