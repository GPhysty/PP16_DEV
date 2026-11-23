unit TFiles;
{$mode tp}{$H-}{$R+}{$Q+}
interface
uses TDoc,TImport,TConvert;
type TFileName=String[12];
var CurrentFile:TFileName;
    {Type of the latest normalized I/O request; CurrentFile remains the document.}
    FileIsClip:Boolean;
    FileError:String[48]; RecoveryPath:String[64];
{$ifdef PP16_FILE_TEST}var FileFault:Byte;{$endif}
function NormalizeName(const Input:String; var Name:TFileName):Boolean;
function NormalizeImportName(const Input:String; var Name:TFileName):Boolean;
function NormalizeExportName(const Input:String; var Name:TFileName):Boolean;
function NormalizePaletteName(const Input:String; var Name:TFileName):Boolean;
function ClipName(const Name:String):Boolean;
function Exists(const Name:String):Boolean;
function LoadImage(const Name:TFileName):Boolean;
function ImportImage(const Name:TFileName; ImageNo:Word; const PaletteName:String;
                     Cancel:TImportCancel):Boolean;
function ImportImageWithMethod(const Name:TFileName; ImageNo:Word; const PaletteName:String;
                     Method:TImportMethod; Cancel:TImportCancel):Boolean;
function SaveImage(const Name:TFileName; ReplaceExisting:Boolean):Boolean;
{Both entry points dispatch by extension. CLP never changes document state.}
function ExportPCX(const Name:TFileName; ReplaceExisting:Boolean):Boolean;
implementation
uses Dos,TClip;
type THeader=array[0..19] of Byte;
var Stage:TDocPixels; StageHeader:THeader; StageBytes:Word;

function ClipName(const Name:String):Boolean;
begin ClipName:=Copy(Name,Length(Name)-3,4)='.CLP' end;

procedure Error(const Message:String; Code:Word);
var S:String[6];
begin
  FileError:=Message;
  if Code<>0 then begin Str(Code,S); FileError:=Message+' (DOS '+S+')' end;
end;

function NormalizeKind(const Input:String; var Name:TFileName; Kind:Byte):Boolean;
var S,B:String[12]; I,P:Integer;
begin
  NormalizeKind:=False;
  case Kind of
    0:FileError:='USE 8.3 NAME WITH .P16 OR .CLP';
    1:FileError:='USE 8.3 NAME WITH .PCX OR .PUT';
    2:FileError:='USE 8.3 NAME WITH .APF OR .PAL';
    3:FileError:='USE 8.3 NAME WITH .PCX';
  end;
  if (Length(Input)=0) or (Length(Input)>12) then Exit;
  S:=Input; P:=0;
  for I:=1 to Length(S) do begin
    S[I]:=UpCase(S[I]);
    if S[I]='.' then begin if P<>0 then Exit; P:=I end
    else if not (S[I] in ['A'..'Z','0'..'9','_','-']) then Exit;
  end;
  if P=0 then begin
    if (Length(S)>8) or (Kind=2) then Exit;
    if Kind=0 then S:=S+'.P16' else S:=S+'.PCX'; P:=Length(S)-3;
  end;
  if (P<2) or (P>9) or (Length(S)<>P+3) then Exit;
  case Kind of
    0:if (Copy(S,P,4)<>'.P16') and not ClipName(S) then Exit;
    1:if (Copy(S,P,4)<>'.PCX') and (Copy(S,P,4)<>'.PUT') then Exit;
    2:if (Copy(S,P,4)<>'.APF') and (Copy(S,P,4)<>'.PAL') then Exit;
    3:if Copy(S,P,4)<>'.PCX' then Exit;
  end;
  B:=Copy(S,1,P-1);
  if (B='CON') or (B='PRN') or (B='AUX') or (B='NUL') then Exit;
  if (Length(B)=4) and (B[4] in ['1'..'9']) and
     ((Copy(B,1,3)='COM') or (Copy(B,1,3)='LPT')) then Exit;
  Name:=S; FileError:=''; NormalizeKind:=True;
end;

function NormalizeName(const Input:String; var Name:TFileName):Boolean;
begin NormalizeName:=NormalizeKind(Input,Name,0) end;
function NormalizeImportName(const Input:String; var Name:TFileName):Boolean;
begin NormalizeImportName:=NormalizeKind(Input,Name,1) end;
function NormalizeExportName(const Input:String; var Name:TFileName):Boolean;
begin NormalizeExportName:=NormalizeKind(Input,Name,3) end;
function NormalizePaletteName(const Input:String; var Name:TFileName):Boolean;
begin NormalizePaletteName:=NormalizeKind(Input,Name,2) end;

function Exists(const Name:String):Boolean;
var S:SearchRec;
begin FindFirst(Name,AnyFile,S); Exists:=DosError=0 end;

