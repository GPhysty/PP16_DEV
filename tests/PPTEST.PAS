program PP16;
{$mode tp}{$H-}{$R+}{$Q+}{$M 8192,0,65536}
{$ifndef CPUI8086}{$fatal Requires i8086 compiler}{$endif}
{$ifndef MSDOS}{$fatal Requires real-mode DOS}{$endif}
uses Dos, VMem, TVideo, TMouse, TCursor
{$ifndef PP16_VIDEO_TEST},TUI{$endif};
var Failures:Word; AutoTest, Dump, Probe:Boolean; Pass:Integer;
    PreviousExit:NearCsPointer; InitialHeap:LongInt;
    MouseTest,NoMouseTest,LegacyDemo:Boolean;
    UITest,UIDump,ShellMode,MouseDemo,DrawingTest,UndoTest,PerfTest,ResponseTest,ClipTest:Boolean;

function ReadKey:Byte; forward;

procedure CleanExit;
begin
  ExitProc:=PreviousExit;
  if GraphicsActive then HideCursor;
  DoneMouse;
  LeaveGraphics;
  ReleaseVideoMemory;
end;

procedure Check(OK:Boolean; const What:String);
begin
  if not OK then begin Inc(Failures); WriteLn('FAIL: ',What) end;
end;

{$ifdef PP16_VIDEO_TEST}
procedure TestPixels;
var X,Y,I:Integer; A:Word;
begin
  {Bank padding guards: 192 unused bytes in each 8192-byte bank.}
  for I:=0 to 3 do
    for A:=8000 to 8191 do Mem[VideoSeg:Word(I)*8192+A]:=$A5;
  FillBox(0,0,319,199,0);
  PutPixel(0,0,1);
  Check(Mem[$9800:0]=$10,'B800 maps to owned physical video page');
  PutPixel(0,0,0);
  {Independent literal offsets verify first rows, bank transition and bottom.}
  Check(PixelOffset(0,0)=0,'row 0 address');
  Check(PixelOffset(0,1)=8192,'row 1 address');
  Check(PixelOffset(0,2)=16384,'row 2 address');
  Check(PixelOffset(0,3)=24576,'row 3 address');
  Check(PixelOffset(0,4)=160,'row 4 address');
  Check(PixelOffset(319,199)=32575,'last pixel address');
  for Y:=0 to 199 do
  begin
    X:=(Y*37) mod 318; X:=X and $7FFE;
    A:=PixelOffset(X,Y); Mem[VideoSeg:A]:=$A5;
    PutPixel(X,Y,3); Check(Mem[VideoSeg:A]=$35,'even nibble preserves odd');
    PutPixel(X+1,Y,12); Check(Mem[VideoSeg:A]=$3C,'odd nibble preserves even');
    Check((GetPixel(X,Y)=3) and (GetPixel(X+1,Y)=12),'pixel readback');
  end;
  {Compare span against a per-pixel oracle, every byte of two complete rows.}
  for I:=0 to 15 do
  begin
    HSpan(0,319,40,6); HSpan(0,319,41,6);
    HSpan(I-5,310+I,40,I);
    for X:=I-5 to 310+I do PutPixel(X,41,I);
    for A:=0 to 159 do
      Check(Mem[VideoSeg:PixelOffset(0,40)+A]=
            Mem[VideoSeg:PixelOffset(0,41)+A],'span/reference equality');
  end;
  FillBox(0,0,319,199,2);
  PutPixel(-32768,0,15); PutPixel(32767,199,15);
  PutPixel(0,-32768,15); PutPixel(319,32767,15);
  HSpan(10,9,0,15); HSpan(0,319,-1,15); HSpan(0,319,200,15);
  FillBox(-5,-5,-1,210,15); FillBox(320,-5,32767,210,15);
  {Sweep raw bytes to catch clipped writes anywhere in the visible page.}
  for Y:=0 to 199 do
    for A:=0 to 159 do Check(Mem[VideoSeg:PixelOffset(0,Y)+A]=$22,'clipping');
  FillBox(-5,-5,1,1,4);
  Check((GetPixel(0,0)=4) and (GetPixel(1,1)=4) and
        (GetPixel(2,1)=2) and (GetPixel(1,2)=2),'clipped box edges');
  for I:=0 to 3 do
    for A:=8000 to 8191 do
      Check(Mem[VideoSeg:Word(I)*8192+A]=$A5,'bank padding guard');
