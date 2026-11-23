program ImpRun;
{$mode tp}{$H-}{$R+}{$Q+}{$M 8192,0,65536}
uses VMem,TVideo,TMouse,TCursor,TUI;
var PreviousExit:CodePointer; Failures:Word;
{$I STACKCHK.INC}
procedure CleanExit;
begin
  ExitProc:=PreviousExit;
  if GraphicsActive then HideCursor;
  DoneMouse; LeaveGraphics; ReleaseVideoMemory;
end;
begin
  WriteErrorsToStdErr:=False; PreviousExit:=ExitProc; ExitProc:=@CleanExit;
  if not ReserveVideoMemory then Halt(2);
  EnterGraphics; MarkUnusedStack; Failures:=ImportChecks; LeaveGraphics;
  if not CheckStackMargin then begin WriteLn('FAIL: import UI stack margin'); Inc(Failures) end;
  if Failures<>0 then Halt(1);
end.
