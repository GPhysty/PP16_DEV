{Test-only stack watermark. Leave 512 bytes below the current SP untouched
 while marking, so the marker cannot overwrite its frame or interrupt scratch.}
var StackMarkLow,StackMarkHigh:Word;
function CurrentSP:Word; assembler;
asm mov ax,sp end;
procedure MarkUnusedStack;
var I,P:Word;
begin
  StackMarkLow:=Ofs(StackBottom^); P:=CurrentSP;
  StackMarkHigh:=P-512;
  for I:=StackMarkLow to StackMarkHigh do Mem[SSeg:I]:=$A5;
end;
function CheckStackMargin:Boolean;
var I,Unused:Word;
begin
  I:=StackMarkLow;
  while (I<=StackMarkHigh) and (Mem[SSeg:I]=$A5) do Inc(I);
  Unused:=I-StackMarkLow;
  WriteLn('STACK UNUSED BOTTOM=',Unused,' ESTIMATED MAX USED=',StackLength-Unused);
  CheckStackMargin:=Unused>=1024;
end;
