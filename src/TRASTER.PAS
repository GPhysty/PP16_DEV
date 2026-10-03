unit TRaster;
{$mode tp}{$H-}{$R+}{$Q+}
interface
type TPlotProc=procedure(X,Y,C:Integer);
procedure RasterStamp(X,Y,C,Size:Integer; Plot:TPlotProc);
procedure RasterLine(X1,Y1,X2,Y2,C:Integer; Plot:TPlotProc);
procedure RasterSquare(X1,Y1,X2,Y2,C:Integer; Plot:TPlotProc);
procedure RasterCircle(X1,Y1,X2,Y2,C:Integer; Plot:TPlotProc);
function EllipseInset(Y,W,H:Integer):Integer;
implementation
function EllipseInset(Y,W,H:Integer):Integer;
{Return the symmetric excluded-pixel count for row Y. Pixel-center geometry
 keeps marquee, copy, cut and paste on the same integer ellipse.}
var X,DX,DY:Integer; W2,H2,Limit:DWord;
begin
  W2:=DWord(W)*Word(W); H2:=DWord(H)*Word(H);
  DY:=2*Y+1-H; Limit:=W2*(H2-DWord(DY*DY));
  X:=0; DX:=W-1;
  while (X<W div 2) and (DWord(DX*DX)*H2>Limit) do
  begin Inc(X); Dec(DX,2) end;
  EllipseInset:=X;
end;


procedure RasterStamp(X,Y,C,Size:Integer; Plot:TPlotProc);
var X1,Y1,X2,Y2,PX,PY:Integer;
begin
  {A brush is a square stamp centred on its pointer pixel. Even sizes have
   one extra pixel on the lower/right side, avoiding a hidden half-pixel
   coordinate.}
  if Size<1 then Size:=1;
  X1:=X-(Size-1) div 2; X2:=X+Size div 2;
  Y1:=Y-(Size-1) div 2; Y2:=Y+Size div 2;
  for PY:=Y1 to Y2 do for PX:=X1 to X2 do Plot(PX,PY,C);
end;

procedure RasterLine(X1,Y1,X2,Y2,C:Integer; Plot:TPlotProc);
var DX,DY,SX,SY,E,E2:Integer;
begin
  DX:=Abs(X2-X1); DY:=-Abs(Y2-Y1);
  if X1<X2 then SX:=1 else SX:=-1;
  if Y1<Y2 then SY:=1 else SY:=-1;
  E:=DX+DY;
  repeat
    Plot(X1,Y1,C);
    if (X1=X2) and (Y1=Y2) then Break;
    E2:=2*E;
    if E2>=DY then begin E:=E+DY; X1:=X1+SX end;
    if E2<=DX then begin E:=E+DX; Y1:=Y1+SY end;
  until False;
end;

procedure RasterSquare(X1,Y1,X2,Y2,C:Integer; Plot:TPlotProc);
var Side,SX,SY,Limit:Integer;
begin
  Side:=Abs(X2-X1); if Abs(Y2-Y1)>Side then Side:=Abs(Y2-Y1);
  if X2<X1 then SX:=-1 else SX:=1;
  if Y2<Y1 then SY:=-1 else SY:=1;
  if SX>0 then Limit:=63-X1 else Limit:=X1;
  if Side>Limit then Side:=Limit;
  if SY>0 then Limit:=63-Y1 else Limit:=Y1;
  if Side>Limit then Side:=Limit;
  X2:=X1+SX*Side; Y2:=Y1+SY*Side;
  RasterLine(X1,Y1,X2,Y1,C,Plot); RasterLine(X2,Y1,X2,Y2,C,Plot);
  RasterLine(X2,Y2,X1,Y2,C,Plot); RasterLine(X1,Y2,X1,Y1,C,Plot);
end;

procedure RasterCircle(X1,Y1,X2,Y2,C:Integer; Plot:TPlotProc);
var R,X,Y,D:Integer;
begin
  R:=Abs(X2-X1); if Abs(Y2-Y1)>R then R:=Abs(Y2-Y1);
  X:=R; Y:=0; D:=1-R;
  while X>=Y do
  begin
    Plot(X1+X,Y1+Y,C); Plot(X1+Y,Y1+X,C);
    Plot(X1-Y,Y1+X,C); Plot(X1-X,Y1+Y,C);
    Plot(X1-X,Y1-Y,C); Plot(X1-Y,Y1-X,C);
    Plot(X1+Y,Y1-X,C); Plot(X1+X,Y1-Y,C);
    Inc(Y);
    if D<0 then D:=D+2*Y+1
    else begin Dec(X); D:=D+2*(Y-X)+1 end;
  end;
end;
end.
