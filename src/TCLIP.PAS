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
function ClipboardPixel(X,Y:Integer):Byte;
implementation
var ClipPixels:array[0..ClipBytes-1] of Byte;

function RowBytes:Integer;
begin RowBytes:=(ClipboardWidth+1) div 2 end;

procedure ClearClipboard;
begin ClipboardValid:=False; ClipboardWidth:=0; ClipboardHeight:=0 end;

procedure ClipSetPixel(X,Y:Integer; C:Byte);
var A:Word;
begin
  A:=Word(Y)*RowBytes+Word(X div 2);
  if Odd(X) then ClipPixels[A]:=(ClipPixels[A] and $F0) or C
  else ClipPixels[A]:=(ClipPixels[A] and $0F) or (C shl 4);
end;

function ClipboardPixel(X,Y:Integer):Byte;
var A:Word;
begin
  ClipboardPixel:=0;
  if (not ClipboardValid) or (X<0) or (Y<0) or
     (X>=ClipboardWidth) or (Y>=ClipboardHeight) then Exit;
  A:=Word(Y)*RowBytes+Word(X div 2);
  if Odd(X) then ClipboardPixel:=ClipPixels[A] and 15
  else ClipboardPixel:=ClipPixels[A] shr 4;
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

end.
