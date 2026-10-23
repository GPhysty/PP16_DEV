program PP16;
{$mode tp}{$H-}{$R+}{$Q+}{$M 8192,0,65536}
{$ifndef CPUI8086}{$fatal Requires i8086 compiler}{$endif}
uses Dos,VMem,TVideo,TMouse,TCursor,TUI;
var PreviousExit:CodePointer;
procedure CleanExit;
begin
  ExitProc:=PreviousExit;
  if GraphicsActive then HideCursor;
  DoneMouse; LeaveGraphics; ReleaseVideoMemory;
end;
begin
  WriteErrorsToStdErr:=False;
  PreviousExit:=ExitProc; ExitProc:=@CleanExit;
  {$ifdef FPC_MM_MEDIUM}
  WriteLn('PP16 M9 - real-mode 8086 / medium model');
  {$else}
  WriteLn('PP16 M9 - real-mode 8086 / small model');
  {$endif}
  WriteLn('Initial near heap bytes=',MemAvail);
  if not ReserveVideoMemory then begin WriteLn('REFUSED: ',VideoMemoryError); Halt(2) end;
  if ParamStr(1)='/PROBE' then begin WriteLn('MEMORY CHECK PASSED'); Halt(0) end;
  EnterGraphics; InitUI; DrawUI; InitMouse; RunUI;
  HideCursor; DoneMouse; LeaveGraphics;
  WriteLn('PP16 SESSION ENDED');
end.
