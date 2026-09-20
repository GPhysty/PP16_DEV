program PPStart;
{$mode tp}{$H-}{$R+}{$Q+}{$M 8192,0,4096}
uses Dos;
var Tail,E:Word; I:Integer; Name:String[8];
procedure Key(C,Scan:Byte);
begin
  MemW[$40:Tail]:=(Word(Scan) shl 8) or C;
  Inc(Tail,2); if Tail=$3E then Tail:=$1E;
end;
begin
  {Feed a bounded BIOS key sequence to the actual editor, then clear leftovers.}
  Name:=ParamStr(2); if Name='' then Name:='PROD';
  Tail:=$1E; MemW[$40:$1A]:=Tail;
  if ParamStr(1)='/SAVE' then Key(19,31) else Key(15,24);
  for I:=1 to Length(Name) do Key(Ord(Name[I]),1);
  Key(13,28); Key(27,1); Key(27,1); Key(27,1); MemW[$40:$1C]:=Tail;
  SwapVectors; Exec('PP16.EXE',''); SwapVectors;
  E:=DosError; MemW[$40:$1C]:=MemW[$40:$1A];
  if (E<>0) or (DosExitCode<>0) then begin
    WriteLn('FAIL: production editor launch/exit ',E,'/',DosExitCode); Halt(1);
  end;
  WriteLn('PRODUCTION SESSION PASSED');
end.
