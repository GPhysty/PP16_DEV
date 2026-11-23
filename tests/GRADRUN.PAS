program GradRun;
{$mode tp}{$H-}{$R+}{$Q+}{$M 8192,0,65536}
uses VMem,TVideo,TMouse,TCursor,TUI;
var PreviousExit:CodePointer; Failures:Word; Frame:File;
    X,Y:Integer; Row:array[0..159] of Byte;
procedure CleanExit;
begin
  ExitProc:=PreviousExit;
  if GraphicsActive then HideCursor;
  DoneMouse; LeaveGraphics; ReleaseVideoMemory;
end;
begin
  WriteErrorsToStdErr:=False;
  PreviousExit:=ExitProc; ExitProc:=@CleanExit;
  if not ReserveVideoMemory then Halt(2);
  EnterGraphics; Failures:=GradientChecks;
  Assign(Frame,'GRADUI.BIN'); Rewrite(Frame,1);
  for Y:=0 to 199 do
  begin
    for X:=0 to 159 do Row[X]:=(GetPixel(X*2,Y) shl 4) or GetPixel(X*2+1,Y);
    BlockWrite(Frame,Row,SizeOf(Row));
  end;
  Close(Frame); LeaveGraphics;
  if Failures<>0 then begin WriteLn('FAIL: gradient ',Failures); Halt(1) end;
end.
