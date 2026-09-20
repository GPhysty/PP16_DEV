program FileTest;
{$mode tp}{$H-}{$R+}{$Q+}{$M 8192,0,65536}
uses Dos,TDoc,TFiles;
var Failures:Word; Before,Pixels,OldPixels:TDocPixels; F:File; E:Word; I,X,Y:Integer;
    Name:TFileName; SavedName:TFileName; SavedDirty,SavedUndo:Boolean;
    Backup:String[80];
const InvalidNames:array[0..10] of String[14]=
 ('','CON','nul.p16','COM1','LPT9.P16','TOOLONG99','A.PUT','A.P16X','A..P16','..\A','A/B');
      BadFiles:array[0..13] of TFileName=
 ('EMPTY.P16','SHORT.P16','TRUNC.P16','MAGIC.P16','VERSION.P16',
  'FLAGS.P16','PALETTE.P16','LENGTH.P16','EXTRA.P16','ODD.P16','MISSING.P16',
  'WIDTH.P16','HEIGHT.P16','HEADER.P16');

procedure Check(OK:Boolean; const Message:String);
begin if not OK then begin Inc(Failures); WriteLn('FAIL: ',Message) end end;

procedure Fixture;
var X,Y:Integer;
begin
  InitBlankDoc(0);
  for Y:=0 to 63 do for X:=0 to 63 do DocSetPixel(X,Y,(X div 4+Y) mod 16);
end;

function Matches(const Path:String; const Expected:TDocPixels):Boolean;
var G:File; Actual:TDocPixels; N,E:Word; I:Integer; OK:Boolean;
begin
  Matches:=False; Assign(G,Path);
  {$I-} Reset(G,1); E:=IOResult; {$I+} if E<>0 then Exit;
  {$I-} Seek(G,20); E:=IOResult; {$I+} OK:=E=0;
  if OK then begin
    {$I-} BlockRead(G,Actual,DocBytes,N); E:=IOResult; {$I+}
    OK:=(E=0) and (N=DocBytes);
  end;
  {$I-} Close(G); E:=IOResult; {$I+} if E<>0 then OK:=False;
  if OK then for I:=0 to DocBytes-1 do if Actual[I]<>Expected[I] then OK:=False;
  Matches:=OK;
end;

procedure Unchanged;
var I:Integer;
begin
  DocCopy(Pixels);
  for I:=0 to DocBytes-1 do Check(Pixels[I]=Before[I],'failure preserves document pixels');
  Check((DocDirty=SavedDirty) and (DocCanUndo=SavedUndo) and (CurrentFile=SavedName),
        'failure preserves dirty flag, undo and filename');
end;

begin
  WriteErrorsToStdErr:=False; Failures:=0; FileFault:=0;
  WriteLn('File tests: initial near heap bytes=',MemAvail);
  Fixture;
  if ParamStr(1)='/WRITE' then begin
    Check(SaveImage('ROUND.P16',False),'write roundtrip fixture');
    Check(not DocDirty,'successful save clears dirty');
  end else if ParamStr(1)='/READ' then begin
    InitBlankDoc(0); Check(LoadImage('ROUND.P16'),'reopen in new DOS process');
    for Y:=0 to 63 do for X:=0 to 63 do
      Check(DocPixel(X,Y)=(X div 4+Y) mod 16,'roundtrip every pixel');
    Check(not DocDirty and not DocCanUndo,'loaded document starts clean without undo');
  end else if ParamStr(1)='/BLOCKED' then begin
    DocCopy(Before); SavedDirty:=DocDirty; SavedUndo:=DocCanUndo; SavedName:=CurrentFile;
    Check(not SaveImage('KEEP.P16',True),'blocked trash path rejects save'); Unchanged;
    Check(Matches('KEEP.P16',Before),'blocked save preserves original file');
  end else begin
    Check(NormalizeName('sprite',Name) and (Name='SPRITE.P16'),'default extension');
    Check(NormalizeName('image_12.p16',Name) and (Name='IMAGE_12.P16'),'valid 8.3 name');
    for I:=0 to 10 do Check(not NormalizeName(InvalidNames[I],Name),'invalid filename rejected');
    CurrentFile:='CURRENT.P16';
    DocBeginAction; DocSetPixel(0,0,12); DocCommitAction;
    DocCopy(Before); SavedDirty:=DocDirty; SavedUndo:=DocCanUndo; SavedName:=CurrentFile;
    for I:=0 to 13 do begin
      Check(not LoadImage(BadFiles[I]),'malformed or unsupported load rejected'); Unchanged;
    end;
    Check(not SaveImage('ROUND.P16',False),'overwrite requires authorization'); Unchanged;
    Check(not SaveImage('DIR.P16',True),'directory target refused'); Unchanged;
    DocCopy(Pixels);
    Assign(F,'ROUND.P16'); GetFAttr(F,E); Check(DosError=0,'read attributes');
    SetFAttr(F,E or 1); Check(DosError=0,'set read-only');
    Check(not SaveImage('ROUND.P16',True),'read-only save refused'); Unchanged;
    Check(LoadImage('ROUND.P16'),'read-only image can be opened');
    SetFAttr(F,E); Check(DosError=0,'restore attributes');
    Fixture; DocCopy(OldPixels);
    {Before is the edited image; ROUND still contains the original fixture.}
    DocReplace(Before); DocBeginAction; DocSetPixel(1,0,9); DocCommitAction;
    DocCopy(Before); SavedDirty:=DocDirty; SavedUndo:=DocCanUndo; SavedName:=CurrentFile;
    for I:=1 to 3 do begin
      FileFault:=I;
      Check(not SaveImage('ROUND.P16',True),'injected write or rename failure'); Unchanged;
      if I=3 then begin
        Backup:=RecoveryPath+'\ROUND.P16';
        Check(Matches(Backup,OldPixels),'failed rollback preserves original in trash');
        Assign(F,Backup); {$I-} Rename(F,'ROUND.P16'); E:=IOResult; {$I+}
        Check(E=0,'restore fault-test backup');
      end;
      Check(Matches('ROUND.P16',OldPixels),'failed save preserves old file bytes');
    end;
    FileFault:=0;
    Check(SaveImage('ROUND.P16',True),'confirmed replacement succeeds');
    Check(Matches(RecoveryPath+'\ROUND.P16',OldPixels),'successful replacement retains old file');
    Check(Matches('ROUND.P16',Before),'replacement contains every new pixel');
    Check(not DocDirty and DocCanUndo,'save preserves undo');
    DocUndo; Check(DocDirty,'undo after save is unsaved');
  end;
  if Failures<>0 then Halt(1);
  WriteLn('M6 FILE CHECKS PASSED');
end.