procedure MakeHeader(W,H,Flags:Byte);
begin
  FillChar(StageHeader,SizeOf(StageHeader),0);
  StageHeader[0]:=$50; StageHeader[1]:=$31; StageHeader[2]:=$36;
  if FileIsClip then begin
    StageHeader[0]:=$43; StageHeader[1]:=$4C; StageHeader[2]:=$50;
  end;
  StageBytes:=((Word(W)+1) div 2)*H;
  StageHeader[3]:=$1A; StageHeader[4]:=1; StageHeader[6]:=20;
  StageHeader[8]:=W; StageHeader[10]:=H; StageHeader[12]:=Flags;
  StageHeader[16]:=Lo(StageBytes); StageHeader[17]:=Hi(StageBytes);
end;

function ReadImage(const Name:String; Verify:Boolean):Boolean;
var F:File; H:THeader; ReadPixels:TDocPixels;
    E,N:Word; Size:LongInt; OK:Boolean; OldMode:Byte;
begin
  ReadImage:=False; Assign(F,Name); OldMode:=FileMode; FileMode:=0;
  {$I-} Reset(F,1); E:=IOResult; {$I+} FileMode:=OldMode;
  if E<>0 then begin Error('CANNOT OPEN FILE',E); Exit end;
  OK:=True;
  {$I-} Size:=FileSize(F); E:=IOResult; {$I+}
  if (E<>0) or (Size<20) then begin Error('WRONG FILE LENGTH',E); OK:=False end;
  if OK then begin
    {$I-} BlockRead(F,H,20,N); E:=IOResult; {$I+}
    if (E<>0) or (N<>20) then begin Error('HEADER READ FAILED',E); OK:=False end;
  end;
  if OK then begin
    if not Verify then begin
      if FileIsClip then begin
        OK:=(H[8] in [1..64]) and (H[10] in [1..64]) and (H[12]<=1);
        MakeHeader(H[8],H[10],H[12]);
      end else MakeHeader(64,64,0);
    end;
    OK:=OK and (CompareByte(H,StageHeader,SizeOf(H))=0) and (Size=20+LongInt(StageBytes));
    if not OK then Error('INVALID FILE HEADER OR LENGTH',0);
  end;
  if OK then begin
    FillChar(ReadPixels,SizeOf(ReadPixels),0);
    {$I-} BlockRead(F,ReadPixels,StageBytes,N); E:=IOResult; {$I+}
    if (E<>0) or (N<>StageBytes) then begin Error('PIXEL READ FAILED',E); OK:=False end;
    if OK then begin
      if Verify then begin
        OK:=CompareByte(ReadPixels,Stage,StageBytes)=0;
        if not OK then Error('SAVED PIXELS DID NOT VERIFY',0);
      end else Move(ReadPixels,Stage,DocBytes);
    end;
  end;
  {$I-} Close(F); E:=IOResult; {$I+}
  if E<>0 then begin Error('CLOSE FAILED',E); OK:=False end;
  ReadImage:=OK;
end;

function LoadImage(const Name:TFileName):Boolean;
var Valid:TFileName;
begin
  LoadImage:=False; FileError:=''; RecoveryPath:='';
  if not NormalizeName(Name,Valid) then Exit;
  FileIsClip:=ClipName(Valid);
  if not ReadImage(Valid,False) then Exit;
  if FileIsClip then ClipboardImport(Stage,StageHeader[8],StageHeader[10],StageHeader[12]<>0)
  else begin DocReplace(Stage); CurrentFile:=Valid end;
  LoadImage:=True;
end;

function ImportImageWithMethod(const Name:TFileName; ImageNo:Word; const PaletteName:String;
                     Method:TImportMethod; Cancel:TImportCancel):Boolean;
var Valid:TFileName;
begin
  ImportImageWithMethod:=False; FileError:='';
  if not NormalizeImportName(Name,Valid) then Exit;
  if not ReadImportedWithMethod(Valid,PaletteName,ImageNo,Stage,Method,Cancel) then begin
    FileError:=ImportError; Exit;
  end;
  if not DocImport(Stage) then begin FileError:='FINISH CURRENT DRAWING ACTION FIRST'; Exit end;
  CurrentFile:=''; FileIsClip:=False; RecoveryPath:=''; ImportImageWithMethod:=True;
end;

function ImportImage(const Name:TFileName; ImageNo:Word; const PaletteName:String;
                     Cancel:TImportCancel):Boolean;
begin
  ImportImage:=ImportImageWithMethod(Name,ImageNo,PaletteName,imDithered,Cancel);
end;

function Directory(const Name:String):Boolean;
var S:SearchRec; E:Word;
begin
  FindFirst(Name,AnyFile,S);
  if DosError=0 then begin
    Directory:=(S.Attr and $10)<>0;
    if (S.Attr and $10)=0 then Error('TRASH PATH IS NOT A DIRECTORY',0);
    Exit;
  end;
  {$I-} MkDir(Name); E:=IOResult; {$I+}
  Directory:=E=0; if E<>0 then Error('CANNOT CREATE TRASH DIRECTORY',E);
