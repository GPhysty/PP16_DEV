unit TVideo;
{$mode tp}{$H-}{$R+}{$Q+}
{$asmmode intel}
{Mode 9 addressing and nibble algorithms adapted from GRAFIX 2.60,
 Joseph A. Albrecht. Original notices retained in docs/CREDITS.md.
 All rectangles/spans have INCLUSIVE endpoints. Reversed ranges are empty.}
interface
const ScreenWidth=320; ScreenHeight=200; VideoSeg=$B800;
type TRow = array[0..159] of Byte;
     TSavedArea = array[0..12287] of Byte;
var GraphicsActive: Boolean;
procedure EnterGraphics;
procedure LeaveGraphics;
procedure PutPixel(X,Y:Integer; Color:Byte);
function GetPixel(X,Y:Integer):Byte;
procedure HSpan(X1,X2,Y:Integer; Color:Byte);
procedure FillBox(X1,Y1,X2,Y2:Integer; Color:Byte);
procedure Text8(X,Y:Integer; const S:String; Color:Byte);
function PixelOffset(X,Y:Word):Word;
function SaveArea(X1,Y1,X2,Y2:Integer; var Data:TSavedArea):Boolean;
procedure RestoreArea(X1,Y1,X2,Y2:Integer; var Data:TSavedArea);
procedure ReadVideoBytes(XByte,Y,Count:Word; var Data);
procedure WriteVideoBytes(XByte,Y,Count:Word; var Data);
procedure DrawBorder(X1,Y1,X2,Y2:Integer; C:Byte);
implementation
uses Dos;
var Lines:array[0..199] of Word;
    OldMode:Byte;

{$ifndef PP16_BYTE_COPY}
procedure CopyRow(SourceSeg,SourceOffset,DestSeg,DestOffset,Count:Word); assembler;
asm
  {Explicit segments: System.Move's near parameters cannot address video RAM.
   Preserve both data segments, string registers, count and direction flag.}
  pushf
  push ds
  push es
  push si
  push di
  push cx
  push ax
  mov ax,SourceSeg
  mov si,SourceOffset
  mov es,DestSeg
  mov di,DestOffset
  mov cx,Count
  mov ds,ax
  cld
  rep movsb
  pop ax
  pop cx
  pop di
  pop si
  pop es
  pop ds
  popf
end;
{$endif}

procedure FillVideo(A,Count:Word; Color:Byte); assembler;
asm
  pushf
  push es
  push di
  push cx
  push ax
  mov ax,$B800
  mov es,ax
  mov di,A
  mov cx,Count
  mov al,Color
  cld
  rep stosb
  pop ax
  pop cx
  pop di
  pop es
  popf
end;

type TByteRow = array[0..159] of Byte;

procedure ReadVideoBytes(XByte,Y,Count:Word; var Data);
{$ifdef PP16_BYTE_COPY}var I:Word;{$endif}
begin
  if (XByte>159) or (Y>199) or (Count=0) or (Count>160-XByte) then Exit;
  {$ifdef PP16_BYTE_COPY}
  for I:=0 to Count-1 do TByteRow(Data)[I]:=Mem[VideoSeg:Lines[Y]+XByte+I];
  {$else}
  CopyRow(VideoSeg,Lines[Y]+XByte,Seg(Data),Ofs(Data),Count);
  {$endif}
end;

procedure WriteVideoBytes(XByte,Y,Count:Word; var Data);
{$ifdef PP16_BYTE_COPY}var I:Word;{$endif}
begin
  if (XByte>159) or (Y>199) or (Count=0) or (Count>160-XByte) then Exit;
  {$ifdef PP16_BYTE_COPY}
  for I:=0 to Count-1 do Mem[VideoSeg:Lines[Y]+XByte+I]:=TByteRow(Data)[I];
  {$else}
  CopyRow(Seg(Data),Ofs(Data),VideoSeg,Lines[Y]+XByte,Count);
  {$endif}
end;

function SaveArea(X1,Y1,X2,Y2:Integer; var Data:TSavedArea):Boolean;
var Y:Integer; W,N,A,I:Word;
begin
  SaveArea:=False;
  if (X1<0) or (Y1<0) or (X2>319) or (Y2>199) or
     (X1>X2) or (Y1>Y2) then Exit;
  W:=Word(X2 div 2-X1 div 2+1);
  if DWord(W)*DWord(Y2-Y1+1)>SizeOf(Data) then Exit;
  N:=0;
  for Y:=Y1 to Y2 do
  begin
    A:=Lines[Y]+Word(X1 div 2);
    {$ifdef PP16_BYTE_COPY}
    for I:=0 to W-1 do Data[N+I]:=Mem[VideoSeg:A+I];
    {$else}
    CopyRow(VideoSeg,A,Seg(Data),Ofs(Data[N]),W);
    {$endif}
    Inc(N,W);
  end;
  SaveArea:=True;
end;

