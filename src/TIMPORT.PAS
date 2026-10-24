unit TImport;
{$mode tp}{$H-}{$R+}{$Q+}
interface
uses TDoc;
type TImportCancel=function:Boolean;
     TImportError=String[48];
var ImportError:TImportError;
function InspectImport(const Name:String; Selected:Word;
                       var Count,W,H:Word):Boolean;
function ResolveImportPalette(const Image,Requested:String):String;
function ReadImported(const Name,PaletteName:String; Selected:Word;
                      var Pixels:TDocPixels; Cancel:TImportCancel):Boolean;
implementation
uses Dos,TConvert;
var InputFile:File; InputSize,Position,Limit:LongInt;
    Buffer:array[0..255] of Byte; BufferAt,BufferCount:Word;

procedure Error(const S:String);
begin ImportError:=S end;

function OpenInput(const Name:String):Boolean;
var E:Word; OldMode:Byte;
begin
  OpenInput:=False; Assign(InputFile,Name); OldMode:=FileMode; FileMode:=0;
  {$I-} Reset(InputFile,1); E:=IOResult; {$I+} FileMode:=OldMode;
  if E<>0 then begin Error('CANNOT OPEN IMPORT FILE / PALETTE'); Exit end;
  {$I-} InputSize:=FileSize(InputFile); E:=IOResult; {$I+}
  if E<>0 then begin
    {$I-} Close(InputFile); E:=IOResult; {$I+}
    Error('CANNOT READ IMPORT FILE LENGTH'); Exit;
  end;
  OpenInput:=True;
end;

function CloseInput(OK:Boolean):Boolean;
var E:Word;
begin
  {$I-} Close(InputFile); E:=IOResult; {$I+}
  if E<>0 then begin if OK then Error('CANNOT CLOSE IMPORT FILE'); OK:=False end;
  CloseInput:=OK;
end;

function SeekInput(P,EndPos:LongInt):Boolean;
var E:Word;
begin
  SeekInput:=False;
  if (P<0) or (EndPos<P) or (EndPos>InputSize) then begin Error('INVALID IMPORT BOUNDS'); Exit end;
  {$I-} Seek(InputFile,P); E:=IOResult; {$I+}
  if E<>0 then begin Error('CANNOT SEEK IMPORT FILE'); Exit end;
  Position:=P; Limit:=EndPos; BufferAt:=0; BufferCount:=0; SeekInput:=True;
end;

function ReadByte(var B:Byte):Boolean;
var Wanted,N,E:Word;
begin
  ReadByte:=False;
  if Position>=Limit then begin Error('TRUNCATED IMPORT DATA'); Exit end;
  if BufferAt=BufferCount then begin
    Wanted:=256; if Limit-Position<256 then Wanted:=Word(Limit-Position);
    {$I-} BlockRead(InputFile,Buffer,Wanted,N); E:=IOResult; {$I+}
    if (E<>0) or (N<>Wanted) then begin Error('IMPORT READ FAILED'); Exit end;
    BufferAt:=0; BufferCount:=N;
  end;
  B:=Buffer[BufferAt]; Inc(BufferAt); Inc(Position); ReadByte:=True;
end;

function Cancelled(Cancel:TImportCancel):Boolean;
begin
  Cancelled:=False;
  if Assigned(Cancel) then if Cancel then begin
    Error('IMPORT CANCELLED'); Cancelled:=True;
  end;
end;

function IsPCX(const Name:String):Boolean;
begin IsPCX:=Copy(Name,Length(Name)-3,4)='.PCX' end;

function GetWord(L,H:Byte):Word;
begin GetWord:=Word(L) or (Word(H) shl 8) end;

function PCXHeader(var W,H,Stride:Word; var PixelEnd:LongInt; var Bits:Byte):Boolean;
var Header:array[0..127] of Byte; I:Integer; X1,Y1,X2,Y2,RowBytes:Word;
    B:Byte; S:String[3];