end;

function NewSaveFolder:Boolean;
var Y,M,D,DOW,E:Word; I,J:Integer; DateName:String[8]; S:String[5]; Base:String[32];
begin
  NewSaveFolder:=False;
  if not Directory('TRASH') then Exit;
  GetDate(Y,M,D,DOW); Str(Y:4,DateName); Str(M:2,S); DateName:=DateName+S;
  Str(D:2,S); DateName:=DateName+S;
  for J:=1 to 8 do if DateName[J]=' ' then DateName[J]:='0';
  Base:='TRASH\'+DateName;
  if not Directory(Base) then Exit;
  for I:=1 to 9999 do begin
    Str(I:4,S); for J:=1 to 4 do if S[J]=' ' then S[J]:='0';
    RecoveryPath:=Base+'\S'+S;
    if not Exists(RecoveryPath) then begin
      {$I-} MkDir(RecoveryPath); E:=IOResult; {$I+}
      if E<>0 then begin Error('CANNOT CREATE SAVE DIRECTORY',E); Exit end;
      NewSaveFolder:=True; Exit;
    end;
  end;
  Error('TRASH SAVE DIRECTORY LIMIT REACHED',0);
end;

function RenameFile(const OldName,NewName:String):Word;
var F:File;
begin
  Assign(F,OldName); {$I-} Rename(F,NewName); RenameFile:=IOResult; {$I+}
end;

function WritePCX(var F:File):Boolean;
const Palette:array[0..15,0..2] of Byte=(
  (0,0,0),(0,0,170),(0,170,0),(0,170,170),
  (170,0,0),(170,0,170),(170,85,0),(170,170,170),
  (85,85,85),(85,85,255),(85,255,85),(85,255,255),
  (255,85,85),(255,85,255),(255,255,85),(255,255,255));
var Buffer:array[0..768] of Byte; X,Y,Run,Used:Integer; Color:Byte;

  function Pixel(P:Integer):Byte;
  begin
    if Odd(P) then Pixel:=Stage[Y*32+(P shr 1)] and 15
    else Pixel:=Stage[Y*32+(P shr 1)] shr 4;
  end;

  function WriteBlock(Count:Word):Boolean;
  var N,E:Word;
  begin
    {$I-} BlockWrite(F,Buffer,Count,N); E:=IOResult; {$I+}
    WriteBlock:=(E=0) and (N=Count);
    if (E<>0) or (N<>Count) then Error('PCX WRITE FAILED',E);
  end;

begin
  WritePCX:=False; FillChar(Buffer,SizeOf(Buffer),0);
  Buffer[0]:=10; Buffer[1]:=5; Buffer[2]:=1; Buffer[3]:=8;
  Buffer[8]:=63; Buffer[10]:=63; Buffer[12]:=72; Buffer[14]:=72;
  Move(Palette,Buffer[16],SizeOf(Palette));
  Buffer[65]:=1; Buffer[66]:=64; Buffer[68]:=1;
  if not WriteBlock(128) then Exit;
  for Y:=0 to 63 do begin
    X:=0; Used:=0;
    while X<64 do begin
      Color:=Pixel(X); Run:=1;
      while (Run<63) and (X+Run<64) do begin
        if Pixel(X+Run)<>Color then Break;
        Inc(Run);
      end;
      if Run>1 then begin Buffer[Used]:=$C0 or Byte(Run); Inc(Used) end;
      {Document indices are 0..15, so single bytes cannot be RLE markers.}
      Buffer[Used]:=Color; Inc(Used); Inc(X,Run);
    end;
    if not WriteBlock(Used) then Exit;
    {$ifdef PP16_FILE_TEST}
    if FileFault=1 then begin Error('INJECTED PCX WRITE FAILURE',0); Exit end;
    {$endif}
  end;
  FillChar(Buffer,SizeOf(Buffer),0); Buffer[0]:=12;
  Move(Palette,Buffer[1],SizeOf(Palette));
  WritePCX:=WriteBlock(769);
end;

function VerifyPCX(const Name:String):Boolean;
var X,Y:Integer; Expected:Byte;
begin
  VerifyPCX:=False;
  {Reuse the existing staging buffer. The document stays unchanged throughout
   export; another 2 KiB pixel array here would crowd the 8 KiB DOS stack.}
  if not ReadImported(Name,'',1,Stage,nil) then begin
    Error('EXPORTED PCX DID NOT VERIFY',0); Exit;
  end;
  for Y:=0 to 63 do for X:=0 to 31 do begin
    Expected:=(DocPixel(X*2,Y) shl 4) or DocPixel(X*2+1,Y);
    if Stage[Y*32+X]<>Expected then begin
      Error('EXPORTED PIXELS DID NOT VERIFY',0); Exit;
    end;
  end;
  VerifyPCX:=True;
