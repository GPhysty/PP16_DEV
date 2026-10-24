program ImpFile;
{$mode tp}{$H-}{$R+}{$Q+}{$M 8192,0,65536}
uses Dos,TDoc,TFiles,TImport,TPaint,TClip;
var Failures,Assertions:Word; Before,Expected,Actual:TDocPixels;
    ClipBefore,ClipAfter:TDocPixels; SavedDirty,SavedUndo:Boolean;
    OldName,Name,Pal,RawName,OutName:TFileName; List:Text;
    Selected,Count,W,H:Word; I,J,Code:Integer; S:String[12];
    F:File; N,Attributes:Word; CancelAt,Polls:Integer; InitialHeap:LongInt;
    StartTick,EndTick:LongInt; Imported:Boolean;
const BadPCX:array[0..13] of TFileName=
 ('PCXVER.PCX','PCXBPP.PCX','PCXPLN.PCX','PCXENC.PCX','PCXWIDE.PCX','PCXHIGH.PCX',
  'PCXLINE.PCX','PCXXMIN.PCX','PCXZERO.PCX','PCXRUN.PCX','PCXTRUNC.PCX',
  'PCXEXTRA.PCX','PCXPAL.PCX','PCXSHORT.PCX');
      BadPUT:array[0..5] of TFileName=
 ('PUTSHORT.PUT','PUTEXTRA.PUT','PUTMAGIC.PUT','PUTBITS.PUT','PUTZERO.PUT','PUTPAD.PUT');
      BadPal:array[0..3] of TFileName=('BADDAC.PAL','BADFOUR.PAL','SHORT.PAL','NONE.PAL');
{$I STACKCHK.INC}

procedure Check(OK:Boolean; const Message:String);
begin
  Inc(Assertions);
  if not OK then begin Inc(Failures); WriteLn('FAIL: ',Message,' ',FileError,' ',ImportError) end;
end;

function Ticks:LongInt;
var H1,H2,L:Word;
begin
  repeat H1:=MemW[$40:$6E]; L:=MemW[$40:$6C]; H2:=MemW[$40:$6E] until H1=H2;
  Ticks:=(LongInt(H1) shl 16) or L;
end;

function CancelImport:Boolean;
begin Inc(Polls); CancelImport:=Polls>=CancelAt end;

procedure ReadExpected(const Name:String);
begin
  Assign(F,Name); Reset(F,1); BlockRead(F,Expected,2048,N); Close(F);
  Check(N=2048,'reference length');
end;

procedure Capture;
begin
  DocCopy(Before); SavedDirty:=DocDirty; SavedUndo:=DocCanUndo; OldName:=CurrentFile;
  ClipboardExport(ClipBefore);
end;

procedure Unchanged;
begin
  DocCopy(Actual); ClipboardExport(ClipAfter);
  Check(CompareByte(Actual,Before,2048)=0,'failure preserves every document pixel');
  Check((DocDirty=SavedDirty) and (DocCanUndo=SavedUndo) and (CurrentFile=OldName),
        'failure preserves dirty flag, undo and filename');
  Check(CompareByte(ClipBefore,ClipAfter,2048)=0,'failure preserves clipboard');
  Check((GradientFirst=1) and (GradientLast=14) and (GradientStep=3),'import preserves selected paint');
end;

