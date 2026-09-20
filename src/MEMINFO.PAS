program MemInfo;
{$mode tp}{$H-}{$R+}{$Q+}{$M 8192,0,65536}
uses Dos;
var R: Registers; S, N: Word; E: DWord; T: Byte;
begin
 WriteErrorsToStdErr := False;
 WriteLn('BDA available KB=',MemW[$40:$13], ' installed KB=',MemW[$40:$15]);
 WriteLn('ROM signatures=',Mem[$FFFF:$E],',',Mem[$FC00:0]);
 FillChar(R,SizeOf(R),0); R.AH:=$52; MsDos(R);
 S:=MemW[R.ES:R.BX-2]; N:=0;
 repeat
  T:=Mem[S:0]; E:=DWord(S)+DWord(MemW[S:3])+1;
  WriteLn('MCB seg=',S,' type=',T,' owner=',MemW[S:1],' size=',MemW[S:3],' end=',E);
  if ((T<>$4D) and (T<>$5A)) or (E<=$100) or (E>$A000) then Halt(2);
  S:=Word(E); Inc(N);
 until (T=$5A) or (N>100);
end.