end;

function WriteImage(const Name:TFileName; ReplaceExisting,Exporting:Boolean):Boolean;
var Valid:TFileName; TempName,BackupName:String[80]; F:File;
    E,N,Count,CloseError:Word; OldExists,OK:Boolean; S:SearchRec;
begin
  WriteImage:=False; FileError:=''; RecoveryPath:='';
  if Exporting then begin
    if not NormalizeExportName(Name,Valid) then Exit;
  end else begin
    if not NormalizeName(Name,Valid) then Exit;
    FileIsClip:=ClipName(Valid);
  end;
  if not Exporting and FileIsClip then begin
    if not ClipboardValid then begin Error('CLIPBOARD IS EMPTY',0); Exit end;
    ClipboardExport(Stage);
    MakeHeader(ClipboardWidth,ClipboardHeight,Ord(ClipboardEllipse));
  end else begin
    DocCopy(Stage); if not Exporting then MakeHeader(64,64,0);
  end;
  FindFirst(Valid,AnyFile,S); OldExists:=DosError=0;
  if OldExists then begin
    if not ReplaceExisting then begin Error('FILE EXISTS - CONFIRM REPLACE',0); Exit end;
    if (S.Attr and $19)<>0 then begin Error('TARGET IS READ ONLY OR NOT A FILE',0); Exit end;
  end;
  if not NewSaveFolder then Exit;
  TempName:=RecoveryPath+'\NEW.TMP'; BackupName:=RecoveryPath+'\'+Valid;
  if Exporting then begin
    TempName:=RecoveryPath+'\NEW.PCX';
    if Valid='NEW.PCX' then TempName:=RecoveryPath+'\NEXT.PCX';
  end;
  Assign(F,TempName);
  {$I-} Rewrite(F,1); E:=IOResult; {$I+}
  if E<>0 then begin Error('CANNOT CREATE TEMP FILE',E); Exit end;
  if Exporting then begin OK:=WritePCX(F); E:=0 end
  else begin
    {$I-} BlockWrite(F,StageHeader,SizeOf(StageHeader),N); E:=IOResult; {$I+}
    OK:=(E=0) and (N=SizeOf(StageHeader));
  end;
  if OK and not Exporting then begin
    Count:=StageBytes;
    {$ifdef PP16_FILE_TEST}if FileFault=1 then Count:=StageBytes div 2;{$endif}
    {$I-} BlockWrite(F,Stage,Count,N); E:=IOResult; {$I+}
    OK:=(E=0) and (N=StageBytes);
  end;
  {$I-} Close(F); CloseError:=IOResult; {$I+}
  if (not OK) or (CloseError<>0) then begin
    if E=0 then E:=CloseError;
    Error('SAVE WRITE OR CLOSE FAILED',E); Exit;
  end;
  if Exporting then begin if not VerifyPCX(TempName) then Exit end
  else if not ReadImage(TempName,True) then Exit;
  if OldExists then begin
    E:=RenameFile(Valid,BackupName);
    if E<>0 then begin Error('CANNOT PRESERVE OLD FILE',E); Exit end;
  end;
  {$ifdef PP16_FILE_TEST}
  if FileFault in [2,3] then E:=5 else
  {$endif}
  E:=RenameFile(TempName,Valid);
  if E<>0 then begin
    Error('REPLACEMENT FAILED - OLD FILE KEPT',E);
    if OldExists then begin
      {$ifdef PP16_FILE_TEST}
      if FileFault=3 then CloseError:=5 else
      {$endif}
      CloseError:=RenameFile(BackupName,Valid);
      if CloseError<>0 then Error('RESTORE FAILED - ORIGINAL IN TRASH',CloseError);
    end;
    Exit;
  end;
  if not Exporting and not FileIsClip then begin CurrentFile:=Valid; DocSaved end;
  WriteImage:=True;
end;

function SaveImage(const Name:TFileName; ReplaceExisting:Boolean):Boolean;
begin SaveImage:=WriteImage(Name,ReplaceExisting,False) end;

function ExportPCX(const Name:TFileName; ReplaceExisting:Boolean):Boolean;
begin ExportPCX:=WriteImage(Name,ReplaceExisting,True) end;
begin
  {PP16 accepts DOS 3.3 / 8.3 names only. Keep all runtime file operations on
   that API even when the host offers LFNs. The shipped i8086-small RTL's LFN
   search path raises runtime error 257 when it finds an existing file. This
   process-local switch leaves the emulator's configuration unchanged.}
  System.LFNSupport:=False;
  CurrentFile:=''; FileError:=''; RecoveryPath:='';
end.
