unit TRaster;
{$mode tp}{$H-}{$R+}{$Q+}
interface
type TPlotProc=procedure(X,Y,C:Integer);
procedure RasterLine(X1,Y1,X2,Y2,C:Integer; Plot:TPlotProc);
procedure RasterSquare(X1,Y1,X2,Y2,C:Integer; Plot:TPlotProc);
procedure RasterCircle(X1,Y1,X2,Y2,C:Integer; Plot:TPlotProc);
implementation

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
