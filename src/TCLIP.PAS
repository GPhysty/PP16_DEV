unit TClip;
{$mode tp}{$H-}{$R+}{$Q+}
interface
uses TDoc,TRaster;
const ClipBytes=2048;
var ClipboardValid,ClipboardEllipse:Boolean;
    ClipboardWidth,ClipboardHeight:Integer;
procedure ClearClipboard;
procedure ClipboardCopy(X,Y,W,H:Integer; Ellipse:Boolean);
procedure ClipboardCut(X,Y,W,H:Integer; Background:Byte; Ellipse:Boolean);
procedure ClipboardPaste(X,Y:Integer; Behind:Boolean; Background:Byte);
procedure ClipboardMirror;
procedure ClipboardRotateClockwise;
procedure ClipboardScale(Grow:Boolean);
function ClipboardPixel(X,Y:Integer):Byte;
procedure ClipboardExport(var Data:TDocPixels);
procedure ClipboardImport(const Data:TDocPixels; W,H:Integer; Ellipse:Boolean);
implementation
type TClipPixels=array[0..ClipBytes-1] of Byte;
var ClipPixels,RotatePixels:TClipPixels;

procedure ClipboardExport(var Data:TDocPixels);
begin Move(ClipPixels,Data,ClipBytes) end;

procedure ClipboardImport(const Data:TDocPixels; W,H:Integer; Ellipse:Boolean);
begin
  {TFiles validates dimensions 1..64 and the complete payload before importing.}
  Move(Data,ClipPixels,ClipBytes);
  ClipboardWidth:=W; ClipboardHeight:=H;
  ClipboardEllipse:=Ellipse; ClipboardValid:=True;
end;

function RowBytes:Integer;
begin RowBytes:=(ClipboardWidth+1) div 2 end;

procedure ClearClipboard;
begin
  ClipboardValid:=False; ClipboardEllipse:=False;
  ClipboardWidth:=0; ClipboardHeight:=0
end;

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

procedure ClipboardCopy(X,Y,W,H:Integer; Ellipse:Boolean);
var I,J,Bytes,L:Integer; Source:TDocRow;
begin
  ClearClipboard;
  if (X<0) or (Y<0) or (W<1) or (H<1) or
     (X+W>DocWidth) or (Y+H>DocHeight) then Exit;
  ClipboardWidth:=W; ClipboardHeight:=H; ClipboardEllipse:=Ellipse;
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
  if Ellipse then for J:=0 to H-1 do begin
    L:=EllipseInset(J,W,H);
    for I:=0 to L-1 do begin ClipSetPixel(I,J,0); ClipSetPixel(W-1-I,J,0) end;
  end;
  ClipboardValid:=True;
end;

procedure ClipboardCut(X,Y,W,H:Integer; Background:Byte; Ellipse:Boolean);
var I,J,L:Integer;
begin
  ClipboardCopy(X,Y,W,H,Ellipse);
  if not ClipboardValid then Exit;
  DocBeginAction;
  for J:=0 to H-1 do begin
    L:=0; if ClipboardEllipse then L:=EllipseInset(J,W,H);
    for I:=L to W-1-L do DocSetPixel(X+I,Y+J,Background);
  end;
  DocCommitAction;
end;

procedure ClipboardPaste(X,Y:Integer; Behind:Boolean; Background:Byte);
var I,J,L:Integer;
begin
  if not ClipboardValid then Exit;
  Background:=Background and 15;
  DocBeginAction;
  for J:=0 to ClipboardHeight-1 do begin
    L:=0; if ClipboardEllipse then
      L:=EllipseInset(J,ClipboardWidth,ClipboardHeight);
    for I:=L to ClipboardWidth-1-L do
    if (X+I>=0) and (Y+J>=0) and (X+I<DocWidth) and (Y+J<DocHeight) then
      if (not Behind) or (DocPixel(X+I,Y+J)=Background) then
        DocSetPixel(X+I,Y+J,BufferPixel(ClipPixels,ClipboardWidth,I,J));
  end;
  DocCommitAction;
end;

procedure TransformClipboard(Kind:Byte);
var X,Y,DX,DY,W,H,NewWidth:Integer;
begin
  if not ClipboardValid then Exit;
  W:=ClipboardWidth; H:=ClipboardHeight;
  if Kind=1 then NewWidth:=H else NewWidth:=W;
  FillChar(RotatePixels,SizeOf(RotatePixels),0);
  for Y:=0 to H-1 do for X:=0 to W-1 do
  begin
    DX:=X; DY:=Y;
    case Kind of
      0:DX:=W-1-X;
      1:begin DX:=H-1-Y; DY:=X end;
    end;
    BufferSetPixel(RotatePixels,NewWidth,DX,DY,BufferPixel(ClipPixels,W,X,Y));
  end;
  Move(RotatePixels,ClipPixels,ClipBytes);
  if Kind=1 then begin ClipboardWidth:=H; ClipboardHeight:=W end;
end;
procedure ClipboardMirror;
begin TransformClipboard(0) end;
procedure ClipboardRotateClockwise;
begin TransformClipboard(1) end;

procedure ClipboardScale(Grow:Boolean);
var X,Y,SX,SY,W,H,NW,NH,L,SourceL:Integer;
begin
  if not ClipboardValid then Exit;
  W:=ClipboardWidth; H:=ClipboardHeight;
  NW:=W; NH:=H;
  if Grow then
  begin
    if NW<64 then Inc(NW);
    if NH<64 then Inc(NH);
  end
  else
  begin
    if NW>1 then Dec(NW);
    if NH>1 then Dec(NH);
  end;
  if (NW=W) and (NH=H) then Exit;
  FillChar(RotatePixels,SizeOf(RotatePixels),0);
  for Y:=0 to NH-1 do
  begin
    SY:=((2*Y+1)*H) div (2*NH); L:=0; SourceL:=0;
    if ClipboardEllipse then
    begin
      L:=EllipseInset(Y,NW,NH);
      SourceL:=EllipseInset(SY,W,H);
      while W<=2*SourceL do
      begin
        if SY<H div 2 then Inc(SY) else Dec(SY);
        SourceL:=EllipseInset(SY,W,H);
      end;
    end;
    for X:=L to NW-1-L do
    begin
      if ClipboardEllipse then
        SX:=SourceL+((2*(X-L)+1)*(W-2*SourceL)) div (2*(NW-2*L))
      else SX:=((2*X+1)*W) div (2*NW);
      BufferSetPixel(RotatePixels,NW,X,Y,BufferPixel(ClipPixels,W,SX,SY));
    end;
  end;
  Move(RotatePixels,ClipPixels,ClipBytes);
  ClipboardWidth:=NW; ClipboardHeight:=NH;
end;
end.
