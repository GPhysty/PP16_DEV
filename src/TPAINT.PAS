unit TPaint;
{$mode tp}{$H-}{$R+}{$Q+}
interface
const GradientPaint=16;
type TPaintRow=array[0..31] of Byte;
var GradientFirst,GradientLast,GradientStep:Byte;
procedure InitPaint;
procedure SetGradient(First,Last,Step:Byte);
function SolidPaint(C:Byte):Byte;
function MixColor(X,Y:Integer; Step:Byte):Byte;
function PaintColor(X,Y:Integer; C:Byte):Byte;
procedure PaintReadRow(Y:Integer; var Row:TPaintRow);
implementation
{A dispersed 5x5 rank permutation inside a 2x2 ordered pattern. All ranks
 0..99 occur once in the resulting 10x10 tile: ten ranks per 10% step.}
const Rank:array[0..4,0..4] of Byte=(
      (0,17,7,20,10),(12,4,22,14,2),(24,9,19,6,16),
      (5,15,1,18,11),(21,13,8,23,3));
      Order:array[0..1,0..1] of Byte=((0,2),(3,1));
var Rows:array[0..9] of TPaintRow;
    RowIndex:array[0..63] of Byte;

function MixColor(X,Y:Integer; Step:Byte):Byte;
var R:Word;
begin
  X:=X mod 10; Y:=Y mod 10;
  R:=Word(Order[Y and 1,X and 1])*25+Rank[Y div 2,X div 2];
  if R<Word(Step)*10 then MixColor:=GradientLast
  else MixColor:=GradientFirst;
end;

procedure SetGradient(First,Last,Step:Byte);
var X,Y,P:Integer; Tile:array[0..4] of Byte;
begin
  GradientFirst:=First and 15; GradientLast:=Last and 15;
  if Step>10 then Step:=10;
  GradientStep:=Step;
  for Y:=0 to 9 do
  begin
    for X:=0 to 4 do
      Tile[X]:=(MixColor(X*2,Y,Step) shl 4) or MixColor(X*2+1,Y,Step);
    P:=0;
    for X:=0 to 31 do
    begin Rows[Y,X]:=Tile[P]; Inc(P); if P=5 then P:=0 end;
  end;
end;

procedure InitPaint;
var Y,R:Integer;
begin
  R:=0;
  for Y:=0 to 63 do
  begin RowIndex[Y]:=R; Inc(R); if R=10 then R:=0 end;
  SetGradient(0,15,5);
end;

function SolidPaint(C:Byte):Byte;
begin
  if C=GradientPaint then
    if (GradientStep=0) or (GradientFirst=GradientLast) then C:=GradientFirst
    else if GradientStep=10 then C:=GradientLast;
  SolidPaint:=C;
end;

function PaintColor(X,Y:Integer; C:Byte):Byte;
var B:Byte;
begin
  if C=GradientPaint then
  begin
    PaintColor:=0;
    if (X<0) or (Y<0) or (X>63) or (Y>63) then Exit;
    B:=Rows[RowIndex[Y],X shr 1];
    if Odd(X) then C:=B and 15 else C:=B shr 4;
  end;
  PaintColor:=C and 15;
end;

procedure PaintReadRow(Y:Integer; var Row:TPaintRow);
begin Move(Rows[RowIndex[Y]],Row,SizeOf(Row)) end;
end.
