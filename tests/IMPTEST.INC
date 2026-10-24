function ImportChecks:Word;
var Failures:Word; Before:DWord; R:Registers;

  procedure Check(OK:Boolean; const Message:String);
  begin if not OK then begin Inc(Failures); WriteLn('FAIL: ',Message,' ',FileError) end end;

  procedure TypeName(const S:String);
  var I:Integer;
  begin for I:=1 to Length(S) do KeyInput(Ord(S[I]),0,0) end;

  procedure ChooseImport;
  begin
    HandleClick(MenuX[0],3,1);
    HandleClick(PopupX[0]+14,MenuRowY(0,4)+1,1);
  end;

  procedure PaintIntact;
  begin
    Check((ForeColor=GradientPaint) and (BackColor=6) and (BrushSize=3) and
          (SelectedTool=7) and (GradientFirst=1) and (GradientLast=14) and
          (GradientStep=3),'import keeps all active paint/tool settings');
    Check(ClipboardValid and (ClipboardWidth=1) and (ClipboardHeight=1) and
          (ClipboardPixel(0,0)=9),'import keeps clipboard dimensions and pixels');
  end;

  procedure Capture(const Name:String);
  var F:File; Row:array[0..159] of Byte; X,Y:Integer;
  begin
    Assign(F,Name); Rewrite(F,1);
    for Y:=0 to 199 do begin
      for X:=0 to 159 do Row[X]:=(GetPixel(X*2,Y) shl 4) or GetPixel(X*2+1,Y);
      BlockWrite(F,Row,SizeOf(Row));
    end;
    Close(F);
  end;

begin
  Failures:=0; InitUI; InitBlankDoc(0); CurrentFile:='OLD.P16';
  ForeColor:=GradientPaint; BackColor:=6; BrushSize:=3; SelectedTool:=7;
  SetGradient(1,14,3); DocBeginAction; DocSetPixel(0,0,9); DocCommitAction;
  ClipboardCopy(0,0,1,1,False); DrawUI; Before:=DocChecksum;
  ChooseImport;
  Check((OpenMenu=9) and DialogImporting and not DialogSaving,'File Import dispatches to indexed chooser');
  HandleClick(210,155,1); Check(DocChecksum=Before,'import chooser blocks canvas');
  KeyInput(27,1,0); Check((OpenMenu=-1) and (DocChecksum=Before) and DocCanUndo and
    (CurrentFile='OLD.P16') and DocDirty,'cancel chooser preserves document state');
  ChooseImport; TypeName('PCXRUN.PCX'); KeyInput(13,28,0);
  Check((OpenMenu=9) and (FileError<>'') and (DocChecksum=Before),'bad import remains in chooser');
  KeyInput(27,1,0); PaintIntact;
  ChooseImport; TypeName('GEN.PCX');
  FillChar(R,SizeOf(R),0); R.AH:=5; R.CX:=$011B; Intr($16,R);
  KeyInput(13,28,0);
  Check((OpenMenu=9) and (FileError='IMPORT CANCELLED') and (DocChecksum=Before),
        'Escape cancels conversion through BIOS input');
  KeyInput(27,1,0);
  ChooseImport; TypeName('SMALL.PCX'); KeyInput(13,28,0);
  Check((OpenMenu=-1) and DocDirty and DocCanUndo and (CurrentFile=''),'successful import is unnamed and undoable');
  Check((DocPixel(0,0)=1) and (DocPixel(1,0)=6) and (DocPixel(2,0)=12) and
        (DocPixel(4,0)=15) and (DocPixel(5,0)=0) and (DocPixel(0,3)=0),
        'import commits literal colors and top-left black padding'); PaintIntact;
  KeyInput(26,0,0);
  Check((DocChecksum=Before) and DocDirty,'UI undo restores pre-import image and dirty state');
  ChooseImport; TypeName('MULTI.PUT'); KeyInput(13,28,0);
  Check((OpenMenu=9) and (DocChecksum=Before),'PUT selection waits before modifying image');
  HandleClick(241,77,1); KeyInput(13,28,0);
  Check((OpenMenu=-1) and (DocPixel(0,0)=1) and (DocPixel(4,0)=15),
        'mouse PUT selector imports second odd-aligned record'); PaintIntact;
  Before:=DocChecksum;
  ChooseImport; TypeName('MIXED.PUT'); KeyInput(13,28,0); TypeName('GOOD.PAL'); KeyInput(13,28,0);
  Check((OpenMenu=9) and (DocChecksum=Before) and (FileError<>''),'oversized selected PUT image rejected');
  HandleClick(241,77,1); KeyInput(13,28,0);
  Check((OpenMenu=-1) and (DocChecksum=Before),'small record after oversized record imports');
  ChooseImport; TypeName('MISSING.PUT'); KeyInput(13,28,0); KeyInput(13,28,0);
  Check((OpenMenu=9) and (FileError<>''),'missing associated palette remains editable');
  TypeName('GOOD.PAL'); KeyInput(13,28,0);
  Check((OpenMenu=-1) and (DocPixel(0,0)=1),'explicit PAL palette imports');
  HandleClick(MenuX[0],3,1); HandleClick(PopupX[0]+14,MenuRowY(0,2)+1,1);
  Check((OpenMenu=9) and DialogSaving and not DialogImporting,'Save after import asks for native filename');
  TypeName('UIIMPT'); KeyInput(13,28,0);
  Check((CurrentFile='UIIMPT.P16') and not DocDirty,'Save uses P16 without changing source');
  ChooseImport; KeyInput(9,15,0); KeyInput(0,71,0); KeyInput(13,28,0);
  Check(OpenMenu=9,'keyboard import list opens PUT settings'); KeyInput(27,1,0);
  ChooseImport; TypeName('BIRDN.PCX'); KeyInput(13,28,0); PaintIntact;
  Check((OpenMenu=-1) and DocDirty and (CurrentFile=''),'bird imports through File menu');
  Capture('IMPORTED.BIN');
  ChooseImport; TypeName('MULTI.PUT'); KeyInput(13,28,0);
  KeyInput(9,15,0); KeyInput(0,80,0); Capture('IMPORTUI.BIN');
  WriteLn('Import UI: initial near heap=',MemAvail);
  if Failures=0 then WriteLn('IMPORT UI CHECKS PASSED');
  ImportChecks:=Failures;
end;
