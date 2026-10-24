  procedure CheckFilledShapes;
  var Tool,Size,X,Y:Integer; Original:DWord; Name:TFileName;

    procedure DumpPixels(const Name:String);
    var Output:File; Row:TDocRow; Y:Integer; N:Word;
    begin
      {$I-} Assign(Output,Name); Rewrite(Output,1);
      if IOResult<>0 then begin Check(False,'open filled-shape pixels'); Exit end;
      for Y:=0 to 63 do begin
        DocReadRow(Y,Row); BlockWrite(Output,Row,32,N);
        if (IOResult<>0) or (N<>32) then begin Check(False,'write filled-shape pixels'); Break end;
      end;
      Close(Output); Check(IOResult=0,'close filled-shape pixels'); {$I+}
    end;

    procedure Toggle(T:Integer);
    begin HandleClick(6+(T mod 4)*19,41,2) end;

  begin
    ResetTest; DrawUI;
    Toggle(5);
    Check((SelectedTool=5) and ToolFilled(5) and not ToolFilled(6),
          'right click selects filled circle independently');
    Toggle(6); Toggle(5);
    Check((SelectedTool=5) and not ToolFilled(5) and ToolFilled(6),
          'right click toggles back and preserves other tool mode');
    HandleClick(44,41,1);
    Check((SelectedTool=6) and ToolFilled(6),'left click retains filled mode');
    HandleClick(39,41,2);
    Check((SelectedTool=6) and not ToolFilled(5),'toolbar gap does not toggle a shape');
    {Matched raw documents let the host oracle flood the existing outline
     mask without adding files to the native Open dialog's fixture list.}
    for Tool:=5 to 6 do for Size:=1 to 5 do begin
      ResetTest; InitBlankDoc(11); DrawUI;
      SelectedTool:=Tool; BrushSize:=Size; ForeColor:=3; BackColor:=4;
      AtDoc(24,24,1); AtDoc(36,36,0); PaintChanges;
      Name:='O'+Num(Tool)+Num(Size)+'.RAW'; DumpPixels(Name);
      DocUndo; PaintChanges;
      Toggle(Tool); Original:=DocChecksum;
      AtDoc(24,24,1); AtDoc(36,36,1);
      Check((DocChecksum=Original) and not DocDirty,
            'filled shape retains canvas-only dashed guide until release');
      AtDoc(36,36,0); PaintChanges;
      if Tool=5 then Check(DocPixel(24,24)=4,'circle center uses secondary fill')
      else Check(DocPixel(30,30)=4,'square interior uses secondary fill');
      Check((DocPixel(36,24)=3) and (DocPixel(0,0)=11) and DocCanUndo,
            'primary border and exterior are preserved');
      if Size=3 then begin DrawUI; DumpGuide('F'+Num(Tool)+'.BIN') end;
      Name:='F'+Num(Tool)+Num(Size)+'.RAW'; DumpPixels(Name);
      DocUndo; PaintChanges;
      Check((DocChecksum=Original) and not DocDirty and not DocCanUndo,
            'filled shape is one undo action');
    end;
    for Tool:=5 to 6 do begin
      ResetTest; InitBlankDoc(9); DrawUI; Toggle(Tool);
      SetGradient(4,14,5); ForeColor:=GradientPaint; BackColor:=0; BrushSize:=3;
      Original:=DocChecksum;
      AtDoc(24,24,1); AtDoc(36,36,1);
      KeyInput(27,1,1); AtDoc(36,36,0);
      Check((DocChecksum=Original) and not DocDirty,'Escape cancels a filled shape');
      AtDoc(24,24,1);
      BackColor:=2; FilledShapeTools[Tool]:=False; BrushSize:=1; ForeColor:=1;
      AtDoc(36,36,0); PaintChanges;
      if Tool=5 then Check(DocPixel(24,24)=0,'circle captures black secondary at press')
      else Check(DocPixel(30,30)=0,'square captures black secondary at press');
      Check((DocPixel(36,24)=PaintColor(36,24,GradientPaint)) and
            (DocPixel(36,23)=PaintColor(36,23,GradientPaint)),
            'filled shape captures primary dither and border thickness');
      DocUndo; PaintChanges;
      Check((DocChecksum=Original) and not DocDirty,'filled dither undo restores artwork');
      {A zero-radius shape has no fill area, even with a contrasting secondary.}
      ResetTest; InitBlankDoc(3); DrawUI; Toggle(Tool);
      ForeColor:=3; BackColor:=4; BrushSize:=5;
      AtDoc(10,10,1); AtDoc(10,10,0); PaintChanges;
      Check(not DocDirty and not DocCanUndo,'tiny unchanged filled shape remains a no-op');
      ResetTest; InitBlankDoc(9); DrawUI; Toggle(Tool);
      ForeColor:=3; BackColor:=0;
      AtDoc(0,0,1); AtDoc(12,12,0); PaintChanges;
      Check((DocPixel(3,3)=0) and (DocPixel(63,63)=9),
            'filled shape clips at top and left image edges');
      AtDoc(63,63,1); AtDoc(51,51,0); PaintChanges;
      Check((DocPixel(60,60)=0) and (DocPixel(32,32)=9),
            'filled shape clips at bottom and right image edges');
      {Fill must replace mixed artwork, including isolated primary-color pixels.}
      ResetTest; InitBlankDoc(9);
      for Y:=10 to 40 do for X:=10 to 40 do DocSetPixel(X,Y,(X+Y) mod 16);
      DocSaved; DrawUI; Toggle(Tool); ForeColor:=3; BackColor:=4;
      AtDoc(24,24,1); AtDoc(36,36,0); PaintChanges;
      if Tool=5 then Check(DocPixel(24,24)=4,'circle fill covers existing artwork')
      else Check(DocPixel(30,30)=4,'square fill covers existing artwork');
    end;
  end;