begin
  PCXHeader:=False;
  if InputSize<128 then begin Error('PCX HEADER IS TRUNCATED'); Exit end;
  if not SeekInput(0,InputSize) then Exit;
  for I:=0 to 127 do if not ReadByte(Header[I]) then Exit;
  if Header[0]<>10 then begin Error('NOT A PCX FILE'); Exit end;
  if Header[1]<>5 then begin
    Str(Header[1],S); Error('PCX VERSION '+S+' IS UNSUPPORTED (NEED 5)'); Exit;
  end;
  if Header[2]<>1 then begin Error('PCX MUST USE RLE COMPRESSION'); Exit end;
  if Header[65]<>1 then begin
    Str(Header[65],S); Error('PCX HAS '+S+' PLANES; NEED ONE'); Exit;
  end;
  Bits:=Header[3];
  if not (Bits in [4,8]) then begin
    Str(Bits,S); Error('PCX USES '+S+' BITS; NEED 4 OR 8'); Exit;
  end;
  X1:=GetWord(Header[4],Header[5]); Y1:=GetWord(Header[6],Header[7]);
  X2:=GetWord(Header[8],Header[9]); Y2:=GetWord(Header[10],Header[11]);
  if (X2<X1) or (Y2<Y1) then begin Error('INVALID PCX DIMENSIONS'); Exit end;
  if (X2-X1>=64) or (Y2-Y1>=64) then begin Error('IMAGE MUST BE AT MOST 64 X 64'); Exit end;
  W:=X2-X1+1; H:=Y2-Y1+1; Stride:=GetWord(Header[66],Header[67]);
  RowBytes:=W; if Bits=4 then RowBytes:=(W+1) shr 1;
  if (Stride<RowBytes) or Odd(Stride) then begin Error('INVALID PCX BYTES PER LINE'); Exit end;
  PixelEnd:=InputSize;
  if Bits=4 then begin
    {The caller reads the sixteen RGB entries embedded in the PCX header.}
    PCXHeader:=SeekInput(16,64); Exit;
  end;
  if InputSize<898 then begin Error('PCX 256-COLOR PALETTE IS TRUNCATED'); Exit end;
  PixelEnd:=InputSize-769;
  if not SeekInput(PixelEnd,InputSize) then Exit;
  if not ReadByte(B) then Exit;
  if B<>12 then begin Error('MISSING PCX 256-COLOR PALETTE'); Exit end;
  PCXHeader:=True;
end;

function PUTIndex(Selected:Word; var Count,W,H:Word; var Start:LongInt):Boolean;
var Header:array[0..6] of Byte; I:Integer; Bits,Height,Width:Word;
    P,Payload,Bytes,RecordSize:LongInt;
begin
  PUTIndex:=False; Count:=0; W:=0; H:=0; Start:=-1;
  if not SeekInput(0,InputSize) then Exit;
  for I:=0 to 6 do if not ReadByte(Header[I]) then Exit;
  Payload:=GetWord(Header[5],Header[6]);
  if Payload=0 then Payload:=65536;
  if (Header[0]<>$FD) or (InputSize<>Payload+7) then begin
    Error('INVALID PUT BLOAD HEADER / LENGTH'); Exit;
  end;
  P:=7;
  while P<InputSize do begin
    if (InputSize-P<4) or (Count=1000) then begin Error('INVALID PUT IMAGE RECORDS'); Exit end;
    if not SeekInput(P,InputSize) then Exit;
    for I:=0 to 3 do if not ReadByte(Header[I]) then Exit;
    Bits:=GetWord(Header[0],Header[1]); Height:=GetWord(Header[2],Header[3]);
    if (Bits=0) or (Bits>$7FFF) or ((Bits and 7)<>0) or
       (Height=0) or (Height>$7FFF) then begin Error('INVALID PUT IMAGE DESCRIPTOR'); Exit end;
    Width:=Bits shr 3;
    if LongInt(Width)>(InputSize-P-4) div Height then begin Error('TRUNCATED PUT IMAGE RECORD'); Exit end;
    {Bounded above by the file length. Unsigned multiply avoids the defective
     checked signed LongInt helper for valid products above 32767.}
    Bytes:=LongInt(DWord(Width)*DWord(Height)); RecordSize:=4+Bytes+(Bytes and 1);
    if RecordSize>InputSize-P then begin Error('MISSING PUT RECORD ALIGNMENT BYTE'); Exit end;
    Inc(Count);
    if Count=Selected then begin Start:=P+4; W:=Width; H:=Height end;
    P:=P+RecordSize;
  end;
  if (Count=0) or (Start<0) then begin Error('PUT IMAGE NUMBER OUT OF RANGE'); Exit end;
  PUTIndex:=True;
end;

function InspectImport(const Name:String; Selected:Word; var Count,W,H:Word):Boolean;
var OK:Boolean; Stride:Word; P:LongInt; Bits:Byte;
begin
  InspectImport:=False; ImportError:=''; Count:=0; W:=0; H:=0;
  if not OpenInput(Name) then Exit;
  if IsPCX(Name) then begin
    OK:=PCXHeader(W,H,Stride,P,Bits); Count:=1;
    if OK and (Selected<>1) then begin Error('PCX CONTAINS ONE IMAGE'); OK:=False end;
  end else OK:=PUTIndex(Selected,Count,W,H,P);
  InspectImport:=CloseInput(OK);
end;

function RegularFile(const Name:String):Boolean;
var S:SearchRec;
begin
  FindFirst(Name,AnyFile,S); RegularFile:=(DosError=0) and ((S.Attr and $18)=0);
end;

