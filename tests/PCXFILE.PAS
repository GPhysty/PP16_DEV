program PCXFile;
{$mode tp}{$H-}{$R+}{$Q+}{$M 8192,0,65536}
uses Dos,TDoc,TFiles,TImport,TClip,TPaint;
var Failures,Assertions,E,Attributes:Word; I,X,Y:Integer; F:File;
    Before,Original,Actual,ClipBefore,ClipAfter:TDocPixels;
    OldName,Name:TFileName; SavedDirty,SavedUndo:Boolean; Backup:String[80];
    InitialHeap:LongInt; Arg:String[12];
{$I STACKCHK.INC}

procedure Check(OK:Boolean; const Message:String);
begin
  Inc(Assertions);
  if not OK then begin Inc(Failures); WriteLn('FAIL: ',Message,' ',FileError) end;
end;

procedure Capture;
begin
  DocCopy(Before); ClipboardExport(ClipBefore); OldName:=CurrentFile;
  SavedDirty:=DocDirty; SavedUndo:=DocCanUndo;
end;

procedure Unchanged;
begin
  DocCopy(Actual); ClipboardExport(ClipAfter);
  Check(CompareByte(Actual,Before,DocBytes)=0,'export preserves all document pixels');
  Check((CurrentFile=OldName) and (DocDirty=SavedDirty) and (DocCanUndo=SavedUndo),
        'export preserves native filename, dirty flag and undo');
  Check(ClipboardValid and (ClipboardWidth=1) and (ClipboardHeight=1) and
        (CompareByte(ClipBefore,ClipAfter,DocBytes)=0),'export preserves clipboard');
  Check((GradientFirst=1) and (GradientLast=14) and (GradientStep=3),
        'export preserves active gradient');
end;

function Matches(const Path:String; const Expected:TDocPixels):Boolean;
begin
  Matches:=False;
  if ReadImported(Path,'',1,Actual,nil) then Matches:=CompareByte(Actual,Expected,DocBytes)=0;
end;

begin
  WriteErrorsToStdErr:=False; Arg:=ParamStr(1); InitialHeap:=MemAvail;
  Failures:=0; Assertions:=0; FileFault:=0; MarkUnusedStack;
  InitPaint; SetGradient(1,14,3); InitBlankDoc(0);
  for Y:=0 to 63 do for X:=0 to 63 do DocSetPixel(X,Y,(X div 4+Y) mod 16);
  ClipboardCopy(0,0,1,1,False); CurrentFile:='NATIVE.P16';
  DocCopy(Original); Capture;
  Check(NormalizeExportName('sprite',Name) and (Name='SPRITE.PCX'),'default export extension');
  Check(NormalizeExportName('image_12.pcx',Name) and (Name='IMAGE_12.PCX'),'export 8.3 name');
  Check(not NormalizeExportName('A.PUT',Name),'export rejects PUT extension');
  Check(not NormalizeExportName('A.P16',Name),'export rejects native extension');
  Check(not NormalizeExportName('CON.PCX',Name),'export rejects DOS device');
  Check(not NormalizeExportName('..\A.PCX',Name),'export rejects paths');
  if Arg='/BLOCKED' then begin
    Check(not ExportPCX('KEEP.PCX',True),'blocked trash path rejects export'); Unchanged;
  end else begin
    Check(ExportPCX('COLORS',False),'export full-color image'); Unchanged;
    Check(Matches('COLORS.PCX',Before),'export reimports with every index unchanged');
    Check(not ExportPCX('COLORS.PCX',False),'replacement requires confirmation'); Unchanged;
    Check(not ExportPCX('DIR.PCX',True),'directory target refused'); Unchanged;
    Assign(F,'COLORS.PCX'); GetFAttr(F,Attributes); Check(DosError=0,'read PCX attributes');
    SetFAttr(F,Attributes or 1); Check(DosError=0,'set PCX read-only');
    Check(not ExportPCX('COLORS.PCX',True),'read-only PCX refused'); Unchanged;
    SetFAttr(F,Attributes); Check(DosError=0,'restore PCX attributes');
    DocBeginAction; DocSetPixel(0,0,12); DocSetPixel(1,0,9); DocCommitAction; Capture;
    for I:=1 to 3 do begin
      FileFault:=I;
      Check(not ExportPCX('COLORS.PCX',True),'injected write or rename failure'); Unchanged;
      if I=3 then begin
        Backup:=RecoveryPath+'\COLORS.PCX';
        Check(Matches(Backup,Original),'failed rollback preserves original PCX in trash');
        Assign(F,Backup); {$I-} Rename(F,'COLORS.PCX'); E:=IOResult; {$I+}
        Check(E=0,'restore fault-test original');
      end;
      Check(Matches('COLORS.PCX',Original),'failed export leaves original pixels readable');
    end;
    FileFault:=0;
    Check(ExportPCX('COLORS.PCX',True),'confirmed PCX replacement'); Unchanged;
    Check(Matches(RecoveryPath+'\COLORS.PCX',Original),'replacement retains original PCX');
    Check(Matches('COLORS.PCX',Before),'replacement reimports exact edited pixels');
    Check(ExportPCX('NEW.PCX',False),'export with the default temporary basename'); Unchanged;
    DocUndo; Check(DocPixel(0,0)=0,'export preserves usable undo snapshot');
    Capture;
    Check(ExportPCX('NEW.PCX',True),'replace NEW.PCX without temporary/backup collision'); Unchanged;
    Check(Matches('NEW.PCX',Original),'replacement of NEW.PCX has exact pixels');
    InitBlankDoc(0); DocSaved; Capture;
    Check(ExportPCX('BLACK.PCX',False),'export solid black with 64-pixel runs'); Unchanged;
    InitBlankDoc(15); Capture;
    Check(ExportPCX('WHITE.PCX',False),'export solid white'); Unchanged;
    InitBlankDoc(0);
    for Y:=0 to 63 do for X:=0 to 63 do begin
      if Y=0 then DocSetPixel(X,Y,0)
      else if Y=1 then begin
        if X<63 then DocSetPixel(X,Y,15) else DocSetPixel(X,Y,3);
      end else if Y=2 then DocSetPixel(X,Y,3+(X mod 2)*3)
      else if Y=3 then DocSetPixel(X,Y,(X div 2) mod 16)
      else DocSetPixel(X,Y,Y mod 16);
    end;
    Capture; Check(ExportPCX('RUNS.PCX',False),'export RLE boundaries and single pixels'); Unchanged;
    Check(Matches('RUNS.PCX',Before),'RLE boundaries round-trip without row leakage');
  end;
  Check(CheckStackMargin,'export keeps at least 1 KiB stack margin');
  WriteLn('Export heap initial=',InitialHeap,' final=',MemAvail);
  Check(MemAvail=InitialHeap,'export restores heap exactly');
  WriteLn('Export assertions=',Assertions);
  if Failures<>0 then Halt(1);
  WriteLn('PCX EXPORT CHECKS PASSED');
end.