procedure RestoreArea(X1,Y1,X2,Y2:Integer; var Data:TSavedArea);
var Y:Integer; W,N,A,I:Word;
begin
  {Only rectangles successfully captured by SaveArea are passed here.
   Whole bytes include edge neighbors; no background edits occur under popups.}
  W:=Word(X2 div 2-X1 div 2+1); N:=0;
  for Y:=Y1 to Y2 do
  begin
    A:=Lines[Y]+Word(X1 div 2);
    {$ifdef PP16_BYTE_COPY}
    for I:=0 to W-1 do Mem[VideoSeg:A+I]:=Data[N+I];
    {$else}
    CopyRow(Seg(Data),Ofs(Data[N]),VideoSeg,A,W);
    {$endif}
    Inc(N,W);
  end;
end;

function PixelOffset(X,Y:Word):Word;
begin PixelOffset:=(Y and 3)*8192+(Y shr 2)*160+(X shr 1) end;

procedure DrawBorder(X1,Y1,X2,Y2:Integer; C:Byte);
var Y:Integer;
begin
  HSpan(X1,X2,Y1,C); HSpan(X1,X2,Y2,C);
  for Y:=Y1+1 to Y2-1 do begin PutPixel(X1,Y,C); PutPixel(X2,Y,C) end;
end;

procedure EnterGraphics;
var R:Registers; Y:Word;
begin
  FillChar(R,SizeOf(R),0); R.AH:=$0F; Intr($10,R); OldMode:=R.AL;
  R.AX:=9; Intr($10,R);
  {GRAF page zero: APage=DPage=3, PageShift=1, Reg3DF=C0 -> F6.
   Select CPU and display banks 6/7: physical 98000..9FFFF on 640K HX.}
  Port[$3DF]:=$F6;
  for Y:=0 to 199 do Lines[Y]:=PixelOffset(0,Y);
  GraphicsActive:=True;
end;

procedure LeaveGraphics;
var R:Registers;
begin
  if GraphicsActive then
  begin
    FillChar(R,SizeOf(R),0);
    if OldMode in [0,1,2,3,7] then R.AX:=OldMode else R.AX:=3;
    Intr($10,R); GraphicsActive:=False;
  end;
end;

procedure PutPixel(X,Y:Integer; Color:Byte);
var A:Word; B:Byte;
begin
  if (X<0) or (X>319) or (Y<0) or (Y>199) then Exit;
  A:=Lines[Y]+Word(X shr 1); B:=Mem[VideoSeg:A]; Color:=Color and 15;
  if (X and 1)=0 then B:=(B and $0F) or (Color shl 4)
  else B:=(B and $F0) or Color;
  Mem[VideoSeg:A]:=B;
end;

function GetPixel(X,Y:Integer):Byte;
var B:Byte;
begin
  GetPixel:=0;
  if (X<0) or (X>319) or (Y<0) or (Y>199) then Exit;
  B:=Mem[VideoSeg:Lines[Y]+Word(X shr 1)];
  if (X and 1)=0 then GetPixel:=B shr 4 else GetPixel:=B and 15;
end;

procedure HSpan(X1,X2,Y:Integer; Color:Byte);
var A,Count:Word; B:Byte;
begin
  if (Y<0) or (Y>199) or (X1>X2) or (X2<0) or (X1>319) then Exit;
  if X1<0 then X1:=0; if X2>319 then X2:=319;
  Color:=Color and 15;
  if Odd(X1) then begin PutPixel(X1,Y,Color); Inc(X1) end;
  if not Odd(X2) then begin PutPixel(X2,Y,Color); Dec(X2) end;
  if X1>X2 then Exit;
  A:=Lines[Y]+Word(X1 shr 1); Count:=Word((X2-X1+1) shr 1);
  B:=Color or (Color shl 4);
  {$ifdef PP16_BYTE_COPY}
  while Count<>0 do begin Mem[VideoSeg:A]:=B; Inc(A); Dec(Count) end;
  {$else}
  FillVideo(A,Count,B);
  {$endif}
end;

procedure FillBox(X1,Y1,X2,Y2:Integer; Color:Byte);
var Y:Integer;
begin
  if (Y1>Y2) or (Y2<0) or (Y1>199) then Exit;
  if Y1<0 then Y1:=0; if Y2>199 then Y2:=199;
  for Y:=Y1 to Y2 do HSpan(X1,X2,Y,Color);
end;

procedure Text8(X,Y:Integer; const S:String; Color:Byte);
var I,Row,Col:Integer; Bits:Byte; A:Word;
begin
  {The PC/Tandy BIOS ROM's ASCII 8x8 glyphs, no VGA font call.}
  for I:=1 to Length(S) do
  begin
    if (Ord(S[I])>=32) and (Ord(S[I])<=126) then
    begin
      A:=$FA6E+Word(Ord(S[I]))*8;
      for Row:=0 to 7 do
      begin
        Bits:=Mem[$F000:A+Word(Row)];
        for Col:=0 to 7 do
          if (Bits and ($80 shr Col))<>0 then PutPixel(X+Col,Y+Row,Color);
      end;
    end;
    if X>319-8 then Exit;
    X:=X+8;
  end;
end;
begin GraphicsActive:=False end.
