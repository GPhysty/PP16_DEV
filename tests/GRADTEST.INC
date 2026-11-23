function GradientChecks:Word;
var F:Word; Assertions:DWord; S:TMouseState;
    A,B,K,X,Y,I,J,N,Z,Tool,Size:Integer; C:Byte;
    Before:DWord; Row:TDocRow;

  procedure Check(OK:Boolean; const Name:String);
  begin
    Inc(Assertions);
    if not OK then begin Inc(F); if F<20 then WriteLn('FAIL: ',Name) end;
  end;

  procedure Feed(X,Y:Integer; Buttons:Byte);
  begin S.X:=X; S.Y:=Y; UpdateButtons(Buttons,S); PointerInput(S); PaintChanges end;

  procedure AtDoc(X,Y:Integer; Buttons:Byte);
  begin Feed(CanvasX+(X-PanX)*Zoom,CanvasY+(Y-PanY)*Zoom,Buttons) end;

  procedure PalettePick(C,Button:Byte);
  begin HandleClick(4+(C mod 4)*19,PaletteY+(C div 4)*PaletteStep+2,Button) end;

  procedure ChooseMix(K:Integer);
  begin HandleClick(GradientRampX+((K*2+1)*GradientRampWidth) div 22,GradientY+3,1) end;

  procedure Reset;
  begin
    InitUI; InitBlankDoc(0); SetZoom(2); PanView(-64,-64);
    FillChar(S,SizeOf(S),0); DrawUI;
  end;

  procedure ChooseClear(Black:Boolean);
  begin
    HandleClick(MenuX[3],3,1);
    if Black then I:=0 else I:=1;
    HandleClick(PopupX[3]+14,MenuRowY(3,I)+1,1);
  end;

