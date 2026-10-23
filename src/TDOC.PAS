unit TDoc;
{$mode tp}{$H-}{$R+}{$Q+}
interface
const DocWidth=64; DocHeight=64; DocBytes=2048;
type TDocPixels=array[0..DocBytes-1] of Byte;
     TDocRow=array[0..31] of Byte;
var DocDirty:Boolean;
procedure DocCopy(var Data:TDocPixels);
procedure DocReadRow(Y:Integer; var Row:TDocRow);
procedure DocReplace(const Data:TDocPixels);
procedure DocSaved;
function DocCanUndo:Boolean;
procedure DocBeginAction;
procedure DocCommitAction;
procedure DocCancelAction;
procedure DocUndo;
procedure DocClear(C:Byte);
procedure InitDemoDoc;
procedure InitBlankDoc(C:Byte);
function DocSetPixel(X,Y:Integer; C:Byte):Boolean;
procedure DocBrush(X,Y:Integer; C:Byte; Size:Integer);
procedure DocLine(X1,Y1,X2,Y2:Integer; C:Byte; Size:Integer);
procedure DocSquare(X1,Y1,X2,Y2:Integer; C:Byte; Size:Integer);
procedure DocCircle(X1,Y1,X2,Y2:Integer; C:Byte; Size:Integer);
function DocFloodFill(X,Y:Integer; C:Byte):Boolean;
function TakeDirtyRow(Y:Integer; var X1,X2:Integer):Boolean;
function DocAllDirty:Boolean;
function DocPixel(X,Y:Integer):Byte;
function DocChecksum:DWord;
implementation
uses TRaster;
var Pixels:array[0..DocBytes-1] of Byte;
    UndoPixels,PendingPixels:array[0..DocBytes-1] of Byte;
    UndoValid,UndoDirty,ActionActive,ActionChanged,PendingDirty:Boolean;
    DirtyFirst,DirtyLast:array[0..63] of Integer;
    {A 12-bit packed stack holds every possible document coordinate using
     6,144 bytes, rather than 8,192 bytes for 4,096 Words. Pixels are changed
     when queued, so no coordinate can be queued more than once.}
    FillStack:array[0..6143] of Byte;
    FillCount:Word; StampSize:Integer;

procedure ResetDirty;
var Y:Integer;
begin
  DocDirty:=False;
  UndoValid:=False; ActionActive:=False; ActionChanged:=False;
  for Y:=0 to 63 do begin DirtyFirst[Y]:=64; DirtyLast[Y]:=-1 end;
end;

procedure MarkAll;
var Y:Integer;
begin
  for Y:=0 to 63 do begin DirtyFirst[Y]:=0; DirtyLast[Y]:=63 end;
end;

function DocCanUndo:Boolean;
begin DocCanUndo:=UndoValid and not ActionActive end;

procedure DocCopy(var Data:TDocPixels);
begin Move(Pixels,Data,DocBytes) end;

procedure DocReadRow(Y:Integer; var Row:TDocRow);
begin
  if (Y<0) or (Y>=DocHeight) then FillChar(Row,SizeOf(Row),0)
  else Move(Pixels[Word(Y)*32],Row,SizeOf(Row));
end;

procedure DocReplace(const Data:TDocPixels);
begin Move(Data,Pixels,DocBytes); ResetDirty; MarkAll end;

procedure DocSaved;
begin
  DocDirty:=False;
  UndoDirty:=UndoValid and (CompareByte(Pixels,UndoPixels,DocBytes)<>0);
end;

procedure DocBeginAction;
begin
  if ActionActive then Exit;
  ActionActive:=True; ActionChanged:=False;
end;

procedure DocCommitAction;
begin
  if not ActionActive then Exit;
  if ActionChanged then
  begin
    Move(PendingPixels,UndoPixels,DocBytes);
    UndoDirty:=PendingDirty; UndoValid:=True;
  end;
  ActionActive:=False; ActionChanged:=False;
end;

procedure DocCancelAction;
begin
  if not ActionActive then Exit;
  if ActionChanged then
  begin
    Move(PendingPixels,Pixels,DocBytes); DocDirty:=PendingDirty; MarkAll;
  end;
  ActionActive:=False; ActionChanged:=False;