end;
{$endif}

procedure Demo;
var I:Integer;
begin
  FillBox(0,0,319,199,0);
  for I:=0 to 7 do begin HSpan(0,319,I,I+1); HSpan(0,319,192+I,15-I) end;
  Text8(16,18,'PP16 - TANDY M1',15);
  Text8(16,30,'320 X 200 / 16 COLORS',7);
  for I:=0 to 15 do
  begin
    FillBox(9+I*19,49,25+I*19,84,7);
    FillBox(10+I*19,50,24+I*19,83,I);
  end;
  Text8(16,96,'PIXEL  SPAN  FILLED BOX',15);
  PutPixel(24,116,15); PutPixel(25,116,12);
  HSpan(80,143,116,11); HSpan(87,136,120,3);
  FillBox(184,110,288,137,4); FillBox(192,118,280,129,12);
  Text8(16,151,'R: REPEAT   ESC: EXIT',14);
  Text8(16,165,'8086 / NO FPU / MODE 9',7);
  FillBox(0,8,3,15,15); FillBox(316,8,319,15,12);
  FillBox(0,184,3,191,10); FillBox(316,184,319,191,9);
  PutPixel(0,0,15); PutPixel(319,0,12);
  PutPixel(0,199,10); PutPixel(319,199,9);
  Check(GetPixel(0,0)=15,'top left'); Check(GetPixel(319,0)=12,'top right');
  Check(GetPixel(0,199)=10,'bottom left'); Check(GetPixel(319,199)=9,'bottom right');
end;

function KeyPending:Boolean;
var R:Registers;
begin
  FillChar(R,SizeOf(R),0); R.AH:=1; Intr($16,R);
  KeyPending:=(R.Flags and $40)=0;
end;

procedure MouseChecks;
var S:TMouseState; I,X,Y:Integer; Row:TRow; A:Word;
begin
  FillChar(S,SizeOf(S),0);
  if NoMouseTest then begin Check(not MouseReady,'absent driver rejected'); Exit end;
  Check(MouseReady,'INT 33h driver detected');
  if not MouseReady then Exit;
  for I:=0 to 3 do
  begin
    X:=(I and 1)*319; Y:=(I shr 1)*199;
    WarpMouse(X,Y); PollMouse(S);
    Check((S.X=X) and (S.Y=Y),'mouse reaches corner');
  end;
  {All horizontal and vertical positions survive normalization exactly once.}
  for X:=0 to 319 do begin WarpMouse(X,100); PollMouse(S); Check(S.X=X,'mouse X mapping') end;
  for Y:=0 to 199 do begin WarpMouse(160,Y); PollMouse(S); Check(S.Y=Y,'mouse Y mapping') end;
  FillChar(S,SizeOf(S),0);
  UpdateButtons(1,S); Check((S.Pressed=1) and (S.Released=0),'left press');
  UpdateButtons(1,S); Check((S.Pressed=0) and (S.Released=0),'left held');
  UpdateButtons(3,S); Check((S.Pressed=2) and (S.Buttons=3),'both buttons');
  UpdateButtons(2,S); Check(S.Released=1,'left release');
  UpdateButtons(0,S); Check(S.Released=2,'right release');
  {Compare each raw row before/after many clipped and overlapping cursor moves.}
  for Y:=0 to 199 do
  begin
    for A:=0 to 159 do Row[A]:=Mem[VideoSeg:PixelOffset(0,Y)+A];
    for I:=0 to 3 do
    begin ShowCursor(I*106,Y); ShowCursor(I*106+1,Y); HideCursor end;
    if Y<10 then begin ShowCursor(-7,-9); ShowCursor(-1,-1); HideCursor end;
    for A:=0 to 159 do Check(Row[A]=Mem[VideoSeg:PixelOffset(0,Y)+A],'cursor restores background');
  end;
  WarpMouse(160,100);
end;

procedure MouseStatus(const S:TMouseState; const Event:String);
var Line:String[39]; SX,SY:String[3];
begin
  Str(S.X:3,SX); Str(S.Y:3,SY);
  Line:='X:'+SX+' Y:'+SY+' L:';
  if (S.Buttons and 1)<>0 then Line:=Line+'DOWN ' else Line:=Line+'UP   ';
  Line:=Line+'R:';
  if (S.Buttons and 2)<>0 then Line:=Line+'DOWN' else Line:=Line+'UP  ';
  FillBox(8,144,311,175,0);
  Text8(8,144,Line,15); Text8(8,156,Event,14);
  Text8(8,168,'ESC: EXIT  R: REDRAW',7);