begin
  F:=0; Assertions:=0; Reset;
  {Check coverage independently by counting each of the 100 tile pixels for
   every endpoint pair and every selectable ratio, including equal colours.}
  for A:=0 to 15 do for B:=0 to 15 do for K:=0 to 10 do
  begin
    SetGradient(A,B,K); N:=0;
    for Y:=0 to 9 do for X:=0 to 9 do
    begin
      C:=PaintColor(X,Y,GradientPaint);
      Check((C=A) or (C=B),'mix uses only its two endpoints');
      if C=B then Inc(N);
      Check(C=PaintColor(X+10,Y+20,GradientPaint),'tile repeats in image coordinates');
    end;
    if A<>B then Check(N=K*10,'exact 10 percent tile coverage')
    else Check(N=100,'equal endpoints remain solid');
  end;
  Check(PaintColor(-1,0,GradientPaint)=0,'negative paint coordinate is safe');
  Check(PaintColor(64,0,GradientPaint)=0,'past-edge paint coordinate is safe');
  SetGradient(1,14,3);
  for Y:=0 to 63 do
  begin
    PaintReadRow(Y,Row);
    for X:=0 to 63 do
    begin
      if Odd(X) then C:=Row[X div 2] and 15 else C:=Row[X div 2] shr 4;
      Check(C=PaintColor(X,Y,GradientPaint),'packed rows agree with pixel resolver');
    end;
  end;
  {Real control dispatch, including all 11 hit regions, palette gaps, swatch,
   endpoint arming/cancellation, picking and foreground/background semantics.}
  Reset;
  HandleClick(GradientAX+2,GradientY+2,1); PalettePick(1,1);
  HandleClick(GradientBX+2,GradientY+2,1); PalettePick(14,1);
  Check((GradientFirst=1) and (GradientLast=14) and
    (ForeColor=GradientPaint) and (GradientArm=0),'endpoint assignment activates mix');
  for K:=0 to 10 do
  begin
    ChooseMix(K);
    Check((GradientStep=K) and (ForeColor=GradientPaint),'all ramp steps select correctly');
    for Y:=0 to 10 do for X:=0 to 32 do
      Check(GetPixel(14+X,82+Y)=PaintColor(X,Y,GradientPaint),'foreground swatch displays active mix');
  end;
  Before:=DocChecksum; PalettePick(6,1);
  Check((ForeColor=6) and (GradientFirst=1) and (GradientLast=14) and
    (DocChecksum=Before),'ordinary palette restores solid and retains endpoints');
  HandleClick(20,PaletteY+2,1);
  Check(ForeColor=6,'palette column gap does not select');
  HandleClick(4,PaletteY+PaletteHeight,1);
  Check(ForeColor=6,'palette row gap does not select');
  ChooseMix(5); PalettePick(3,2);
  Check((ForeColor=GradientPaint) and (BackColor=3),'right palette changes only solid background');
  Check(GetPixel(GradientRampX+GradientRampWidth div 2,190)=15,'active gradient marker is bright');
  KeyInput(9,15,0);
  Check((ForeColor=3) and (BackColor=3),'Tab from gradient selects solid background');
  Check(GetPixel(GradientRampX+GradientRampWidth div 2,190)=8,'Tab redraws gradient marker as inactive');
  HandleClick(GradientAX+2,GradientY+2,1); KeyInput(27,1,0); PalettePick(5,1);
  Check((GradientArm=0) and (GradientFirst=1) and (ForeColor=5),'Escape cancels endpoint assignment');
  ChooseMix(4); AtDoc(5,5,2); AtDoc(5,5,0);
  Check((ForeColor=0) and not DocDirty,'eyedropper exits gradient without painting');
  {Clear uses complete packed rows, is one undo action, and preserves the
   previous undo on an identical repeat. Both solid endpoints take the old path.}
  for K:=0 to 10 do
  begin
    InitBlankDoc(8); SetGradient(1,14,K); ForeColor:=GradientPaint;
    CachedFore:=-1; DrawUI; ChooseClear(False);
    Check(DocCanUndo and DocDirty,'gradient clear is undoable');
    for Y:=0 to 63 do for X:=0 to 63 do
    begin
      C:=PaintColor(X,Y,GradientPaint);
      Check(DocPixel(X,Y)=C,'gradient clear fills packed image');
      Check(GetPixel(CanvasX+X*2,CanvasY+Y*2)=C,'gradient clear redraws canvas');
      Check(GetPixel(ImagePreviewX+X,ImagePreviewY+Y)=C,'gradient clear redraws preview');
    end;
    DocSaved; DocClear(GradientPaint);
    Check(not DocDirty and DocCanUndo,'identical gradient clear preserves clean state and undo');
    DocUndo;
    for Y:=0 to 63 do for X:=0 to 63 do Check(DocPixel(X,Y)=8,'clear undo restores original');
  end;
  DocClear(GradientPaint); ChooseClear(True);
  Check(DocChecksum=0,'ordinary Clear remains black with gradient active');
  DocUndo; Check(DocChecksum<>0,'black Clear undo restores dither');
  KeyInput(0,46,0); PaintChanges; Check(DocChecksum=0,'Alt+C remains black');
  {A fill must traverse unchanged old-colour pixels, including its seed.
   All nine mixed ratios run over the entire document; a separate barrier
   keeps a disconnected region untouched.}
  for K:=1 to 9 do
  begin
    InitBlankDoc(0); SetGradient(0,15,K);
    Check(DocFloodFill(1,0,GradientPaint),'dither fill reports changed pixels');
    for Y:=0 to 63 do for X:=0 to 63 do
      Check(DocPixel(X,Y)=PaintColor(X,Y,GradientPaint),'dither fill reaches all connected pixels');
    DocUndo; Check((DocChecksum=0) and not DocDirty,'dither fill is one clean-restoring undo');
  end;
  InitBlankDoc(0); SetGradient(0,15,5);
  for Y:=0 to 63 do DocSetPixel(32,Y,2);
  DocSaved; DocFloodFill(1,0,GradientPaint);
  for Y:=0 to 63 do for X:=0 to 63 do
    if X<32 then Check(DocPixel(X,Y)=PaintColor(X,Y,GradientPaint),'fill reaches barrier')
    else if X=32 then Check(DocPixel(X,Y)=2,'fill preserves barrier')
    else Check(DocPixel(X,Y)=0,'fill preserves disconnected region');
  DocUndo; Before:=DocChecksum; SetGradient(0,0,5);
  Check(not DocFloodFill(1,0,GradientPaint) and not DocDirty and
    (DocChecksum=Before),'same-colour gradient fill is a no-op');
  {Exercise Brush and each shape via pointer input at every brush size,
   zoom and grid mode. A bright untouched background makes overwritten
   black pixels visible, too. Release must remove every temporary guide pixel.}
  for Tool:=3 to 7 do if Tool<>4 then
    for Size:=1 to 5 do
  begin
    Reset; InitBlankDoc(8); SetGradient(0,15,5); ForeColor:=GradientPaint;
    SelectedTool:=Tool; BrushSize:=Size;
    Z:=2; if Size in [2,5] then Z:=4 else if Size=3 then Z:=8;
    SetZoom(Z); PanView(-64,-64); if Z>2 then PanView(8,9);
    GridVisible:=Odd(Size); DrawUI;
    AtDoc(PanX+3,PanY+3,1); AtDoc(PanX+6,PanY+5,1);
    Check((Tool=3) or not DocDirty,'shape preview leaves document clean');
    AtDoc(PanX+6,PanY+5,0); PaintChanges;
    for Y:=0 to CanvasSize-1 do for X:=0 to CanvasSize-1 do
    begin
      C:=DocPixel(PanX+X div Z,PanY+Y div Z);
      if GridVisible and ((X mod Z=Z-1) or (Y mod Z=Z-1)) then C:=8;
      Check(GetPixel(CanvasX+X,CanvasY+Y)=C,'release renders paint and grid without guide remnants');
    end;
    for Y:=0 to VisibleCells-1 do for X:=0 to VisibleCells-1 do
    begin
      C:=DocPixel(PanX+X,PanY+Y);
      if C<>8 then Check(C=PaintColor(PanX+X,PanY+Y,GradientPaint),'stroke pattern stays image anchored');
    end;
    Check(DocCanUndo,'dither stroke has one undo'); DocUndo;
    Check(not DocDirty,'dither stroke undo restores clean state');
  end;
  Reset; SetGradient(0,15,5); ForeColor:=GradientPaint; BrushSize:=5;
  AtDoc(0,0,1); AtDoc(63,63,0); Before:=DocChecksum;
  AtDoc(0,0,1); AtDoc(63,63,0);
  Check(DocChecksum=Before,'overlapping strokes align at image edges');
  Before:=DocChecksum; AtDoc(10,20,1); AtDoc(20,25,1);
  KeyInput(27,1,1); AtDoc(20,25,0);
  Check((DocChecksum=Before) and DocCanUndo,'cancel preserves previous completed dither action');
  {Literal writes, files and clipboard placement must not reinterpret colours
   through the selected gradient. Save/open the pattern through real DOS I/O.}
  Reset; SetGradient(1,14,3); ForeColor:=GradientPaint; DocClear(GradientPaint);
  Check(SaveImage('GRAD.P16',False),'save gradient as ordinary native pixels');
  Before:=DocChecksum; InitBlankDoc(6);
  Check(LoadImage('GRAD.P16') and (DocChecksum=Before),'native gradient save/open preserves pixels');
  ClipboardCopy(1,3,11,9,False); Check(SaveImage('GRAD.CLP',False),'save gradient clipboard');
  ClearClipboard; Check(LoadImage('GRAD.CLP'),'reload gradient clipboard');
  InitBlankDoc(6); DocBeginAction; ClipboardPaste(17,23,False,0); DocCommitAction;
  for Y:=0 to 8 do for X:=0 to 10 do
    Check(DocPixel(17+X,23+Y)=PaintColor(1+X,3+Y,GradientPaint),'clipboard preserves source pixels at a new phase');
  for I:=0 to 15 do
  begin DocSetPixel(I,0,I); Check(DocPixel(I,0)=I,'literal writes remain literal under gradient paint') end;
  {Leave a reviewable framebuffer with the original demo and active selector.}
  InitUI; SetGradient(4,14,5); ForeColor:=GradientPaint; DrawUI;
  WriteLn('GRADIENT CHECKS PASSED: ',Assertions,' assertions; all 256 pairs / 11 ratios');
  GradientChecks:=F;
end;
