unit TView;
{$mode tp}{$H-}{$R+}{$Q+}
interface
const CanvasX=85; CanvasY=29; CanvasSize=128;
var Zoom,PanX,PanY:Integer; GridVisible:Boolean;
procedure InitView;
procedure SetZoom(Value:Integer);
procedure PanView(DX,DY:Integer);
function VisibleCells:Integer;
function ScreenToDoc(X,Y:Integer; var DX,DY:Integer):Boolean;
function IsCanvas(X,Y:Integer):Boolean;
implementation
uses TDoc;
function VisibleCells:Integer;
begin VisibleCells:=CanvasSize div Zoom end;

procedure ClampPan;
var Limit:Integer;
begin
  Limit:=DocWidth-VisibleCells; if Limit<0 then Limit:=0;
  if PanX<0 then PanX:=0; if PanX>Limit then PanX:=Limit;
  if PanY<0 then PanY:=0; if PanY>Limit then PanY:=Limit;
end;

procedure InitView;
begin Zoom:=4; PanX:=16; PanY:=16; GridVisible:=True end;

procedure SetZoom(Value:Integer);
var OldCells:Integer;
begin
  if not (Value in [2,4,8]) then Exit;
  OldCells:=VisibleCells;
  Zoom:=Value;
  PanX:=PanX+OldCells div 2-VisibleCells div 2;
  PanY:=PanY+OldCells div 2-VisibleCells div 2;
  ClampPan;
end;

procedure PanView(DX,DY:Integer);
begin PanX:=PanX+DX; PanY:=PanY+DY; ClampPan end;

function IsCanvas(X,Y:Integer):Boolean;
begin
  IsCanvas:=(X>=CanvasX) and (X<CanvasX+CanvasSize) and
            (Y>=CanvasY) and (Y<CanvasY+CanvasSize);
end;

function ScreenToDoc(X,Y:Integer; var DX,DY:Integer):Boolean;
begin
  ScreenToDoc:=False; DX:=-1; DY:=-1;
  if not IsCanvas(X,Y) then Exit;
  DX:=PanX+(X-CanvasX) div Zoom;
  DY:=PanY+(Y-CanvasY) div Zoom;
  if (DX>=DocWidth) or (DY>=DocHeight) then
  begin DX:=-1; DY:=-1; Exit end;
  ScreenToDoc:=True;
end;
end.