end;

procedure MouseLoop;
var S,Old:TMouseState; Event:String[30]; K:Byte; R:Registers;
begin
  FillBox(8,16,311,39,0); Text8(16,18,'PP16 - MOUSE CHECKPOINT',15);
  Text8(16,30,'MOVE / CLICK / HOLD / RELEASE',7);
  if not MouseReady then
  begin
    FillBox(0,144,319,177,0); Text8(0,148,MouseError,14);
    repeat K:=ReadKey until K=27;
    Exit;
  end;
  FillChar(S,SizeOf(S),0); PollMouse(S); Old:=S;
  Event:='READY'; MouseStatus(S,Event); ShowCursor(S.X,S.Y);
  repeat
    K:=0;
    if KeyPending then K:=ReadKey;
    PollMouse(S);
    if (S.X<>Old.X) or (S.Y<>Old.Y) or (S.Buttons<>Old.Buttons) or
       (K=Ord('r')) or (K=Ord('R')) then
    begin
      HideCursor;
      if (K=Ord('r')) or (K=Ord('R')) then
      begin Demo; FillBox(8,16,311,39,0); Text8(16,18,'PP16 - MOUSE CHECKPOINT',15) end;
      if S.Pressed<>0 then Event:='PRESS'
      else if S.Released<>0 then Event:='RELEASE'
      else if S.Buttons<>0 then Event:='DRAG' else Event:='MOVE';
      MouseStatus(S,Event); ShowCursor(S.X,S.Y); Old:=S;
    end;
    {No idle repaint. Yield to DOS background services between polls.}
    FillChar(R,SizeOf(R),0); Intr($28,R);
  until K=27;
  HideCursor;
end;

procedure DumpPage(const Name:String);
var F:File; Row:TRow; Y,I:Integer; N:Word;
begin
  {$I-} Assign(F,Name); Rewrite(F,1);
  if IOResult<>0 then begin Check(False,'open frame dump'); Exit end;
  for Y:=0 to 199 do
  begin
    for I:=0 to 159 do Row[I]:=Mem[VideoSeg:PixelOffset(0,Y)+Word(I)];
    BlockWrite(F,Row,160,N);
    if (IOResult<>0) or (N<>160) then begin Check(False,'write frame dump'); Break end;
  end;
  Close(F); Check(IOResult=0,'close frame dump'); {$I+}
end;

function ReadKey:Byte;
var R:Registers;
begin FillChar(R,SizeOf(R),0); Intr($16,R); ReadKey:=R.AL end;

