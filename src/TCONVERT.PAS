unit TConvert;
{$mode tp}{$H-}{$R+}{$Q+}
{$ifndef CPUI8086}{$fatal Requires 8086 compiler}{$endif}
{$ifndef FPC_MM_MEDIUM}{$fatal Requires Medium memory model}{$endif}
interface
type TPalette=array[0..255,0..2] of Byte;
     TIndexRow=array[0..63] of Byte;
     TPackedRow=array[0..31] of Byte;
     {Temporary caller-owned state fits the editor's existing 8 KiB stack.
      It does not consume permanent near heap or overlay drawing buffers.}
     TConvertState=record
       SourcePalette:TPalette;
       Flags:array[0..255] of Byte;
       Errors:array[0..1,0..65,0..2] of LongInt;
       RowNumber:Integer; ImageWidth:Word;
     end;
procedure PreparePalette(var State:TConvertState);
procedure BeginImage(var State:TConvertState; Width:Word);
procedure ConvertRow(var State:TConvertState; const Source:TIndexRow; var Dest:TPackedRow);
implementation
{Exact-color fixed-point serpentine FS, validated by the isolated DOS study.
 Errors are Q4 linear RGB. Clamp before quantizing and propagating residuals.
 Named-parameter IMUL avoids the bundled checked LongInt multiply defect.}
{$I TCVTLUT.INC}
procedure PreparePalette(var State:TConvertState);
var I,J:Integer; R,G,B:Word;
begin
  with State do begin
    for I:=0 to 255 do begin
      Flags[I]:=0;
      if (SourcePalette[I,0]=SourcePalette[I,1]) and
         (SourcePalette[I,1]=SourcePalette[I,2]) then Flags[I]:=$80;

      {The generated 8-bit -> 12-bit LUT is strictly increasing. Equality of
       these linear values is therefore exact equality of the original bytes.
       Reuse existing tables and unused flag bits: no second palette/map.}
      R:=LinearLUT[SourcePalette[I,0]];
      G:=LinearLUT[SourcePalette[I,1]];
      B:=LinearLUT[SourcePalette[I,2]];
      for J:=0 to 15 do
        if (R=Target[J,0]) and (G=Target[J,1]) and (B=Target[J,2]) then begin
          Flags[I]:=Flags[I] or $10 or Byte(J); Break;
        end;
    end;
  end;
end;

procedure BeginImage(var State:TConvertState; Width:Word);
begin
  if (Width<1) or (Width>64) then Halt(91);
  State.ImageWidth:=Width; FillChar(State.Errors,SizeOf(State.Errors),0); State.RowNumber:=0;
end;

function Clamped(V:LongInt):LongInt;
begin
  if V<0 then Clamped:=0
  else if V>65520 then Clamped:=65520
  else Clamped:=V;
end;

function Round16(V:LongInt):LongInt;
begin
  if V<0 then Round16:=-((-V+8) shr 4)
  else Round16:=(V+8) shr 4;
end;

function Square16(V:Integer):LongInt; assembler;
asm
  {V is proved to be in -4095..4095. 8086 signed IMUL returns DX:AX.}
  mov ax,V
  imul ax
end;

function Nearest(R,G,B:Word; Neutral:Boolean):Byte;
var I,D:Integer; Score,Best,S:LongInt; Chosen:Byte;
begin
  Best:=2147483647; Chosen:=0;
  for I:=0 to 15 do
    if not Neutral or (I=0) or (I=7) or (I=8) or (I=15) then begin
      D:=Integer(R)-Integer(Target[I,0]); S:=Square16(D); Score:=S+(S shl 1);
      D:=Integer(G)-Integer(Target[I,1]); S:=Square16(D); Score:=Score+(S shl 2)+(S shl 1);
      D:=Integer(B)-Integer(Target[I,2]); Score:=Score+Square16(D);
      if Score<Best then begin Best:=Score; Chosen:=I end;
    end;
  Nearest:=Chosen;
end;

procedure ConvertRow(var State:TConvertState; const Source:TIndexRow; var Dest:TPackedRow);
var Current,Following,Direction,X,P,C:Integer;
    Index,Meta,Chosen:Byte;
    Values:array[0..2] of LongInt;
    E:LongInt;
begin
  with State do begin
    if RowNumber>=64 then Halt(91);
    Current:=RowNumber and 1; Following:=1-Current;
    FillChar(Errors[Following],SizeOf(Errors[Following]),0);
    Direction:=1; X:=0;
    if Current<>0 then begin Direction:=-1; X:=ImageWidth-1 end;
    FillChar(Dest,SizeOf(Dest),0);
    repeat
      P:=X+1; Index:=Source[X]; Meta:=Flags[Index];
      for C:=0 to 2 do Values[C]:=Clamped(
        (LongInt(LinearLUT[SourcePalette[Index,C]]) shl 4)+Errors[Current,P,C]);

      if (Meta and $10)<>0 then Chosen:=Meta and 15
      else
        Chosen:=Nearest(Word((Values[0]+8) shr 4),Word((Values[1]+8) shr 4),
                        Word((Values[2]+8) shr 4),(Meta and $80)<>0);
      if (X and 1)=0 then Dest[X shr 1]:=Dest[X shr 1] or (Chosen shl 4)
      else Dest[X shr 1]:=Dest[X shr 1] or Chosen;
      for C:=0 to 2 do begin
        E:=Values[C]-(LongInt(Target[Chosen,C]) shl 4);
        Errors[Current,P+Direction,C]:=Errors[Current,P+Direction,C]+Round16((E shl 3)-E);
        Errors[Following,P-Direction,C]:=Errors[Following,P-Direction,C]+Round16((E shl 1)+E);
        Errors[Following,P,C]:=Errors[Following,P,C]+Round16((E shl 2)+E);
        Errors[Following,P+Direction,C]:=Errors[Following,P+Direction,C]+Round16(E);
      end;
      Inc(X,Direction);
    until (X<0) or (X>=ImageWidth);
    Inc(RowNumber);
  end;
end;
end.
