unit VMem;
{$mode tp}{$H-}{$R+}{$Q+}
interface
var VideoMemoryError: String[100];
    ReservedSegment, ArenaEnd: Word;
function ReserveVideoMemory: Boolean;
procedure ReleaseVideoMemory;
implementation
uses Dos;
const VideoStart = $9800; {640K HX: highest 32K of shared RAM}
var Held: Boolean;

function ReserveVideoMemory: Boolean;
var R: Registers; S, Last, Strategy, Count: Word;
    Next: DWord; Kind: Byte; Allocated: Boolean;
begin
  ReserveVideoMemory:=False;
  VideoMemoryError:='Unsupported machine: requires Tandy with 640K installed';
  if (Mem[$FFFF:$E]<>$FF) or (Mem[$FC00:0]<>$21) or
     (MemW[$40:$15]<>640) then Exit;
  VideoMemoryError:='Invalid DOS conventional memory chain';
  FillChar(R,SizeOf(R),0); R.AH:=$52; MsDos(R);
  if R.BX<2 then Exit;
  S:=MemW[R.ES:R.BX-2]; Count:=0;
  repeat
    if (S<$50) or (S>=$A000) then Exit;
    Kind:=Mem[S:0];
    if (Kind<>$4D) and (Kind<>$5A) then Exit;
    Next:=DWord(S)+DWord(MemW[S:3])+1;
    if (Next>$A000) or (Next<=S) then Exit;
    Last:=S; S:=Word(Next); Inc(Count);
    if Count>256 then Exit;
  until Kind=$5A;
  ArenaEnd:=S;
  if S<=VideoStart then
  begin
    VideoMemoryError:='DOS/BIOS reservation disagrees';
    if MemW[$40:$13]>608 then Exit;
    ReservedSegment:=0;
    VideoMemoryError:=''; ReserveVideoMemory:=True; Exit;
  end;
  {Only a terminal FREE block can be split. Never write a live allocation.}
  VideoMemoryError:='Video RAM overlaps an existing DOS allocation';
  if (Last>=VideoStart-1) or (MemW[Last:1]<>0) then Exit;
  VideoMemoryError:='DOS allocation strategy unavailable';
  R.AX:=$5800; MsDos(R); if (R.Flags and 1)<>0 then Exit;
  Strategy:=R.AX;
  R.AX:=$5801; R.BX:=2; MsDos(R); if (R.Flags and 1)<>0 then Exit;
  R.AH:=$48; R.BX:=ArenaEnd-VideoStart; MsDos(R);
  Allocated:=(R.Flags and 1)=0; ReservedSegment:=R.AX;
  R.AX:=$5801; R.BX:=Strategy; MsDos(R);
  VideoMemoryError:='Could not restore DOS allocation strategy';
  if (R.Flags and 1)<>0 then
  begin
    if Allocated then begin R.AH:=$49; R.ES:=ReservedSegment; MsDos(R) end;
    Exit;
  end;
  VideoMemoryError:='Cannot acquire the exact shared video memory range';
  if not Allocated then Exit;
  Held:=True;
  if (ReservedSegment<>VideoStart) or
     (MemW[ReservedSegment-1:1]<>PrefixSeg) or
     (DWord(ReservedSegment)+MemW[ReservedSegment-1:3]<>ArenaEnd) then
  begin ReleaseVideoMemory; Exit end;
  VideoMemoryError:=''; ReserveVideoMemory:=True;
end;

procedure ReleaseVideoMemory;
var R: Registers;
begin
  if Held then
  begin
    FillChar(R,SizeOf(R),0); R.AH:=$49; R.ES:=ReservedSegment; MsDos(R);
    Held:=False;
  end;
end;
begin
  Held:=False; ReservedSegment:=0;
end.