var K:Byte; R:Registers; Scene:Integer; SceneName:String[3];
begin
  WriteErrorsToStdErr:=False; Failures:=0; Pass:=0;
  AutoTest:=ParamStr(1)='/TEST'; Dump:=ParamStr(1)='/DUMP';
  MouseTest:=ParamStr(1)='/MTEST'; NoMouseTest:=ParamStr(1)='/NTEST';
  LegacyDemo:=ParamStr(1)='/M1';
  MouseDemo:=ParamStr(1)='/M2';
  DrawingTest:=ParamStr(1)='/DRAWTEST';
  UndoTest:=ParamStr(1)='/UNDOTEST';
  PerfTest:=ParamStr(1)='/PERF';
  ResponseTest:=ParamStr(1)='/RESP';
  ClipTest:=ParamStr(1)='/CLIPTEST';
  if ResponseTest then PerfTest:=True;
  UITest:=ParamStr(1)='/UITEST'; UIDump:=ParamStr(1)='/UIDUMP';
  ShellMode:=not (AutoTest or Dump or MouseTest or NoMouseTest or LegacyDemo or MouseDemo);
  Probe:=ParamStr(1)='/PROBE'; InitialHeap:=MemAvail;
  PreviousExit:=ExitProc; ExitProc:=@CleanExit;
  WriteLn('PP16 M9 - real-mode 8086 / small model');
  if not ReserveVideoMemory then begin WriteLn('REFUSED: ',VideoMemoryError); Halt(2) end;
  WriteLn('Video page physical 98000..9FFFF; DOS arena end paragraph=',ArenaEnd);
  WriteLn('Owned DOS block segment=',ReservedSegment,' (0=pre-reserved)');
  WriteLn('BIOS available KB=',MemW[$40:$13],'; initial near heap bytes=',InitialHeap);
  if Probe then begin WriteLn('MEMORY CHECK PASSED'); Halt(0) end;
  repeat
    Inc(Pass); EnterGraphics;
    {$ifdef PP16_VIDEO_TEST}
    if AutoTest then TestPixels;
    Demo;
    {$else}
    InitUI; DrawUI;
    {$endif}
    {$ifdef PP16_VIEW_TEST}
    if UITest then Check(ViewChecks=0,'view mapping and UI dispatch');
    {$endif}
    {$ifdef PP16_DRAW_TEST}
    if DrawingTest then begin Check(DrawChecks=0,'drawing and shape acceptance'); DumpPage('M7FRAME.BIN') end;
    {$endif}
    {$ifdef PP16_UNDO_TEST}
    if UndoTest then begin Check(UndoChecks=0,'undo acceptance'); DumpPage('M5FRAME.BIN') end;
    {$endif}
    {$ifdef PP16_FILEUI_TEST}
    if ParamStr(1)='/FILEUI' then begin
      Check(FileUIChecks=0,'file dialog acceptance'); DumpPage('FILEUI.BIN');
    end;
    {$endif}
    {$ifdef PP16_CLIP_TEST}
    if ClipTest then begin Check(ClipChecks=0,'selection and clipboard acceptance'); DumpPage('M9FRAME.BIN') end;
    {$endif}
    {$ifndef PP16_VIDEO_TEST}
    {$ifdef PP16_RESPONSE_TEST}
    if PerfTest then
      if ResponseTest then begin
        PerfCase(10); Check(ResponseChecks=0,'response acceptance');
        DumpPage('RESPONSE.BIN'); HideCursor;
      end
      else for Scene:=0 to 9 do
      begin
        PerfCase(Scene); Str(Scene,SceneName); DumpPage('P'+SceneName+'.BIN');
        DrawUI; DumpPage('R'+SceneName+'.BIN');
      end;
    {$endif}
    {$endif}
    {$ifdef PP16_VIDEO_TEST}
    if MouseTest or NoMouseTest or MouseDemo or (ShellMode and not UITest and not UIDump and not DrawingTest and not UndoTest and not PerfTest) then
    begin
      InitMouse;
      if MouseTest or NoMouseTest then MouseChecks;
    end;
    if Dump then DumpPage('M1FRAME.BIN');
    {$endif}
    {$ifdef PP16_VIEW_TEST}
    if UITest or UIDump then DumpPage('M3FRAME.BIN');
    if UITest or UIDump then
    begin
      ShowReferenceMenu(0); DumpPage('M3FILE.BIN');
      ShowReferenceMenu(2); DumpPage('M3VIEW.BIN');
      ShowReferenceMenu(3); DumpPage('M3ACTION.BIN');
    end;
    {$endif}
    K:=27;
    DoneMouse;
    LeaveGraphics;
    FillChar(R,SizeOf(R),0); R.AH:=$0F; Intr($10,R);
    Check(R.AL in [0,1,2,3,7],'text mode restored');
    WriteLn('Pass ',Pass,': cumulative failures=',Failures);
  until (AutoTest and (Pass=3)) or ((not AutoTest) and (K<>Ord('r')) and (K<>Ord('R')));
  if Failures<>0 then Halt(1);
  if MouseTest then
  begin
    WriteLn('Mouse raw maximum=',MouseRawMaxX,',',MouseRawMaxY,' X scale=',MouseXScale);
    WriteLn('M2 CHECKS PASSED');
  end
  else if ParamStr(1)='/FILEUI' then WriteLn('M6 UI CHECKS PASSED')
  else if PerfTest then WriteLn('UI PERF CHECKS PASSED')
  else if UndoTest then WriteLn('M5 CHECKS PASSED')
  else if ClipTest then WriteLn('M9 CHECKS PASSED')
  else if DrawingTest then WriteLn('M8 CHECKS PASSED')
  else if UITest then WriteLn('M3 CHECKS PASSED')
  else if ShellMode then WriteLn('PP16 VIEW SESSION ENDED')
  else if NoMouseTest then WriteLn('MISSING DRIVER CHECK PASSED')
  else
  WriteLn('M1 CHECKS PASSED');
end.