begin
  WriteErrorsToStdErr:=False; Failures:=0; Assertions:=0;
  {The RTL initializes argv/environment lazily on the first ParamStr call.}
  S:=ParamStr(1); WriteLn('Import file checks'); InitialHeap:=MemAvail;
  WriteLn('Import tests: initial near heap=',InitialHeap);
  MarkUnusedStack;
  InitPaint; SetGradient(1,14,3); InitBlankDoc(0);
  if S='/SIBLING' then begin
    Check(ImportImage('ASSOC.PUT',1,'',nil),'sibling PALETTES association');
    ReadExpected('EXPECT.RAW'); DocCopy(Actual);
    Check(CompareByte(Actual,Expected,2048)=0,'sibling palette output');
  end else begin
    Check(NormalizeImportName('bird',Name) and (Name='BIRD.PCX'),'default import extension');
    Check(not NormalizeName('A.PUT',Name),'native Open stays native');
    Check(not NormalizeImportName('A.P16',Name),'import stays indexed only');
    Check(not NormalizeImportName('CON.PUT',Name),'import rejects DOS devices');
    Check(not NormalizeImportName('..\A.PUT',Name),'import dialog uses current directory');
    Check(InspectImport('MULTI.PUT',2,Count,W,H) and (Count=2) and (W=5) and (H=3),'PUT odd record indexing');
    Check(InspectImport('MIXED.PUT',2,Count,W,H) and (Count=2) and (W=5),'PUT skips record larger than 32767 bytes');
    DocSetPixel(0,0,5); ClipboardCopy(0,0,1,1,False);
    InitBlankDoc(0); CurrentFile:='OLD.P16';
    DocBeginAction; DocSetPixel(0,0,12); DocCommitAction; Capture;
    for I:=0 to 13 do begin Check(not ImportImage(BadPCX[I],1,'',nil),'malformed PCX rejected'); Unchanged end;
    for I:=0 to 5 do begin Check(not ImportImage(BadPUT[I],1,'GOOD.PAL',nil),'malformed PUT rejected'); Unchanged end;
    for I:=0 to 3 do begin Check(not ImportImage('MULTI.PUT',1,BadPal[I],nil),'invalid palette rejected'); Unchanged end;
    Check(not ImportImage('MISSING.PUT',1,'',nil),'missing association needs palette'); Unchanged;
    Check(not ImportImage('NONE.PCX',1,'',nil),'missing input rejected'); Unchanged;
    Check(not ImportImage('MULTI.PUT',0,'',nil),'zero record rejected'); Unchanged;
    Check(not ImportImage('MULTI.PUT',3,'',nil),'nonexistent record rejected'); Unchanged;
    Check(not ImportImage('MIXED.PUT',1,'GOOD.PAL',nil),'oversized selected record rejected'); Unchanged;
    for J:=1 to 3 do begin
      Polls:=0; CancelAt:=J;
      Check(not ImportImage('GEN.PCX',1,'',CancelImport),'conversion cancellation'); Unchanged;
    end;
    Polls:=0; CancelAt:=3;
    Check(not ImportImage('PADWIDE.PCX',1,'',CancelImport),'cancel while decoding padded scanline'); Unchanged;
    DocUndo; Check((DocPixel(0,0)=0) and not DocDirty,'previous undo survives all failures');
    DocBeginAction; DocSetPixel(0,0,12); DocCommitAction;
    DocBeginAction; Capture;
    Check(not ImportImage('SMALL.PCX',1,'',nil),'active gesture rejects import commit'); Unchanged;
    DocCancelAction;
    Assign(List,'CASES.TXT'); Reset(List); ReadLn(List,S); Val(S,J,Code); Check(Code=0,'case count');
    for I:=1 to J do begin
      ReadLn(List,Name); ReadLn(List,S); Val(S,Selected,Code);
      ReadLn(List,Pal); ReadLn(List,RawName); ReadLn(List,OutName);
      Capture; ReadExpected(RawName);
      StartTick:=Ticks; Imported:=ImportImage(Name,Selected,Pal,nil); EndTick:=Ticks;
      if EndTick<StartTick then EndTick:=EndTick+$1800B0;
      Check(Imported,'valid indexed image imports');
      WriteLn('Imported ',Name,' image ',Selected,' ticks=',EndTick-StartTick);
      DocCopy(Actual); Check(CompareByte(Actual,Expected,2048)=0,'every converted/padded pixel matches scalar oracle');
      Check(DocDirty and DocCanUndo and (CurrentFile=''),'successful import is unnamed, dirty and undoable');
      Check(SaveImage(OutName,False),'import saves as native P16');
      Check(not DocDirty and DocCanUndo,'save preserves imported undo');
      DocUndo; DocCopy(Actual);
      Check(CompareByte(Actual,Before,2048)=0,'import undo restores every previous pixel');
      Check((GradientFirst=1) and (GradientLast=14) and (GradientStep=3),'conversion leaves gradient unchanged');
    end;
    Close(List);
    Assign(F,'SMALL.PCX'); GetFAttr(F,Attributes); Check(DosError=0,'read source attributes');
    SetFAttr(F,Attributes or 1); Check(DosError=0,'make source read-only');
    Check(ImportImage('SMALL.PCX',1,'',nil),'read-only source imports');
    SetFAttr(F,Attributes); Check(DosError=0,'restore source attributes');
    InitBlankDoc(0); DocBeginAction; DocSetPixel(0,0,9); DocCommitAction;
    Check(ImportImage('SMALL.PCX',1,'',nil),'import over dirty image'); DocUndo;
    Check(DocDirty and (DocPixel(0,0)=9),'undo restores prior dirty flag');
  end;
  WriteLn('Import tests: final near heap=',MemAvail);
  Check(MemAvail=InitialHeap,'import closes files without heap leakage');
  Check(CheckStackMargin,'at least 1 KiB untouched stack margin');
  if Failures<>0 then Halt(1);
  WriteLn('IMPORT FILE CHECKS PASSED; assertions=',Assertions);
end.
