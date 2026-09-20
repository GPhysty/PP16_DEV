unit TMouse;
{$mode tp}{$H-}{$R+}{$Q+}
interface
type TMouseState=record
  X,Y:Integer;
  Buttons,Pressed,Released:Byte;
end;
var MouseReady:Boolean;
    MouseError:String[80];
    MouseRawMaxX,MouseRawMaxY,MouseXScale:Word;
function InitMouse:Boolean;
procedure PollMouse(var State:TMouseState);
procedure UpdateButtons(NewButtons:Byte; var State:TMouseState);
procedure WarpMouse(X,Y:Word);
procedure DoneMouse;
implementation
uses Dos;

procedure UpdateButtons(NewButtons:Byte; var State:TMouseState);
begin
  NewButtons:=NewButtons and 3;
  State.Pressed:=NewButtons and (not State.Buttons);
  State.Released:=State.Buttons and (not NewButtons);
  State.Buttons:=NewButtons;
end;

function InitMouse:Boolean;
var R:Registers;
begin
  InitMouse:=False; MouseReady:=False;
  MouseError:='NO MOUSE DRIVER - ESC EXITS';
  {Inspect the vector before calling it: absent drivers may be null or IRET.}
  FillChar(R,SizeOf(R),0); R.AX:=$3533; MsDos(R);
  if ((R.ES=0) and (R.BX=0)) then Exit;
  if Mem[R.ES:R.BX]=$CF then Exit;
  FillChar(R,SizeOf(R),0); Intr($33,R);
  if R.AX<>$FFFF then Exit;
  {Reset leaves the driver's own cursor hidden. PP16 owns one software cursor.}
  R.AX:=7; R.CX:=0; R.DX:=639; Intr($33,R);
  R.AX:=8; R.CX:=0; R.DX:=199; Intr($33,R);
  R.AX:=4; R.CX:=639; R.DX:=199; Intr($33,R);
  R.AX:=3; Intr($33,R); MouseRawMaxX:=R.CX; MouseRawMaxY:=R.DX;
  MouseError:='UNSUPPORTED MOUSE RANGE - ESC EXITS';
  if MouseRawMaxY<>199 then Exit;
  if (MouseRawMaxX=638) or (MouseRawMaxX=639) then MouseXScale:=2
  else if MouseRawMaxX=319 then MouseXScale:=1 else Exit;
  R.AX:=4; R.CX:=0; R.DX:=0; Intr($33,R);
  R.AX:=3; Intr($33,R);
  if (R.CX<>0) or (R.DX<>0) then Exit;
  MouseReady:=True; MouseError:=''; InitMouse:=True;
  WarpMouse(160,100);
end;

procedure PollMouse(var State:TMouseState);
var R:Registers;
begin
  if not MouseReady then Exit;
  FillChar(R,SizeOf(R),0); R.AX:=3; Intr($33,R);
  State.X:=R.CX div MouseXScale;
  State.Y:=R.DX;
  if State.X>319 then State.X:=319;
  if State.Y>199 then State.Y:=199;
  UpdateButtons(R.BL,State);
end;

procedure WarpMouse(X,Y:Word);
var R:Registers;
begin
  if not MouseReady then Exit;
  if X>319 then X:=319; if Y>199 then Y:=199;
  FillChar(R,SizeOf(R),0); R.AX:=4;
  R.CX:=X*MouseXScale; R.DX:=Y; Intr($33,R);
end;

procedure DoneMouse;
begin MouseReady:=False end;
begin MouseReady:=False end.
