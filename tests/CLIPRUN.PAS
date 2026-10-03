program ClipRun;
{$mode tp}{$H-}{$R+}{$Q+}{$M 8192,0,65536}
uses VMem,TVideo,TMouse,TCursor,TUI;
var PreviousExit:NearCsPointer; Failures:Word;
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
  EnterGraphics; Failures:=ClipChecks; LeaveGraphics;
  if Failures<>0 then begin WriteLn('FAIL: clipboard UI ',Failures); Halt(1) end;
  WriteLn('M9 CHECKS PASSED');
end.
