  procedure CheckShapeGuides;
  var Tool,Z,PX,PY,DX,DY,Offset:Integer; Expected,Seen:Byte;
      Clean:Boolean; BeforeShape:DWord;

    function CanvasColor(X,Y:Integer):Byte;
    begin
      CanvasColor:=DocPixel(PanX+X div Zoom,PanY+Y div Zoom);
      if GridVisible and ((X mod Zoom=Zoom-1) or (Y mod Zoom=Zoom-1)) then
        CanvasColor:=8;
    end;

    procedure CheckCanvas(const Name:String);
    var X,Y:Integer;
    begin
      for Y:=0 to CanvasSize-1 do for X:=0 to CanvasSize-1 do
        if GetPixel(CanvasX+X,CanvasY+Y)<>CanvasColor(X,Y) then
        begin Check(False,Name); Exit end;
    end;

  begin
    for Tool:=5 to 7 do begin
      Z:=2;
      repeat
        ResetTest; SetZoom(Z); PanView(-64,-64);
        if Z>2 then PanView(8,9);
        GridVisible:=Odd(Tool+Z div 2);
        for DY:=0 to 63 do for DX:=0 to 63 do
          DocSetPixel(DX,DY,(DX+DY) mod 16);
        DocSaved; DrawUI; BeforeShape:=DocChecksum;
        SelectedTool:=Tool; BrushSize:=5;
        SetGradient(1,14,5); ForeColor:=GradientPaint;
        AtDoc(PanX+4,PanY+4,1); AtDoc(PanX+10,PanY+7,1);
        Clean:=True; Seen:=0;
        for PY:=0 to CanvasSize-1 do for PX:=0 to CanvasSize-1 do begin
          Expected:=CanvasColor(PX,PY);
          C:=GetPixel(CanvasX+PX,CanvasY+PY);
          if C<>Expected then begin
            if not (C in [7,8]) then Clean:=False;
            Seen:=1;
          end;
        end;
        Check(Clean and (Seen=1) and not DocDirty and
              (DocChecksum=BeforeShape),'positioning uses only a gray canvas guide');
        {This point belongs to the old outline, outside the shorter one.}
        Offset:=(Z-1) div 2; PX:=10*Z+Offset; PY:=4*Z+Offset;
        if Tool=7 then PY:=7*Z+Offset;
        AtDoc(PanX+8,PanY+9,1);
        Check(GetPixel(CanvasX+PX,CanvasY+PY)=CanvasColor(PX,PY),
              'moving a guide restores the old artwork and grid');
        KeyInput(27,1,1); AtDoc(PanX+8,PanY+9,0);
        Check((DocChecksum=BeforeShape) and not DocDirty,'guide cancel preserves artwork');
        CheckCanvas('guide cancel leaves no screen pixels behind');
        AtDoc(PanX+4,PanY+4,1); AtDoc(PanX+8,PanY+9,1);
        AtDoc(PanX+9,PanY+6,0); PaintChanges;
        Check(DocDirty and DocCanUndo,'guide release commits dithered thick shape');
        CheckCanvas('guide release restores all uncovered artwork and grid');
        DocUndo; PaintChanges;
        Check((DocChecksum=BeforeShape) and not DocDirty,'shape guide keeps one-action undo');
        Z:=Z*2;
      until Z>8;
      {Even a shape that paints no new pixels must erase its guide.}
      ResetTest; InitBlankDoc(4); DrawUI;
      SelectedTool:=Tool; ForeColor:=4;
      AtDoc(4,4,1); AtDoc(10,7,0); PaintChanges;
      Check(not DocDirty and not DocCanUndo,'same-color shape remains a no-op');
      CheckCanvas('same-color release removes the guide');
    end;
    ResetTest; DrawUI; SelectedTool:=7;
    AtDoc(3,3,1); AtDoc(8,8,1);
    Check((GetPixel(CanvasX+16,CanvasY+16) in [7,8]) and
          (GetPixel(CanvasX+17,CanvasY+17) in [7,8]) and
          (GetPixel(CanvasX+16,CanvasY+16)<>GetPixel(CanvasX+17,CanvasY+17)),
          'diagonal line guide alternates gray screen pixels');
    PutPixel(CanvasX+16,CanvasY+16,2);
    Feed(S.X+1,S.Y+1,1);
    Check(GetPixel(CanvasX+16,CanvasY+16)=2,'motion within one image pixel skips guide redraw');
    KeyInput(27,1,1); AtDoc(8,8,0);
    CheckCanvas('same-cell motion still cleans up on cancel');
    {Raw framebuffer pairs for visual review of positioning and final paint.}
    for Tool:=5 to 7 do begin
      ResetTest; SetZoom(4); PanView(-64,-64);
      SelectedTool:=Tool; BrushSize:=5; SetGradient(4,14,5);
      ForeColor:=GradientPaint; DrawUI;
      AtDoc(12,12,1); AtDoc(22,18,1);
      DumpGuide('G'+Num(Tool)+'.BIN');
      AtDoc(22,18,0); PaintChanges;
      DumpGuide('S'+Num(Tool)+'.BIN');
    end;
  end;
