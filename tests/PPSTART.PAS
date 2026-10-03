program PPStart;
{$mode tp}{$H-}{$R+}{$Q+}{$M 8192,0,4096}
uses Dos;
type TMouseStep=record X,Y:Word; Buttons,Count:Byte end;
     TFarParts=packed record Offset,Segment:Word end;
var Tail,E,MouseReads:Word; I,StepCount,StepIndex,StepLeft:Integer;
    Name:String[8]; Steps:array[0..11] of TMouseStep; OldMouse,NewMouse:FarPointer;
    NewMouseParts:TFarParts absolute NewMouse;

procedure FakeMouse(Flags,CodeSeg,IP,AX,BX,CX,DX,SI,DI,DataSeg,ES,BP:Word); interrupt;
begin
  case AX of
    0:begin AX:=$FFFF; BX:=2; MouseReads:=0 end;
    3:begin
        BX:=0;
        if MouseReads=0 then begin CX:=639; DX:=199 end
        else if MouseReads=1 then begin CX:=0; DX:=0 end
        else if StepIndex<StepCount then
        begin
          CX:=Steps[StepIndex].X*2; DX:=Steps[StepIndex].Y;
          BX:=Steps[StepIndex].Buttons;
          Dec(StepLeft);
          if StepLeft=0 then
          begin
            Inc(StepIndex);
            if StepIndex<StepCount then StepLeft:=Steps[StepIndex].Count;
          end;
        end;
        Inc(MouseReads);
      end;
  end;
end;

procedure MouseStep(X,Y:Word; Buttons,Count:Byte);
begin
  Steps[StepCount].X:=X; Steps[StepCount].Y:=Y;
  Steps[StepCount].Buttons:=Buttons; Steps[StepCount].Count:=Count;
  Inc(StepCount);
end;

procedure Key(C,Scan:Byte);
begin
  MemW[$40:Tail]:=(Word(Scan) shl 8) or C;
  Inc(Tail,2); if Tail=$3E then Tail:=$1E;
end;
begin
  {Drive the actual editor through its File menu and filename dialog.}
  Name:=ParamStr(2); if Name='' then Name:='PROD';
  StepCount:=0; StepIndex:=0; MouseReads:=0;
  MouseStep(4,3,0,1); MouseStep(4,3,1,1); MouseStep(4,3,0,1);
  if ParamStr(1)='/SAVE' then I:=34 else I:=25;
  MouseStep(15,I,0,1); MouseStep(15,I,1,1); MouseStep(15,I,0,1);
  MouseStep(15,I,0,Length(Name)+1);
  MouseStep(4,3,0,1); MouseStep(4,3,1,1); MouseStep(4,3,0,1);
  MouseStep(15,52,0,1); MouseStep(15,52,1,1);
  StepLeft:=Steps[0].Count;
  Tail:=$1E; MemW[$40:$1A]:=Tail;
  for I:=1 to 5 do Key(0,1);
  for I:=1 to Length(Name) do Key(Ord(Name[I]),1);
  Key(13,28); MemW[$40:$1C]:=Tail;
  NewMouseParts.Segment:=CSeg; NewMouseParts.Offset:=Ofs(FakeMouse);
  GetIntVec($33,OldMouse); SetIntVec($33,NewMouse);
  SwapVectors; Exec('PP16.EXE',''); SwapVectors;
  SetIntVec($33,OldMouse);
  E:=DosError; MemW[$40:$1C]:=MemW[$40:$1A];
  if (E<>0) or (DosExitCode<>0) then begin
    WriteLn('FAIL: production editor launch/exit ',E,'/',DosExitCode); Halt(1);
  end;
  WriteLn('PRODUCTION SESSION PASSED');
end.
