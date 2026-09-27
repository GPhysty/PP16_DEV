unit TFiles;
{$mode tp}{$H-}{$R+}{$Q+}
interface
uses TDoc;
type TFileName=String[12];
var CurrentFile:TFileName;
    FileError:String[48]; RecoveryPath:String[64];
{$ifdef PP16_FILE_TEST}var FileFault:Byte;{$endif}
function NormalizeName(const Input:String; var Name:TFileName):Boolean;
function Exists(const Name:String):Boolean;
function LoadImage(const Name:TFileName):Boolean;
function SaveImage(const Name:TFileName; ReplaceExisting:Boolean):Boolean;
implementation
uses Dos;
type THeader=array[0..19] of Byte;
var Stage:TDocPixels;

procedure Error(const Message:String; Code:Word);
var S:String[6];
begin
  FileError:=Message;
  if Code<>0 then begin Str(Code,S); FileError:=Message+' (DOS '+S+')' end;
end;

function NormalizeName(const Input:String; var Name:TFileName):Boolean;
var S,B:String[12]; I,P:Integer;
begin
  NormalizeName:=False; FileError:='USE A DOS 8.3 NAME WITH .P16';
  if (Length(Input)=0) or (Length(Input)>12) then Exit;
  S:=Input; P:=0;
  for I:=1 to Length(S) do begin
    S[I]:=UpCase(S[I]);
    if S[I]='.' then begin if P<>0 then Exit; P:=I end
    else if not (S[I] in ['A'..'Z','0'..'9','_','-']) then Exit;
  end;
  if P=0 then begin if Length(S)>8 then Exit; S:=S+'.P16'; P:=Length(S)-3 end;
  if (P<2) or (P>9) or (Length(S)<>P+3) or (Copy(S,P,4)<>'.P16') then Exit;
  B:=Copy(S,1,P-1);
  if (B='CON') or (B='PRN') or (B='AUX') or (B='NUL') then Exit;
  if (Length(B)=4) and (B[4] in ['1'..'9']) and
     ((Copy(B,1,3)='COM') or (Copy(B,1,3)='LPT')) then Exit;
  Name:=S; FileError:=''; NormalizeName:=True;
end;

function Exists(const Name:String):Boolean;
var S:SearchRec;
begin FindFirst(Name,AnyFile,S); Exists:=DosError=0 end;

procedure MakeHeader(var H:THeader);
begin
  FillChar(H,SizeOf(H),0);
  H[0]:=$50; H[1]:=$31; H[2]:=$36; H[3]:=$1A;
  H[4]:=1; H[6]:=20; H[8]:=64; H[10]:=64; H[17]:=8;
end;

function ReadImage(const Name:String; Verify:Boolean):Boolean;
var F:File; H,Expected:THeader; Row:array[0..63] of Byte;
    E,N:Word; I,J:Integer; Size:LongInt; OK:Boolean; OldMode:Byte;
begin
  ReadImage:=False; Assign(F,Name); OldMode:=FileMode; FileMode:=0;
  {$I-} Reset(F,1); E:=IOResult; {$I+} FileMode:=OldMode;
  if E<>0 then begin Error('CANNOT OPEN FILE',E); Exit end;
  OK:=True;
  {$I-} Size:=FileSize(F); E:=IOResult; {$I+}
  if (E<>0) or (Size<>2068) then begin Error('WRONG FILE LENGTH',E); OK:=False end;
  if OK then begin
    {$I-} BlockRead(F,H,20,N); E:=IOResult; {$I+}
    if (E<>0) or (N<>20) then begin Error('HEADER READ FAILED',E); OK:=False end;
  end;
  if OK then begin
    MakeHeader(Expected);
    for I:=0 to 19 do if H[I]<>Expected[I] then OK:=False;
    if not OK then Error('NOT A SUPPORTED 64X64 P16 V1 FILE',0);
  end;
  if OK and not Verify then
  begin
    {$I-} BlockRead(F,Stage,DocBytes,N); E:=IOResult; {$I+}
    if (E<>0) or (N<>DocBytes) then begin Error('PIXEL READ FAILED',E); OK:=False end;
  end
  else begin
    I:=0;
    while OK and (I<DocBytes) do begin
      {$I-} BlockRead(F,Row,SizeOf(Row),N); E:=IOResult; {$I+}
      if (E<>0) or (N<>SizeOf(Row)) then begin Error('PIXEL READ FAILED',E); OK:=False end
      else begin
        for J:=0 to 63 do if Row[J]<>Stage[I+J] then OK:=False;
        if not OK then Error('SAVED PIXELS DID NOT VERIFY',0);
      end;
      Inc(I,64);
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
  if not ReadImage(Valid,False) then Exit;
  DocReplace(Stage); CurrentFile:=Valid; LoadImage:=True;
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

function SaveImage(const Name:TFileName; ReplaceExisting:Boolean):Boolean;
var Valid:TFileName; TempName,BackupName:String[80]; F:File; H:THeader;
    E,N,Count,CloseError:Word; OldExists,OK:Boolean; S:SearchRec;
begin
  SaveImage:=False; FileError:=''; RecoveryPath:='';
  if not NormalizeName(Name,Valid) then Exit;
  FindFirst(Valid,AnyFile,S); OldExists:=DosError=0;
  if OldExists then begin
    if not ReplaceExisting then begin Error('FILE EXISTS - CONFIRM REPLACE',0); Exit end;
    if (S.Attr and $19)<>0 then begin Error('TARGET IS READ ONLY OR NOT A FILE',0); Exit end;
  end;
  if not NewSaveFolder then Exit;
  TempName:=RecoveryPath+'\NEW.TMP'; BackupName:=RecoveryPath+'\'+Valid;
  DocCopy(Stage); MakeHeader(H); Assign(F,TempName);
  {$I-} Rewrite(F,1); E:=IOResult; {$I+}
  if E<>0 then begin Error('CANNOT CREATE TEMP FILE',E); Exit end;
  {$I-} BlockWrite(F,H,SizeOf(H),N); E:=IOResult; {$I+}
  OK:=(E=0) and (N=SizeOf(H));
  if OK then begin
    Count:=DocBytes;
    {$ifdef PP16_FILE_TEST}if FileFault=1 then Count:=DocBytes div 2;{$endif}
    {$I-} BlockWrite(F,Stage,Count,N); E:=IOResult; {$I+}
    OK:=(E=0) and (N=DocBytes);
  end;
  {$I-} Close(F); CloseError:=IOResult; {$I+}
  if (not OK) or (CloseError<>0) then begin
    if E=0 then E:=CloseError;
    Error('SAVE WRITE OR CLOSE FAILED',E); Exit;
  end;
  if not ReadImage(TempName,True) then Exit;
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
  CurrentFile:=Valid; DocSaved; SaveImage:=True;
end;
begin
  {PP16 accepts DOS 3.3 / 8.3 names only. Keep all runtime file operations on
   that API even when the host offers LFNs. The shipped i8086-small RTL's LFN
   search path raises runtime error 257 when it finds an existing file. This
   process-local switch leaves the emulator's configuration unchanged.}
  System.LFNSupport:=False;
  CurrentFile:=''; FileError:=''; RecoveryPath:='';
end.