end;

procedure DocUndo;
begin
  if not DocCanUndo then Exit;
  Move(UndoPixels,Pixels,DocBytes); DocDirty:=UndoDirty;
  UndoValid:=False; MarkAll;
end;

procedure DocClear(C:Byte);
var I:Word; B:Byte;
begin
  if ActionActive then Exit;
  C:=C and 15; B:=C or (C shl 4);
  {A uniform document is a no-op: preserve its dirty flag and prior undo.}
  for I:=0 to DocBytes-1 do if Pixels[I]<>B then
  begin
    Move(Pixels,UndoPixels,DocBytes);
    UndoDirty:=DocDirty; UndoValid:=True;
    FillChar(Pixels,DocBytes,B); DocDirty:=True;
    MarkAll; Exit;
  end;
end;

procedure InitBlankDoc(C:Byte);
begin
  C:=C and 15; FillChar(Pixels,SizeOf(Pixels),C or (C shl 4)); ResetDirty;
end;

procedure SetPixel(X,Y:Integer; C:Byte);
var A:Word;
begin
  A:=Word(Y)*32+Word(X div 2);
  if Odd(X) then Pixels[A]:=(Pixels[A] and $F0) or C
  else Pixels[A]:=(Pixels[A] and $0F) or (C shl 4);
end;

procedure InitDemoDoc;
var X,Y,DX,DY,D:Integer; C:Byte;
begin
  {Original fixed fixture: a small sunset planet against a star field.
   Row-major packed high-nibble-first data, independent of video RAM.}
  FillChar(Pixels,SizeOf(Pixels),0);
  for Y:=0 to 63 do for X:=0 to 63 do
  begin
    C:=0;
    if ((X*13+Y*7) mod 113=0) then C:=7;
    DX:=X-32; DY:=Y-31; D:=DX*DX+DY*DY;
    if D<=256 then C:=1;
    if D<=196 then
    begin
      if Y<25 then C:=14 else if Y<31 then C:=6
      else if Y<37 then C:=12 else C:=4;
      if (Y>=36) and (Y>43-Abs(X-28)) then C:=0;
      if (Y>=39) and (Y<43) then C:=3;
    end;
    SetPixel(X,Y,C);
  end;
  ResetDirty;
end;

function DocSetPixel(X,Y:Integer; C:Byte):Boolean;
begin
  DocSetPixel:=False;
  if (X<0) or (Y<0) or (X>=64) or (Y>=64) then Exit;
  C:=C and 15;
  if DocPixel(X,Y)=C then Exit;
  {Capture lazily: a no-change gesture must not replace the previous undo.
   A separate pending snapshot preserves that undo if the gesture cancels.}
  if ActionActive and not ActionChanged then
  begin
    Move(Pixels,PendingPixels,DocBytes); PendingDirty:=DocDirty;
    ActionChanged:=True;
  end;
  SetPixel(X,Y,C); DocDirty:=True;
  if X<DirtyFirst[Y] then DirtyFirst[Y]:=X;
  if X>DirtyLast[Y] then DirtyLast[Y]:=X;
  DocSetPixel:=True;
end;

procedure PlotDoc(X,Y,C:Integer);
begin
  DocSetPixel(X,Y,C);
end;

function ValidStampSize(Size:Integer):Integer;
begin
  if Size<1 then ValidStampSize:=1
  else if Size>5 then ValidStampSize:=5
  else ValidStampSize:=Size;
end;

procedure PlotDocStamp(X,Y,C:Integer);
begin
  RasterStamp(X,Y,C,StampSize,PlotDoc);
end;

procedure DocBrush(X,Y:Integer; C:Byte; Size:Integer);
begin
  RasterStamp(X,Y,C,ValidStampSize(Size),PlotDoc);
end;

procedure DocLine(X1,Y1,X2,Y2:Integer; C:Byte; Size:Integer);
begin
  if (X1<0) or (X1>63) or (X2<0) or (X2>63) or
     (Y1<0) or (Y1>63) or (Y2<0) or (Y2>63) then Exit;
  StampSize:=ValidStampSize(Size);
  RasterLine(X1,Y1,X2,Y2,C,PlotDocStamp);