function ResolveImportPalette(const Image,Requested:String):String;
var Name:String[64];
begin
  if Requested='' then Name:=Copy(Image,1,Length(Image)-4)+'.APF'
  else Name:=Requested;
  ResolveImportPalette:='';
  if RegularFile(Name) then ResolveImportPalette:=Name
  else if RegularFile('PALETTES\'+Name) then ResolveImportPalette:='PALETTES\'+Name
  else if RegularFile('..\PALETTES\'+Name) then ResolveImportPalette:='..\PALETTES\'+Name;
end;

function PUTPalette(const Name:String; var Palette:TPalette):Boolean;
var I,C:Integer; B:Byte; OK:Boolean;
begin
  PUTPalette:=False;
  if Name='' then begin Error('PALETTE NEEDED: CHOOSE APF OR PAL'); Exit end;
  if not OpenInput(Name) then Exit;
  OK:=False;
  if InputSize<>1024 then Error('APF / PAL MUST BE 1024 BYTES')
  else if SeekInput(0,InputSize) then begin
    OK:=True;
    for I:=0 to 255 do begin
      for C:=0 to 3 do begin
        if not ReadByte(B) then begin OK:=False; Break end;
        if ((C<3) and (B>63)) or ((C=3) and (B<>0)) then begin
          Error('INVALID VGA DAC PALETTE ENTRY'); OK:=False; Break;
        end;
        if C<3 then Palette[I,C]:=Byte((Word(B)*255+31) div 63);
      end;
      if not OK then Break;
    end;
  end;
  PUTPalette:=CloseInput(OK);
end;

function ConvertInput(var State:TConvertState; PCXBits:Byte; W,H,Stride:Word; Start,EndPos:LongInt;
                      var Pixels:TDocPixels; Cancel:TImportCancel):Boolean;
var Row:TIndexRow; PackedRow:TPackedRow; X,Y,I,J,RowBytes,Run,SincePoll:Word; B,V:Byte;
begin
  ConvertInput:=False;
  if (W<1) or (W>64) or (H<1) or (H>64) then begin Error('IMAGE MUST BE AT MOST 64 X 64'); Exit end;
  if Cancelled(Cancel) or not SeekInput(Start,EndPos) then Exit;
  FillChar(Pixels,SizeOf(Pixels),0); PreparePalette(State); BeginImage(State,W);
  RowBytes:=W; if PCXBits=4 then RowBytes:=(W+1) shr 1;
  for Y:=0 to H-1 do begin
    FillChar(Row,SizeOf(Row),0); X:=0; SincePoll:=0;
    while X<Stride do begin
      if not ReadByte(B) then Exit;
      Run:=1; V:=B;
      if (PCXBits<>0) and ((B and $C0)=$C0) then begin
        Run:=B and $3F;
        if Run=0 then begin Error('INVALID ZERO-LENGTH PCX RUN'); Exit end;
        if not ReadByte(V) then Exit;
      end;
      if Run>Stride-X then begin Error('PCX RUN CROSSES SCANLINE'); Exit end;
      for I:=1 to Run do begin
        if X<RowBytes then
          if PCXBits=4 then begin
            J:=X shl 1; Row[J]:=V shr 4;
            if J+1<W then Row[J+1]:=V and 15;
          end else Row[X]:=V;
        Inc(X);
      end;
      Inc(SincePoll,Run);
      if SincePoll>=256 then begin
        SincePoll:=0; if Cancelled(Cancel) then Exit;
      end;
    end;
    ConvertRow(State,Row,PackedRow); Move(PackedRow,Pixels[Y*32],32);
    if Cancelled(Cancel) then Exit;
  end;
  if Position<>EndPos then begin Error('EXTRA IMPORT PIXEL DATA'); Exit end;
  ConvertInput:=True;
end;

function ReadImported(const Name,PaletteName:String; Selected:Word;
                      var Pixels:TDocPixels; Cancel:TImportCancel):Boolean;
var PCX,OK:Boolean; Count,W,H,Stride:Word; Start,EndPos,PixelEnd:LongInt;
    I,C,PaletteLast:Integer; Bits:Byte;
    State:TConvertState;
begin
  ReadImported:=False; ImportError:=''; PCX:=IsPCX(Name);
  if Cancelled(Cancel) then Exit;
  if not PCX then
    if not PUTPalette(ResolveImportPalette(Name,PaletteName),State.SourcePalette) then Exit;
  if not OpenInput(Name) then Exit;
  OK:=False;
  if PCX then begin
    if PCXHeader(W,H,Stride,PixelEnd,Bits) and (Selected=1) then begin
      OK:=True; FillChar(State.SourcePalette,SizeOf(State.SourcePalette),0);
      PaletteLast:=255; if Bits=4 then PaletteLast:=15;
      for I:=0 to PaletteLast do begin
        for C:=0 to 2 do if not ReadByte(State.SourcePalette[I,C]) then begin OK:=False; Break end;
        if not OK then Break;
      end;
      if OK then OK:=ConvertInput(State,Bits,W,H,Stride,128,PixelEnd,Pixels,Cancel);
    end else if ImportError='' then Error('PCX CONTAINS ONE IMAGE');
  end else if PUTIndex(Selected,Count,W,H,Start) then begin
    EndPos:=Start+LongInt(DWord(W)*DWord(H));
    OK:=ConvertInput(State,0,W,H,W,Start,EndPos,Pixels,Cancel);
  end;
  ReadImported:=CloseInput(OK);
end;
end.