end;

procedure DocSquare(X1,Y1,X2,Y2:Integer; C:Byte; Size:Integer);
begin
  StampSize:=ValidStampSize(Size);
  RasterSquare(X1,Y1,X2,Y2,C,PlotDocStamp);
end;

procedure DocCircle(X1,Y1,X2,Y2:Integer; C:Byte; Size:Integer);
begin
  StampSize:=ValidStampSize(Size);
  RasterCircle(X1,Y1,X2,Y2,C,PlotDocStamp);
end;

procedure FillPush(P:Word);
var O:Word;
begin
  O:=(FillCount shr 1)*3;
  if Odd(FillCount) then
  begin
    FillStack[O+1]:=(FillStack[O+1] and $0F) or Byte((P and $0F) shl 4);
    FillStack[O+2]:=P shr 4;
  end else
  begin
    FillStack[O]:=P and $FF;
    FillStack[O+1]:=(FillStack[O+1] and $F0) or Byte(P shr 8);
  end;
  Inc(FillCount);
end;

function FillPop:Word;
var O:Word;
begin
  Dec(FillCount); O:=(FillCount shr 1)*3;
  if Odd(FillCount) then FillPop:=(Word(FillStack[O+2]) shl 4) or
                                      (FillStack[O+1] shr 4)
  else FillPop:=Word(FillStack[O]) or (Word(FillStack[O+1] and $0F) shl 8);
end;

function DocFloodFill(X,Y:Integer; C:Byte):Boolean;
var Old:Byte; P:Word; WasActive:Boolean;

  procedure Add(NX,NY:Integer);
  begin
    if (NX<0) or (NX>=64) or (NY<0) or (NY>=64) then Exit;
    if DocPixel(NX,NY)<>Old then Exit;
    DocSetPixel(NX,NY,C);
    {At most all 4,096 pixels are queued, which exactly fits the stack.}
    FillPush(Word(NY)*64+NX);
  end;

begin
  DocFloodFill:=False;
  if (X<0) or (X>=64) or (Y<0) or (Y>=64) then Exit;
  C:=C and 15; Old:=DocPixel(X,Y);
  if Old=C then Exit;
  WasActive:=ActionActive;
  if not WasActive then DocBeginAction;
  FillCount:=0; Add(X,Y);
  while FillCount<>0 do
  begin
    P:=FillPop; X:=P and 63; Y:=P shr 6;
    Add(X-1,Y); Add(X+1,Y); Add(X,Y-1); Add(X,Y+1);
  end;
  if not WasActive then DocCommitAction;
  DocFloodFill:=True;
end;

function TakeDirtyRow(Y:Integer; var X1,X2:Integer):Boolean;
begin
  TakeDirtyRow:=False;
  if (Y<0) or (Y>63) then Exit;
  X1:=DirtyFirst[Y]; X2:=DirtyLast[Y];
  TakeDirtyRow:=X1<=X2;
  DirtyFirst[Y]:=64; DirtyLast[Y]:=-1;
end;

function DocAllDirty:Boolean;
var Y:Integer;
begin
  {Undo and cancellation restore the entire packed document. Let the UI
   recognize that case before it consumes the per-row dirty ranges, so it can
   use packed scanline renderers rather than 4,096 cell updates.}
  DocAllDirty:=True;
  for Y:=0 to DocHeight-1 do
    if (DirtyFirst[Y]<>0) or (DirtyLast[Y]<>DocWidth-1) then
    begin DocAllDirty:=False; Exit end;
end;

function DocPixel(X,Y:Integer):Byte;
var B:Byte;
begin
  DocPixel:=0;
  if (X<0) or (Y<0) or (X>=64) or (Y>=64) then Exit;
  B:=Pixels[Word(Y)*32+Word(X div 2)];
  if Odd(X) then DocPixel:=B and 15 else DocPixel:=B shr 4;
end;

function DocChecksum:DWord;
var I:Word; S:DWord;
begin
  S:=0;
  for I:=0 to DocBytes-1 do S:=S+DWord(Pixels[I])*DWord(I+1);
  DocChecksum:=S;
end;
end.
