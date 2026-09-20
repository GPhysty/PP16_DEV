unit TUI;
{$mode tp}{$H-}{$R+}{$Q+}
interface
uses TMouse;
var ForeColor,BackColor:Byte; SelectedTool,SelectedUtility:Integer;
procedure InitUI;
procedure DrawUI;
procedure ShowReferenceMenu(M:Integer);
procedure RunUI;
procedure HandleClick(X,Y:Integer; Button:Byte);
{$ifdef PP16_VIEW_TEST}function ViewChecks:Word;{$endif}
{$ifdef PP16_DRAW_TEST}function DrawChecks:Word;{$endif}
{$ifdef PP16_UNDO_TEST}function UndoChecks:Word;{$endif}
{$ifdef PP16_RESPONSE_TEST}
function ResponseChecks:Word;
procedure PerfCase(N:Integer);
{$endif}
{$ifdef PP16_FILEUI_TEST}function FileUIChecks:Word;{$endif}
procedure PointerFeedback(X,Y:Integer);
implementation
uses Dos,TVideo,TCursor,TDoc,TView,TFont,TFiles,TFDialog;
const ToolNames:array[0..7] of String[12]=
      ('CUT','UTILITIES','BUCKET FILL','BRUSH','ERASER','CIRCLE','SQUARE','LINE');
      UtilityNames:array[0..13] of String[6]=
      ('BRIGHT','DARK','TINT','FUR','MIX','SOFT','UNZAG','HOLLOW',
       'TILE','XOR','GREY','SWEEP','SWAP','EDGE');
      UtilityHelp:array[0..13] of String[65]=(
       'BRIGHT: LIGHTEN NONBLACK COLORS - PREVIEW ONLY',
       'DARK: DARKEN COLORS - PREVIEW ONLY',
       'TINT: TINT WITH CURRENT COLOR - PREVIEW ONLY',
       'FUR: MAKE OBJECT EDGES IRREGULAR - PREVIEW ONLY',
       'MIX: RANDOMLY SWAP PIXEL POSITIONS - PREVIEW ONLY',
       'SOFT: SOFTEN ALL EDGES - PREVIEW ONLY',
       'UNZAG: SMOOTH JAGGED EDGES - PREVIEW ONLY',
       'HOLLOW: TURN SOLID AREAS INTO OUTLINES - PREVIEW ONLY',
       'TILE: REPEAT THE CLIPBOARD IMAGE - PREVIEW ONLY',
       'XOR: XOR PIXEL INDICES WITH CURRENT COLOR - PREVIEW ONLY',
       'GREY: CONVERT TO GRAYSCALE - PREVIEW ONLY',
       'SWEEP: CLEAN UP ISOLATED PIXELS - PREVIEW ONLY',
       'SWAP: REPLACE CURRENT WITH SECONDARY COLOR - PREVIEW ONLY',
       'EDGE: ADD A ONE PIXEL OUTLINE - PREVIEW ONLY');
      ToolIcons:array[0..7,0..13] of String[14]=(
       ('.FF........FF.','..F8......8F..','..F88....88F..','...F88..88F...','....F8888F....','.....F88F.....','......88......','.....2882.....','..2222..2222..','.2FF22..22FF2.','.2F..2..2..F2.','.2F..2..2..F2.','..222....222..','..............'),
       ('........8..8..','.44.....8..8..','.4C4....8888..','..4C4....88...','...4C4..88....','....4C488.....','.....488......','.....884......','....88.C4.....','...88...C4....','..88.....C44..','.888......444.','.8F8..........','..8...........'),
       ('.....000......','....0...0.....','...0.....0....','....00000.....','...0777780....','..07FFFF780...','.07FFFFF7800..','.078FFF780.C0.','..078F780.CC0.','...07880.CCC0.','....000..CCC0.','........0CCC0.','......00CCCC00','.....0CCCCCCC0'),
       ('..........66..','.........6E6..','........6E6...','.......6E6....','......6E6.....','.....6E6......','....788.......','...7F88.......','..0008........','.04440........','044CC0........','04CC00........','0CCC0.........','.000..........'),
       ('..............','......0000....','.....0DDDD0...','....0DDDDDD0..','...0DDDDDDD50.','..0DDDDDDD550.','.0DDDDDDD5550.','0F7DDDDD5550..','0FF7DDD5550...','.0FF7D5550....','..0FF7550.....','...0FF50......','....000.......','..............'),
       ('..............','.....0000.....','...00000000...','..000....000..','..00......00..','.00........00.','.00........00.','.00........00.','.00........00.','..00......00..','..000....000..','...00000000...','.....0000.....','..............'),
       ('..............','.000000000000.','.000000000000.','.00........00.','.00........00.','.00........00.','.00........00.','.00........00.','.00........00.','.00........00.','.00........00.','.000000000000.','.000000000000.','..............'),
       ('..............','...........00.','..........00..','.........00...','........00....','.......00.....','......00......','.....00.......','....00........','...00.........','..00..........','.00...........','00............','..............'));
      MenuX:array[0..5] of Integer=(4,56,108,160,220,284);
var OpenMenu:Integer;
    HoverDX,HoverDY:Integer; ExitRequested:Boolean;
    UtilityHover:Integer; UtilityDrag,UtilityMoved:Boolean;
    Gesture:Byte; StrokeColor:Byte; StrokeX,StrokeY:Integer;
    ShapeTool:Byte; ShapeX,ShapeY:Integer;
    StrokeValid,ShapeValid,PointerBlocked,PaintedDirty:Boolean;
    RepaintedCells:Word;
    PendingCommand:Byte; ConfirmDiscard,PaintedUndo:Boolean;
    CachedTool,CachedUtility,CachedFore,CachedBack:Integer;
    PreviewValid:Boolean; PreviewX1,PreviewY1,PreviewX2,PreviewY2:Integer;
    ViewedZoom,ViewedPanX,ViewedPanY:Integer; ViewedGrid:Boolean;
    SavedPopup:TSavedArea; PopupSaved:Boolean;
    SavedX1,SavedY1,SavedX2,SavedY2:Integer;
    CanvasFrame:array[0..127,0..64] of Byte;
    StatusValid,ShiftHeld:Boolean;
    StatusValues:array[0..3] of String[2];

procedure PaintChanges; forward;
procedure StartFileDialog(Saving:Boolean); forward;

function Num(N:Integer):String;
var S:String[6];
begin Str(N,S); Num:=S end;

procedure Box(X1,Y1,X2,Y2:Integer; C:Byte);
var Y:Integer;
begin
  HSpan(X1,X2,Y1,C); HSpan(X1,X2,Y2,C);
  for Y:=Y1+1 to Y2-1 do begin PutPixel(X1,Y,C); PutPixel(X2,Y,C) end;
end;

procedure Button(X,Y,W,H:Integer; Down:Boolean);
var A,B:Byte; I:Integer;
begin
  FillBox(X,Y,X+W-1,Y+H-1,7);
  if Down then begin A:=8; B:=15 end else begin A:=15; B:=8 end;
  HSpan(X,X+W-1,Y,A); HSpan(X,X+W-1,Y+H-1,B);
  for I:=Y+1 to Y+H-2 do begin PutPixel(X,I,A); PutPixel(X+W-1,I,B) end;
end;

procedure Line(X1,Y1,X2,Y2:Integer; C:Byte);
var DX,DY,SX,SY,E,E2:Integer;
begin
  DX:=Abs(X2-X1); DY:=-Abs(Y2-Y1);
  if X1<X2 then SX:=1 else SX:=-1;
  if Y1<Y2 then SY:=1 else SY:=-1;
  E:=DX+DY;
  repeat
    PutPixel(X1,Y1,C); if (X1=X2) and (Y1=Y2) then Break;
    E2:=2*E;
    if E2>=DY then begin E:=E+DY; X1:=X1+SX end;
    if E2<=DX then begin E:=E+DX; Y1:=Y1+SY end;
  until False;
end;

procedure ToolFrame(I:Integer);
var X,Y:Integer; A,B,C:Byte;
begin
  X:=2+(I mod 4)*19; Y:=18+(I div 4)*19;
  if I=SelectedTool then begin A:=8; B:=15; C:=14 end
  else begin A:=15; B:=8; C:=7 end;
  HSpan(X,X+17,Y,A); HSpan(X,X+17,Y+17,B);
  Line(X,Y+1,X,Y+16,A); Line(X+17,Y+1,X+17,Y+16,B);
  Box(X+1,Y+1,X+16,Y+16,C);
end;

procedure Tools;
var I,X,Y,J,K:Integer; C:Byte; P:Char;
begin
  if CachedTool<0 then for I:=0 to 7 do
  begin
    X:=2+(I mod 4)*19; Y:=18+(I div 4)*19;
    Button(X,Y,18,18,I=SelectedTool);
    FillBox(X+2,Y+2,X+15,Y+15,11);
    for J:=0 to 13 do for K:=0 to 13 do
    begin
      P:=ToolIcons[I,J][K+1];
      if P<>'.' then
      begin
        if P<='9' then C:=Ord(P)-Ord('0') else C:=Ord(P)-Ord('A')+10;
        PutPixel(X+2+K,Y+2+J,C);
      end;
    end;
    if I=SelectedTool then Box(X+1,Y+1,X+16,Y+16,14);
  end;
  if CachedTool>=0 then
  begin
    if (CachedTool=SelectedTool) and (CachedUtility=SelectedUtility) then Exit;
    ToolFrame(CachedTool); ToolFrame(SelectedTool);
  end;
  FillBox(0,62,78,69,1);
  if SelectedTool=1 then
  begin Text8(7,62,UtilityNames[SelectedUtility],15); SmallText(62,64,':1',15) end
  else SmallText(7,64,ToolNames[SelectedTool],15);
  FillBox(0,71,78,77,0); SmallText(8,72,'SIZE:1',7);
  CachedTool:=SelectedTool; CachedUtility:=SelectedUtility;
end;

procedure Colors;
var I,X,Y:Integer;
begin
  if (CachedFore=ForeColor) and (CachedBack=BackColor) then Exit;
  if CachedFore<0 then begin
  FillBox(1,80,78,115,0);
  SmallText(2,86,'>',15); Box(12,80,48,94,15); FillBox(14,82,46,92,ForeColor);
  SmallText(52,85,':'+Num(ForeColor),15);
  Box(12,99,48,113,15); FillBox(14,101,46,111,BackColor);
  SmallText(52,104,':'+Num(BackColor),15);
  SmallText(7,118,'PALETTE',7);
  end else begin
    if CachedFore<>ForeColor then begin
      FillBox(14,82,46,92,ForeColor); FillBox(52,85,77,89,0);
      SmallText(52,85,':'+Num(ForeColor),15);
    end;
    if CachedBack<>BackColor then begin
      FillBox(14,101,46,111,BackColor); FillBox(52,104,77,108,0);
      SmallText(52,104,':'+Num(BackColor),15);
    end;
  end;
  for I:=0 to 15 do
  if (CachedFore<0) or (I=CachedFore) or (I=CachedBack) or
     (I=ForeColor) or (I=BackColor) then
  begin
    X:=2+(I mod 4)*19; Y:=126+(I div 4)*15;
    FillBox(X,Y,X+17,Y+13,I); Box(X,Y,X+17,Y+13,8);
    if I=ForeColor then Box(X+1,Y+1,X+16,Y+12,15);
    if I=BackColor then PutPixel(X+3,Y+10,15);
  end;
  CachedFore:=ForeColor; CachedBack:=BackColor;
end;

procedure DrawCanvas;
var X,Y,C,J,R,A,H:Integer; Col,PairColor,Edge:Byte;
    Row,GridRow:array[0..64] of Byte;
begin
  {Build complete packed rows before touching video RAM. X=85 is odd, so
   each 65-byte row includes the two unchanged border nibbles at 84/213.}
  FillChar(GridRow,SizeOf(GridRow),$88); GridRow[0]:=$78; GridRow[64]:=$87;
  C:=VisibleCells; if C>64 then C:=64;
  Y:=0;
  while Y<128 do
  begin
    Move(GridRow,Row,SizeOf(Row));
    if PanY+Y div Zoom<64 then
      for X:=0 to C-1 do
      begin
        Col:=DocPixel(PanX+X,PanY+Y div Zoom);
        if Zoom=1 then begin
          A:=(X+1) div 2;
          if Odd(X+1) then Row[A]:=(Row[A] and $F0) or Col
          else Row[A]:=(Row[A] and 15) or (Col shl 4);
        end else begin
          A:=(X*Zoom+1) div 2; H:=Zoom div 2;
          PairColor:=Col or (Col shl 4);
          Row[A]:=(Row[A] and $F0) or Col;
          for J:=1 to H-1 do Row[A+J]:=PairColor;
          if GridVisible and (Zoom>=4) then Edge:=8 else Edge:=Col;
          Row[A+H]:=(Row[A+H] and 15) or (Edge shl 4);
        end;
      end;
    for R:=0 to Zoom-1 do
      if GridVisible and (Zoom>=4) and (R=Zoom-1) then
        Move(GridRow,CanvasFrame[Y+R],SizeOf(Row))
      else Move(Row,CanvasFrame[Y+R],SizeOf(Row));
    Inc(Y,Zoom);
  end;
  HideCursor;
  FillBox(84,18,213,25,0);
  SmallText(86,20,'GRID:'+Num(C)+'X'+Num(C),15);
  if DocCanUndo then SmallText(194,20,'UNDO',15) else SmallText(194,20,'UNDO',8);
  HSpan(84,213,28,7); HSpan(84,213,157,7);
  for Y:=0 to 127 do WriteVideoBytes(42,CanvasY+Y,65,CanvasFrame[Y]);
end;

procedure Preview;
var X,Y,X1,Y1,X2,Y2:Integer;

  procedure RestorePixel(X,Y:Integer);
  var C:Byte;
  begin
    C:=0;
    if (X>=237) and (X<=300) and (Y>=46) and (Y<=109) then
      C:=DocPixel(X-237,Y-46);
    PutPixel(X,Y,C);
  end;

begin
  if PreviewValid then begin
    for X:=PreviewX1 to PreviewX2 do begin RestorePixel(X,PreviewY1); RestorePixel(X,PreviewY2) end;
    for Y:=PreviewY1+1 to PreviewY2-1 do begin RestorePixel(PreviewX1,Y); RestorePixel(PreviewX2,Y) end;
  end else begin
  SmallText(219,20,'IMAGE:64X64',15); Box(218,28,318,129,7);
  FillBox(219,29,317,128,0);
  for Y:=0 to 63 do for X:=0 to 63 do PutPixel(237+X,46+Y,DocPixel(X,Y));
  end;
  {Viewport outline belongs to UI, never document pixels.}
  X1:=237+PanX; Y1:=46+PanY;
  X2:=X1+VisibleCells-1; Y2:=Y1+VisibleCells-1;
  if X2>300 then X2:=300; if Y2>109 then Y2:=109;
  Box(X1-1,Y1-1,X2+1,Y2+1,8);
  PreviewX1:=X1-1; PreviewY1:=Y1-1; PreviewX2:=X2+1; PreviewY2:=Y2+1;
  PreviewValid:=True;
end;

procedure Navigation;
var I,Z:Integer; S:String[2];
begin
  Z:=1;
  for I:=0 to 3 do begin Button(85+I*17,161,16,10,Zoom=Z);
    SmallText(89+I*17,164,Num(Z)+'X',4); Z:=Z*2 end;
  for I:=0 to 3 do begin
    Button(156+I*14,161,13,10,False);
    case I of 0:S:='<'; 1:S:='>'; 2:S:='^'; 3:S:='V' end;
    SmallText(161+I*14,164,S,4);
  end;
  FillBox(218,135,318,150,1); Box(218,135,318,150,9);
  SmallText(223,141,'NO',15); Button(240,139,10,9,False); SmallText(243,141,'-',8);
  SmallText(260,141,'1',15); Button(303,139,10,9,False); SmallText(306,141,'+',8);
  FillBox(218,154,318,187,1); Box(218,154,318,187,9);
  SmallText(225,158,'TOTAL:1',15); SmallText(225,166,'BYTES:2048',15);
  SmallText(225,174,'ZOOM:'+Num(Zoom)+'X',15); if DocDirty then SmallText(225,182,'UNSAVED',14) else SmallText(225,182,'CLEAN',14);
end;

procedure Status(X,Y:Integer);
const SX:array[0..3] of Integer=(116,136,120,140);
      SY:array[0..3] of Integer=(176,176,182,182);
var DX,DY,GX,GY,I,J:Integer; V:array[0..3] of String[2]; Changed:Boolean;

  function Coord(N:Integer):String;
  var S:String[3];
  begin
    if N<0 then Coord:='--'
    else begin S:=Num(N)+' '; Coord:=Copy(S,1,2) end;
  end;

begin
  GX:=-1; GY:=-1;
  if ScreenToDoc(X,Y,DX,DY) then
  begin GX:=(X-CanvasX) div Zoom; GY:=(Y-CanvasY) div Zoom end;
  V[0]:=Coord(GX); V[1]:=Coord(GY); V[2]:=Coord(DX); V[3]:=Coord(DY);
  Changed:=not StatusValid;
  for I:=0 to 3 do if V[I]<>StatusValues[I] then Changed:=True;
  HoverDX:=DX; HoverDY:=DY;
  if not Changed then Exit;
  if CursorOverlaps(84,174,213,187) then HideCursor;
  if not StatusValid then begin
    FillBox(84,174,213,187,1);
    SmallText(88,176,'GRID X:',15); SmallText(124,176,' Y:',15);
    SmallText(88,182,'IMAGE X:',15); SmallText(128,182,' Y:',15);
    for I:=0 to 3 do StatusValues[I]:='??';
  end;
  for I:=0 to 3 do for J:=1 to 2 do
    if V[I][J]<>StatusValues[I][J] then SmallCharOpaque(SX[I]+(J-1)*4,SY[I],V[I][J],15,1);
  for I:=0 to 3 do StatusValues[I]:=V[I];
  StatusValid:=True;
end;

function UtilityAt(X,Y:Integer):Integer;
begin
  UtilityAt:=-1;
  if (X>=0) and (X<68) and (Y>=70) and (Y<182) then
    UtilityAt:=(Y-70) div 8;
end;

procedure UtilityRow(I:Integer);
var BG,FG:Byte;
begin
  if (I<0) or (I>13) then Exit;
  if I=UtilityHover then begin BG:=15; FG:=1 end else begin BG:=1; FG:=15 end;
  FillBox(0,70+I*8,67,77+I*8,BG); Text8(7,70+I*8,UtilityNames[I],FG);
end;

procedure UtilityStatus;
begin
  FillBox(0,192,319,199,1);
  if UtilityHover>=0 then SmallText(3,194,UtilityHelp[UtilityHover],14)
  else SmallText(3,194,'SELECT SPECIAL EFFECT - EFFECTS NOT ACTIVE',14);
end;

procedure UtilityPopup;
var I:Integer;
begin
  FillBox(0,62,57,69,15); Text8(7,62,UtilityNames[SelectedUtility],1);
  for I:=0 to 13 do UtilityRow(I);
  UtilityStatus;
end;

const PopupX:array[0..5] of Integer=(1,32,64,96,136,184);
      PopupW:array[0..5] of Integer=(168,152,208,200,176,135);
      MenuRows:array[0..5] of Integer=(16,9,12,12,9,8);
      Labels:array[0..5,0..15] of String[20]=(
       ('New','Open...','Append...','Save','Save As...','Save as DATA...',
        '','Load Clipboard...','Save Clipboard...','','Load Palette...',
        'Save Palette...','','Print Index...','','Exit'),
       ('Undo','','Cut','Copy','Paste','','Transparency On','Paste Behind',
        'Show Clipboard','','','','','','',''),
       ('Cross-hair On','Highlight On','Grid On','Image as Tile','Palette Tools',
        '','Test Animation...','Screen Designer...','','Brighter Shade','Darker Shade','',
        '','','',''),
       ('Clear','Clear to Colour','','Scroll Up','Scroll Down','Scroll Left',
        'Scroll Right','Rotate 90','Flip Horizontal','Flip Vertical','','Effect:SOFT',
        '','','',''),
       ('Add...','Delete...','Resize...','Duplicate...','Convert to Mask...',
        'Crop','Add as Gradient','','Show All','','','','','','',''),
       ('Contents','Index','','Keyboard','Using Help','','About...','',
        '','','','','','','',''));

function MenuRowY(M,I:Integer):Integer;
var J,Y:Integer;
begin
  Y:=15;
  for J:=0 to I-1 do if Labels[M,J]='' then Inc(Y,5) else Inc(Y,9);
  MenuRowY:=Y;
end;

function Enabled(M,I:Integer):Boolean;
begin
  Enabled:=((M=0) and (I in [0,1,3,4,15])) or ((M=1) and (I=0) and DocCanUndo) or
           ((M=3) and (I in [0,1])) or ((M=2) and (I=2)) or
           ((M=5) and (I in [0,3,4,6]));
end;

function Shortcut(M,I:Integer):String;
begin
  Shortcut:='';
  case M of
    1:case I of 0:Shortcut:='Bksp'; 2:Shortcut:='Alt+O'; 3:Shortcut:='Alt+A'; 4:Shortcut:='Alt+Z' end;
    2:case I of 0:Shortcut:='F2'; 1:Shortcut:='F3'; 2:Shortcut:='F4'; 3:Shortcut:='F5';
      4:Shortcut:='F6'; 6:Shortcut:='F7'; 7:Shortcut:='F8'; 9:Shortcut:='PgUp'; 10:Shortcut:='PgDn' end;
    3:case I of 0:Shortcut:='Alt+C'; 3:Shortcut:='Alt+U'; 4:Shortcut:='Alt+D';
      5:Shortcut:='Alt+L'; 6:Shortcut:='Alt+R'; 11:Shortcut:='Alt+E' end;
    4:if I=8 then Shortcut:='F10';
    5:if I=0 then Shortcut:='F1';
  end;
end;

procedure Popup;
var X,W,H,I,Y:Integer; C:Byte; S:String[6];
begin
  if OpenMenu<0 then Exit;
  if OpenMenu=9 then begin DrawFileDialog; Exit end;
  if OpenMenu=8 then
  begin
    FillBox(36,49,283,143,1); Box(36,49,283,143,9); Box(39,52,280,140,7);
    if PendingCommand=1 then Text8(64,59,'New blank image?',15)
    else if PendingCommand=3 then Text8(64,59,'Open another image?',15)
    else Text8(88,59,'Exit PP16?',15);
    SmallText(52,78,'THIS IMAGE HAS UNSAVED CHANGES.',14);
    SmallText(52,88,'CANCEL TO SAVE FIRST, OR DISCARD.',15);
    Button(60,108,84,15,ConfirmDiscard);
    Button(164,108,84,15,not ConfirmDiscard);
    SmallText(86,113,'DISCARD',4); SmallText(190,113,'CANCEL',4);
    if ConfirmDiscard then Box(62,110,141,120,4) else Box(166,110,245,120,4);
    SmallText(52,131,'TAB: SELECT  ENTER: OK  ESC: CANCEL',15);
    Exit;
  end;
  if OpenMenu=7 then begin UtilityPopup; Exit end;
  if OpenMenu=6 then
  begin
    FillBox(52,44,268,133,1); Box(52,44,268,133,9); Box(55,47,265,130,7);
    Text8(88,52,'PP16 - Help',15);
    SmallText(64,70,'1/2/4/8: ZOOM  SHIFT+ARROWS: FAST PAN',15);
    SmallText(64,80,'BRUSH, LINE, SQUARE, CIRCLE: DRAG',15);
    SmallText(64,90,'RIGHT CANVAS DRAG: PICK COLOR',15);
    SmallText(64,100,'BKSP: UNDO  ESC IN STROKE: CANCEL',14);
    SmallText(64,108,'CTRL+S: SAVE  CTRL+O: OPEN',14);
    SmallText(64,116,'ESC OR CLICK: CLOSE',15); Exit;
  end;
  X:=PopupX[OpenMenu]; W:=PopupW[OpenMenu]; H:=MenuRowY(OpenMenu,MenuRows[OpenMenu])+4;
  FillBox(X,9,X+W-1,H,1); Box(X,9,X+W-1,H,9); Box(X+3,12,X+W-4,H-3,7);
  for I:=0 to MenuRows[OpenMenu]-1 do
  begin
    Y:=MenuRowY(OpenMenu,I);
    if Labels[OpenMenu,I]='' then HSpan(X+4,X+W-5,Y+2,8)
    else begin
      if Enabled(OpenMenu,I) then C:=15 else C:=8;
      if (OpenMenu=3) and (I=11) then
        Text8(X+12,Y,'Effect:'+UtilityNames[SelectedUtility],C)
      else Text8(X+12,Y,Labels[OpenMenu,I],C);
      S:=Shortcut(OpenMenu,I);
      if S<>'' then SmallText(X+W-7-Length(S)*4,Y+1,S,C);
      if (OpenMenu=2) and (I=2) and GridVisible then
        begin Line(X+5,Y+4,X+7,Y+6,15); Line(X+7,Y+6,X+10,Y+1,15) end;
    end;
  end;
end;

procedure CapturePopup;
begin
  PopupSaved:=False;
  if OpenMenu<0 then Exit;
  if OpenMenu<6 then begin
    SavedX1:=PopupX[OpenMenu]; SavedX2:=SavedX1+PopupW[OpenMenu]-1;
    SavedY1:=9; SavedY2:=MenuRowY(OpenMenu,MenuRows[OpenMenu])+4;
  end else case OpenMenu of
    6:begin SavedX1:=52; SavedY1:=44; SavedX2:=268; SavedY2:=133 end;
    7:begin SavedX1:=0; SavedY1:=62; SavedX2:=78; SavedY2:=181 end;
    8:begin SavedX1:=36; SavedY1:=49; SavedX2:=283; SavedY2:=143 end;
    9:begin SavedX1:=50; SavedY1:=36; SavedX2:=269; SavedY2:=145 end;
  end;
  PopupSaved:=SaveArea(SavedX1,SavedY1,SavedX2,SavedY2,SavedPopup);
end;

procedure PointerFeedback(X,Y:Integer);
var DX,DY:Integer;
begin
  ShowCursor(X,Y);
  ScreenToDoc(X,Y,DX,DY);
  if (OpenMenu<0) and ((DX<>HoverDX) or (DY<>HoverDY)) then Status(X,Y);
  ShowCursor(X,Y);
end;

procedure InitUI;
begin InitDemoDoc; CurrentFile:=''; InitView; ForeColor:=15; BackColor:=0;
  StatusValid:=False; ShiftHeld:=False;
  CachedTool:=-1; CachedUtility:=-1; CachedFore:=-1; CachedBack:=-1;
  PreviewValid:=False; PopupSaved:=False; ViewedZoom:=-1;
  Gesture:=0; PointerBlocked:=False; StrokeValid:=False; ShapeValid:=False;
  PaintedDirty:=False;
  RepaintedCells:=0;
  PendingCommand:=0; ConfirmDiscard:=False; PaintedUndo:=False;
  SelectedUtility:=5; UtilityHover:=-1; UtilityDrag:=False; UtilityMoved:=False;
  ExitRequested:=False; SelectedTool:=3; OpenMenu:=-1; HoverDX:=-1; HoverDY:=-1 end;

procedure Title;
var S:String[32]; C:Byte;
begin
  S:=CurrentFile; if S='' then S:='UNTITLED';
  S:='PP16 ['+S+']'; C:=10;
  if DocDirty then begin S:=S+'*'; C:=14 end;
  FillBox(100,10,213,14,0); SmallText(100,10,S,C);
end;

procedure DrawUI;
var Y,A,B:Integer;
begin
  StatusValid:=False;
  CachedTool:=-1; CachedUtility:=-1; CachedFore:=-1; CachedBack:=-1;
  PreviewValid:=False; PopupSaved:=False;
  FillBox(0,0,319,199,0); FillBox(0,0,319,7,1);
  Text8(4,0,'File',15); Text8(56,0,'Edit',15); Text8(108,0,'View',15);
  Text8(160,0,'Action',15); Text8(220,0,'Image',15); Text8(284,0,'Help',15);
  Title;
  Tools; Colors; DrawCanvas; Preview; Navigation; Status(-1,-1);
  FillBox(0,192,319,199,1);
  SmallText(3,194,'CTRL+S SAVE  CTRL+O OPEN  BKSP UNDO  ESC EXIT',14);
  CapturePopup; Popup;
  for Y:=0 to 63 do TakeDirtyRow(Y,A,B);
  PaintedDirty:=DocDirty; PaintedUndo:=DocCanUndo;
  ViewedZoom:=Zoom; ViewedPanX:=PanX; ViewedPanY:=PanY; ViewedGrid:=GridVisible;
end;

procedure RedrawView;
begin
  if (ViewedZoom=Zoom) and (ViewedPanX=PanX) and (ViewedPanY=PanY) and
     (ViewedGrid=GridVisible) then Exit;
  DrawCanvas; Preview; Navigation; Status(-1,-1);
  ViewedZoom:=Zoom; ViewedPanX:=PanX; ViewedPanY:=PanY; ViewedGrid:=GridVisible;
end;

procedure PanCommand(Direction:Integer; Fast:Boolean);
var Step:Integer;
begin
  Step:=1; if Fast then Step:=VisibleCells div 2;
  case Direction of
    0:PanView(-Step,0); 1:PanView(Step,0);
    2:PanView(0,-Step); 3:PanView(0,Step);
  end;
  RedrawView;
end;

procedure ClosePopup;
var Old:Integer;
begin
  Old:=OpenMenu; OpenMenu:=-1;
  if Old<0 then Exit;
  if PopupSaved then
  begin
    RestoreArea(SavedX1,SavedY1,SavedX2,SavedY2,SavedPopup);
    if Old=7 then begin
      FillBox(0,192,319,199,1);
      SmallText(3,194,'CTRL+S SAVE  CTRL+O OPEN  BKSP UNDO  ESC EXIT',14);
      Tools;
    end;
  end else DrawUI;
  PopupSaved:=False;
end;

procedure SetPopup(M:Integer);
begin
  ClosePopup; PaintChanges;
  OpenMenu:=M; CapturePopup; Popup;
end;

procedure ShowReferenceMenu(M:Integer);
begin
  if (M<0) or (M>7) then Exit;
  if M=7 then begin SelectedTool:=1; UtilityHover:=-1 end;
  OpenMenu:=M; DrawUI;
end;

procedure CompleteCommand;
var C:Byte;
begin
  C:=PendingCommand;
  ClosePopup;
  if PendingCommand=1 then
  begin InitBlankDoc(0); CurrentFile:=''; InitView end
  else if PendingCommand=2 then ExitRequested:=True;
  PendingCommand:=0; OpenMenu:=-1; DrawUI;
  if C=3 then StartFileDialog(False);
end;

procedure RequestCommand(C:Byte);
begin
  PendingCommand:=C; ConfirmDiscard:=False;
  if DocDirty then SetPopup(8) else CompleteCommand;
end;

procedure CloseConfirmation(Discard:Boolean);
begin
  if Discard then CompleteCommand
  else begin PendingCommand:=0; ClosePopup end;
end;

procedure StartFileDialog(Saving:Boolean);
begin
  ClosePopup; BeginFileDialog(Saving); SetPopup(9);
end;

procedure FinishFileDialog(Result:Byte);
begin
  if Result=0 then Exit;
  ClosePopup;
  if Result=2 then begin
    if not DialogSaving then InitView;
    DrawUI;
  end;
end;

procedure SaveCurrent;
var Message:String[48];
begin
  if CurrentFile='' then StartFileDialog(True)
  else if SaveImage(CurrentFile,True) then DrawUI
  else begin
    Message:=FileError; StartFileDialog(True); FileError:=Message; DrawFileDialog;
  end;
end;

procedure HandleClick(X,Y:Integer; Button:Byte);
var I,M:Integer;
begin
  if OpenMenu=9 then begin
    if Button=1 then FinishFileDialog(FileClick(X,Y));
    Exit;
  end;
  if OpenMenu=8 then
  begin
    if (Button=1) and (Y>=108) and (Y<=122) then
    begin
      if (X>=60) and (X<144) then CloseConfirmation(True)
      else if (X>=164) and (X<248) then CloseConfirmation(False);
    end;
    Exit; {Modal clicks cannot reach a menu, palette or document.}
  end;
  if OpenMenu>=0 then
  begin
    if OpenMenu=7 then
    begin
      I:=UtilityAt(X,Y);
      if (I>=0) and (Button=1) then SelectedUtility:=I;
      UtilityDrag:=False; ClosePopup; Exit;
    end;
    if (Y<8) and (Button=1) then
    begin
      I:=0; while (I<5) and (X>=MenuX[I+1]-2) do Inc(I);
      SetPopup(I); Exit;
    end;
    if OpenMenu<6 then
    begin
      M:=PopupX[OpenMenu];
      if (X>=M) and (X<M+PopupW[OpenMenu]) and (Y>=9) and
         (Y<=MenuRowY(OpenMenu,MenuRows[OpenMenu])+4) then
      begin
        for I:=0 to MenuRows[OpenMenu]-1 do
          if (Y>=MenuRowY(OpenMenu,I)) and (Y<MenuRowY(OpenMenu,I)+8) and
             (Labels[OpenMenu,I]<>'') and Enabled(OpenMenu,I) and (Button=1) then
          begin
            M:=OpenMenu; ClosePopup;
            if M=0 then
            begin
              case I of
                0:RequestCommand(1); 1:RequestCommand(3);
                3:SaveCurrent; 4:StartFileDialog(True); 15:RequestCommand(2);
              end;
              Exit;
            end
            else if M=1 then DocUndo
            else if M=3 then
            begin if I=0 then DocClear(0) else DocClear(ForeColor) end
            else if M=2 then begin GridVisible:=not GridVisible; RedrawView end
            else if M=5 then begin SetPopup(6); Exit end;
            PaintChanges; Exit;
          end;
        Exit; {Disabled items do not masquerade as working commands.}
      end;
    end;
    ClosePopup; Exit; {Dismissal consumes the entire click.}
  end;
  if Y<8 then
  begin
    if Button<>1 then Exit;
    I:=0; while (I<5) and (X>=MenuX[I+1]-2) do Inc(I);
    SetPopup(I); Exit;
  end;
  if (Button=1) and (X>=194) and (X<=211) and (Y>=18) and (Y<=25) then
  begin DocUndo; PaintChanges; Exit end;
  if (X>=2) and (X<78) and (Y>=126) and (Y<186) then
  begin
    if ((X-2) mod 19>=18) or ((Y-126) mod 15>=14) then Exit;
    I:=((Y-126) div 15)*4+(X-2) div 19;
    if Button=1 then ForeColor:=I else if Button=2 then BackColor:=I;
    Colors; Exit;
  end;
  if (Button in [1,2]) and (X>=156) and (X<212) and (Y>=161) and (Y<171) then
  begin PanCommand((X-156) div 14,Button=1); Exit end;
  if Button<>1 then Exit;
  if (X>=12) and (X<=48) and (Y>=99) and (Y<=113) then
  begin I:=ForeColor; ForeColor:=BackColor; BackColor:=I; Colors; Exit end;
  if (SelectedTool=1) and (X>=0) and (X<79) and (Y>=62) and (Y<=69) then
  begin
    UtilityHover:=-1; UtilityDrag:=True; UtilityMoved:=False;
    SetPopup(7); Exit;
  end;
  if (X>=2) and (X<78) and (Y>=18) and (Y<56) then
  begin
    if ((X-2) mod 19>=18) or ((Y-18) mod 19>=18) then Exit;
    SelectedTool:=((Y-18) div 19)*4+(X-2) div 19; Tools; Exit;
  end;
  if (Y>=161) and (Y<171) then
  begin
    if (X>=85) and (X<153) then
    begin I:=(X-85) div 17; SetZoom(1 shl I); RedrawView end
  end;
end;

procedure UtilityMotion(X,Y:Integer; Released:Byte);
var I,Old:Integer;
begin
  if OpenMenu<>7 then Exit;
  I:=UtilityAt(X,Y);
  if UtilityDrag and not ((X>=0) and (X<79) and (Y>=62) and (Y<=69)) then
    UtilityMoved:=True;
  if I<>UtilityHover then
  begin
    Old:=UtilityHover; UtilityHover:=I; UtilityRow(Old); UtilityRow(I); UtilityStatus;
  end;
  if UtilityDrag and ((Released and 1)<>0) then
  begin
    UtilityDrag:=False;
    if UtilityMoved then
    begin
      if I>=0 then SelectedUtility:=I;
      ClosePopup;
    end;
  end;
end;

procedure PaintChanges;
var X,Y,A,B,SX,SY,J,PX1,PY1,PX2,PY2:Integer; C:Byte;
begin
  if OpenMenu>=0 then Exit;
  PX1:=PanX-1; PY1:=PanY-1; PX2:=PanX+VisibleCells; PY2:=PanY+VisibleCells;
  if PX2>64 then PX2:=64; if PY2>64 then PY2:=64;
  for Y:=0 to 63 do if TakeDirtyRow(Y,A,B) then
    for X:=A to B do
    begin
      C:=DocPixel(X,Y);
      if (X>=PanX) and (X<PanX+VisibleCells) and
         (Y>=PanY) and (Y<PanY+VisibleCells) then
      begin
        SX:=CanvasX+(X-PanX)*Zoom; SY:=CanvasY+(Y-PanY)*Zoom;
        FillBox(SX,SY,SX+Zoom-1,SY+Zoom-1,C);
        if GridVisible and (Zoom>=4) then
        begin
          HSpan(SX,SX+Zoom-1,SY+Zoom-1,8);
          for J:=SY to SY+Zoom-2 do PutPixel(SX+Zoom-1,J,8);
        end;
        {A diagnostic counter, not a lifetime total. Saturate rather than wrap.}
        if RepaintedCells<65535 then Inc(RepaintedCells);
      end;
      if (((X=PX1) or (X=PX2)) and (Y>=PY1) and (Y<=PY2)) or
         (((Y=PY1) or (Y=PY2)) and (X>=PX1) and (X<=PX2)) then C:=8;
      PutPixel(237+X,46+Y,C);
    end;
  if DocDirty<>PaintedDirty then
  begin
    Title;
    FillBox(225,182,315,186,1);
    if DocDirty then SmallText(225,182,'UNSAVED',14) else SmallText(225,182,'CLEAN',14);
    PaintedDirty:=DocDirty;
  end;
  if DocCanUndo<>PaintedUndo then
  begin
    FillBox(194,20,211,24,0);
    if DocCanUndo then SmallText(194,20,'UNDO',15) else SmallText(194,20,'UNDO',8);
    PaintedUndo:=DocCanUndo;
  end;
end;

procedure PreviewShapePixel(X,Y:Integer; C:Byte);
var SX,SY,J:Integer;
begin
  {The live outline is a canvas-only overlay. It never enters the document or
   the 1:1 image preview, so release remains the one commit point.}
  if (X<PanX) or (X>=PanX+VisibleCells) or
     (Y<PanY) or (Y>=PanY+VisibleCells) then Exit;
  SX:=CanvasX+(X-PanX)*Zoom; SY:=CanvasY+(Y-PanY)*Zoom;
  FillBox(SX,SY,SX+Zoom-1,SY+Zoom-1,C);
  if GridVisible and (Zoom>=4) then
  begin
    HSpan(SX,SX+Zoom-1,SY+Zoom-1,8);
    for J:=SY to SY+Zoom-2 do PutPixel(SX+Zoom-1,J,8);
  end;
end;

procedure PreviewShapeLine(X1,Y1,X2,Y2:Integer; C:Byte);
var DX,DY,SX,SY,E,E2:Integer;
begin
  DX:=Abs(X2-X1); DY:=-Abs(Y2-Y1);
  if X1<X2 then SX:=1 else SX:=-1;
  if Y1<Y2 then SY:=1 else SY:=-1;
  E:=DX+DY;
  repeat
    PreviewShapePixel(X1,Y1,C);
    if (X1=X2) and (Y1=Y2) then Break;
    E2:=2*E;
    if E2>=DY then begin E:=E+DY; X1:=X1+SX end;
    if E2<=DX then begin E:=E+DX; Y1:=Y1+SY end;
  until False;
end;

procedure PreviewShapeSquare(X1,Y1,X2,Y2:Integer; C:Byte);
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
  PreviewShapeLine(X1,Y1,X2,Y1,C); PreviewShapeLine(X2,Y1,X2,Y2,C);
  PreviewShapeLine(X2,Y2,X1,Y2,C); PreviewShapeLine(X1,Y2,X1,Y1,C);
end;

procedure PreviewShapeCircle(X1,Y1,X2,Y2:Integer; C:Byte);
var R,X,Y,D:Integer;
begin
  R:=Abs(X2-X1); if Abs(Y2-Y1)>R then R:=Abs(Y2-Y1);
  X:=R; Y:=0; D:=1-R;
  while X>=Y do
  begin
    PreviewShapePixel(X1+X,Y1+Y,C); PreviewShapePixel(X1+Y,Y1+X,C);
    PreviewShapePixel(X1-Y,Y1+X,C); PreviewShapePixel(X1-X,Y1+Y,C);
    PreviewShapePixel(X1-X,Y1-Y,C); PreviewShapePixel(X1-Y,Y1-X,C);
    PreviewShapePixel(X1+Y,Y1-X,C); PreviewShapePixel(X1+X,Y1-Y,C);
    Inc(Y);
    if D<0 then D:=D+2*Y+1
    else begin Dec(X); D:=D+2*(Y-X)+1 end;
  end;
end;

procedure ShowShapePreview;
begin
  if not ShapeValid then Exit;
  {Redrawing just the canvas removes the prior outline before drawing the new
   one, including any grid cells it covered.}
  DrawCanvas;
  case ShapeTool of
    5:PreviewShapeCircle(StrokeX,StrokeY,ShapeX,ShapeY,StrokeColor);
    6:PreviewShapeSquare(StrokeX,StrokeY,ShapeX,ShapeY,StrokeColor);
    7:PreviewShapeLine(StrokeX,StrokeY,ShapeX,ShapeY,StrokeColor);
  end;
  {DrawCanvas reflects the active action's temporarily disabled Undo control.
   Force PaintChanges to restore that control after the release commits.}
  PaintedUndo:=DocCanUndo;
end;

procedure EndGesture(Buttons:Byte);
begin
  if Gesture=4 then
    if ShapeValid then
      case ShapeTool of
        5:DocCircle(StrokeX,StrokeY,ShapeX,ShapeY,StrokeColor);
        6:DocSquare(StrokeX,StrokeY,ShapeX,ShapeY,StrokeColor);
        7:DocLine(StrokeX,StrokeY,ShapeX,ShapeY,StrokeColor);
      end;
  if Gesture in [1,4] then DocCommitAction;
  Gesture:=0; StrokeValid:=False; ShapeValid:=False; PointerBlocked:=Buttons<>0;
end;

procedure CancelGesture(Buttons:Byte);
var WasShape:Boolean;
begin
  WasShape:=Gesture=4;
  if Gesture in [1,4] then DocCancelAction;
  Gesture:=0; StrokeValid:=False; ShapeValid:=False; PointerBlocked:=Buttons<>0;
  if WasShape then begin DrawCanvas; PaintedUndo:=DocCanUndo end;
end;

procedure ApplyGesture(X,Y:Integer);
var DX,DY:Integer; C:Byte;
begin
  if Gesture=3 then begin
    if X<237 then X:=237; if X>300 then X:=300;
    if Y<46 then Y:=46; if Y>109 then Y:=109;
    PanView(X-237-VisibleCells div 2-PanX,Y-46-VisibleCells div 2-PanY);
    RedrawView; Exit;
  end;
  if not ScreenToDoc(X,Y,DX,DY) then begin StrokeValid:=False; Exit end;
  if Gesture=2 then
  begin
    C:=DocPixel(DX,DY);
    if ForeColor<>C then begin ForeColor:=C; Colors end;
    Exit;
  end;
  if Gesture=4 then
  begin
    ShapeValid:=True; ShapeX:=DX; ShapeY:=DY;
    ShowShapePreview;
    Exit;
  end;
  if StrokeValid then DocLine(StrokeX,StrokeY,DX,DY,StrokeColor)
  else DocSetPixel(DX,DY,StrokeColor);
  StrokeX:=DX; StrokeY:=DY; StrokeValid:=True;
end;

procedure PointerInput(const S:TMouseState);
var DX,DY:Integer; Owner:Byte;
begin
  if Gesture<>0 then
  begin
    if Gesture=2 then Owner:=2 else Owner:=1;
    ApplyGesture(S.X,S.Y); {Includes the final release position.}
    if (S.Buttons and Owner)=0 then EndGesture(S.Buttons);
    Exit;
  end;
  if PointerBlocked then
  begin if S.Buttons=0 then PointerBlocked:=False; Exit end;
  if S.Pressed=0 then Exit;
  if S.Buttons=3 then begin PointerBlocked:=True; Exit end;
  if (OpenMenu<0) and ((S.Pressed and 1)<>0) and
     (S.X>=237) and (S.X<=300) and (S.Y>=46) and (S.Y<=109) then
  begin Gesture:=3; ApplyGesture(S.X,S.Y); Exit end;
  if (OpenMenu<0) and ScreenToDoc(S.X,S.Y,DX,DY) then
  begin
    if (S.Pressed and 2)<>0 then Gesture:=2
    else if SelectedTool=2 then
    begin
      DocFloodFill(DX,DY,ForeColor);
    end
    else if SelectedTool in [3,4] then
    begin
      Gesture:=1; DocBeginAction;
      if SelectedTool=4 then StrokeColor:=BackColor else StrokeColor:=ForeColor;
    end
    else if SelectedTool in [5,6,7] then
    begin
      Gesture:=4; ShapeTool:=SelectedTool; StrokeColor:=ForeColor;
      StrokeX:=DX; StrokeY:=DY; ShapeX:=DX; ShapeY:=DY; ShapeValid:=True;
      DocBeginAction;
    end
    else
    begin
      FillBox(0,192,319,199,1);
      SmallText(3,194,'CUT AND UTILITIES ARE PREVIEWS',14);
    end;
    StrokeValid:=False;
    if Gesture<>0 then ApplyGesture(S.X,S.Y)
    else PointerBlocked:=True;
  end
  else
  begin
    if (S.Pressed and 1)<>0 then HandleClick(S.X,S.Y,1) else HandleClick(S.X,S.Y,2);
    PointerBlocked:=S.Buttons<>0;
  end;
end;

procedure KeyInput(Key,Scan,Buttons:Byte);
var Temp:Byte;
begin
  if Gesture<>0 then
  begin
    if Key=27 then CancelGesture(Buttons);
    Exit;
  end;
  if OpenMenu=9 then begin
    if Key=27 then begin FinishFileDialog(FileKey(Key,Scan)); PointerBlocked:=Buttons<>0 end
    else if not PointerBlocked and (Buttons=0) then FinishFileDialog(FileKey(Key,Scan));
    Exit;
  end;
  if OpenMenu=8 then
  begin
    if Key=27 then
    begin CloseConfirmation(False); PointerBlocked:=Buttons<>0 end
    else if not PointerBlocked and (Buttons=0) then
      if (Key=9) or (Scan=75) or (Scan=77) then
      begin ConfirmDiscard:=not ConfirmDiscard; Popup end
      else if Key=13 then CloseConfirmation(ConfirmDiscard);
    Exit;
  end;
  if Key=27 then
  begin
    if OpenMenu>=0 then ClosePopup else RequestCommand(2);
    PointerBlocked:=Buttons<>0; Exit;
  end;
  if PointerBlocked or (Buttons<>0) then Exit;
  if Scan=59 then SetPopup(6)
  else if OpenMenu<0 then
  begin
    case Key of
      15:begin RequestCommand(3); Exit end; {Ctrl+O}
      19:begin
        if ShiftHeld then StartFileDialog(True) else SaveCurrent;
        Exit;
      end; {Ctrl+S / Ctrl+Shift+S}
      8:DocUndo;
      49,50,52,56:begin SetZoom(Key-48); RedrawView end;
      9:begin Temp:=ForeColor; ForeColor:=BackColor; BackColor:=Temp; Colors end;
    end;
    case Scan of
      46:if Key=0 then DocClear(0); {Alt+C}
      62:begin GridVisible:=not GridVisible; DrawCanvas end;
      72:PanCommand(2,ShiftHeld);
      80:PanCommand(3,ShiftHeld);
      75:PanCommand(0,ShiftHeld);
      77:PanCommand(1,ShiftHeld);
    end;
  end;
end;

procedure RunUI;
var S,Old:TMouseState; R:Registers; Key,Scan:Byte; DX,DY:Integer;
    Quit,Changed,MotionOnly,DeferHide:Boolean;
begin
  FillChar(S,SizeOf(S),0); S.X:=160; S.Y:=100;
  if MouseReady then PollMouse(S);
  Old:=S; Quit:=False; PointerBlocked:=S.Buttons<>0;
  if MouseReady then ShowCursor(S.X,S.Y)
  else begin FillBox(0,192,319,199,1); SmallText(3,194,'NO MOUSE - 1/2/4/8 ZOOM - ARROWS PAN - ESC EXIT',14) end;
  repeat
    Key:=0; Scan:=0; FillChar(R,SizeOf(R),0); R.AH:=1; Intr($16,R);
    if (R.Flags and $40)=0 then begin R.AH:=0; Intr($16,R); Key:=R.AL; Scan:=R.AH end;
    if MouseReady then PollMouse(S);
    Changed:=(S.X<>Old.X) or (S.Y<>Old.Y) or (S.Buttons<>Old.Buttons) or (Scan<>0);
    if Changed then
    begin
      ShiftHeld:=(Mem[$40:$17] and 3)<>0;
      MotionOnly:=(Scan=0) and (S.Buttons=Old.Buttons) and (Gesture=0) and (OpenMenu<>7);
      if MotionOnly and MouseReady then PointerFeedback(S.X,S.Y)
      else begin
        {Keep the pointer visible during offscreen canvas construction.}
        DeferHide:=(OpenMenu<0) and
          (((Gesture=0) and (S.Buttons=0) and
            ((Key in [49,50,52,56]) or (Scan in [62,72,75,77,80]))) or
           (Gesture=3) or ((Scan=0) and (Gesture=0) and
            (((S.X>=85) and (S.X<212) and (S.Y>=161) and (S.Y<171)) or
             ((S.X>=237) and (S.X<=300) and (S.Y>=46) and (S.Y<=109)))));
        if not DeferHide then HideCursor;
        KeyInput(Key,Scan,S.Buttons);
        if not ExitRequested then PointerInput(S);
        PaintChanges;
        UtilityMotion(S.X,S.Y,S.Released);
        if ExitRequested then Quit:=True;
        if MouseReady and not Quit then PointerFeedback(S.X,S.Y)
        else begin
          ScreenToDoc(S.X,S.Y,DX,DY);
          if (OpenMenu<0) and ((DX<>HoverDX) or (DY<>HoverDY)) then Status(S.X,S.Y);
        end;
      end;
      Old:=S;
    end;
    FillChar(R,SizeOf(R),0); Intr($28,R);
  until Quit;
  HideCursor;
end;

{$ifdef PP16_VIEW_TEST}
function ViewChecks:Word;
var Before:DWord; F:Word; Z,I,G,X,Y,DX,DY:Integer; OK:Boolean; C:Byte;
begin
  F:=0; Before:=DocChecksum; Z:=1;
  repeat
    SetZoom(Z);
    for I:=0 to 1 do
    begin
      PanView(-64,-64); if I=1 then PanView(64,64);
      for G:=0 to 1 do begin
      GridVisible:=G=1; DrawCanvas;
      for Y:=0 to 127 do for X:=0 to 127 do
      begin
        OK:=ScreenToDoc(CanvasX+X,CanvasY+Y,DX,DY);
        C:=8;
        if (PanX+X div Z<64) and (PanY+Y div Z<64) then
        begin
          if (not OK) or (DX<>PanX+X div Z) or (DY<>PanY+Y div Z) then Inc(F);
          C:=DocPixel(PanX+X div Z,PanY+Y div Z);
          if GridVisible and (Z>=4) and ((X mod Z=Z-1) or (Y mod Z=Z-1)) then C:=8;
        end
        else if OK then Inc(F);
        if GetPixel(CanvasX+X,CanvasY+Y)<>C then Inc(F);
      end;
      end;
      if ScreenToDoc(84,29,DX,DY) or ScreenToDoc(213,29,DX,DY) or
         ScreenToDoc(85,28,DX,DY) or ScreenToDoc(85,157,DX,DY) then Inc(F);
    end;
    Z:=Z*2;
  until Z>8;
  {Exercise real control dispatch, including a consumed menu-dismissal click.}
  InitView;
  HandleClick(4,128,1); if ForeColor<>0 then Inc(F);
  HandleClick(62,174,2); if BackColor<>15 then Inc(F);
  HandleClick(90,164,1); if Zoom<>1 then Inc(F);
  HandleClick(142,164,1); if Zoom<>8 then Inc(F);
  HandleClick(180,164,1); if PanX<0 then Inc(F);
  HandleClick(5,3,1); HandleClick(90,164,1); if Zoom<>8 then Inc(F);
  HandleClick(5,21,1); if SelectedTool<>0 then Inc(F);
  HandleClick(125,110,1); HandleClick(125,110,2);
  {Utilities: click choice, drag choice, cancellation and consumed dismissal.}
  HandleClick(24,21,1); if SelectedTool<>1 then Inc(F);
  HandleClick(8,65,1); if OpenMenu<>7 then Inc(F);
  UtilityMotion(8,65,1); if OpenMenu<>7 then Inc(F);
  HandleClick(8,87,1); if (SelectedUtility<>2) or (OpenMenu<>-1) then Inc(F);
  HandleClick(8,65,1); HandleClick(75,150,1);
  if (ForeColor<>0) or (OpenMenu<>-1) then Inc(F);
  HandleClick(8,65,1); UtilityMotion(8,175,0); UtilityMotion(8,175,1);
  if (SelectedUtility<>13) or (OpenMenu<>-1) then Inc(F);
  HandleClick(8,65,1); UtilityMotion(100,110,0); UtilityMotion(100,110,1);
  if (SelectedUtility<>13) or (OpenMenu<>-1) then Inc(F);
  HandleClick(8,65,1); HandleClick(8,65,1);
  if (SelectedUtility<>13) or (OpenMenu<>-1) then Inc(F);
  HandleClick(8,65,1);
  for I:=0 to 13 do begin UtilityMotion(8,71+I*8,0); if UtilityHover<>I then Inc(F) end;
  HandleClick(8,65,1);
  if DocChecksum<>Before then Inc(F);
  InitUI; DrawUI;
  ViewChecks:=F;
end;
{$endif}

{$ifdef PP16_DRAW_TEST}
function DrawChecks:Word;
var F:Word; S:TMouseState; I,X,Y,Z,A,B:Integer; C:Byte; Before:DWord;
    T0,T1:Word;

  procedure Check(OK:Boolean; const Name:String);
  begin if not OK then begin Inc(F); WriteLn('FAIL: ',Name) end end;

  procedure Feed(SX,SY:Integer; Buttons:Byte);
  begin S.X:=SX; S.Y:=SY; UpdateButtons(Buttons,S); PointerInput(S) end;

  procedure AtDoc(DX,DY:Integer; Buttons:Byte);
  begin Feed(CanvasX+(DX-PanX)*Zoom,CanvasY+(DY-PanY)*Zoom,Buttons) end;

  procedure ResetTest;
  begin
    InitUI; InitBlankDoc(0); SetZoom(2); PanView(-64,-64);
    FillChar(S,SizeOf(S),0); SelectedTool:=3; ForeColor:=15; BackColor:=0;
  end;

begin
  F:=0; ResetTest;
  Check(not DocSetPixel(-1,0,15),'reject negative pixel');
  Check(not DocSetPixel(64,63,15),'reject out-of-range pixel');
  Check(not DocDirty,'rejected writes stay clean');
  ResetTest;
  for Y:=0 to 63 do DocSetPixel(32,Y,2);
  DocSaved; SelectedTool:=2; ForeColor:=5;
  AtDoc(2,2,1); AtDoc(2,2,0);
  Check((DocPixel(2,2)=5) and (DocPixel(31,63)=5) and
        (DocPixel(32,20)=2) and (DocPixel(33,20)=0) and DocCanUndo,
        'bucket fill respects a barrier and creates one undo');
  DocUndo;
  Check((DocPixel(2,2)=0) and (DocPixel(32,20)=2) and not DocDirty,
        'bucket fill undo restores pixels and clean state');
  ResetTest; SelectedTool:=2; ForeColor:=12;
  AtDoc(0,0,1); AtDoc(0,0,0);
  for Y:=0 to 63 do for X:=0 to 63 do
    Check(DocPixel(X,Y)=12,'bucket fill reaches full document');
  DocUndo; Check(not DocDirty and (DocChecksum=0),'full bucket fill undo');
  for I:=0 to 15 do
  begin
    DocSetPixel(2,0,I); DocSetPixel(3,0,15-I);
    Check((DocPixel(2,0)=I) and (DocPixel(3,0)=15-I),'packed nibble preservation');
  end;
  ResetTest;
  for I:=0 to 15 do
  begin
    ForeColor:=I; AtDoc(I,2,1); AtDoc(I,2,0);
    Check(DocPixel(I,2)=I,'all sixteen drawing colors');
  end;
  ResetTest;
  AtDoc(0,0,1); AtDoc(63,0,1); AtDoc(63,63,1); AtDoc(0,63,1); AtDoc(0,0,0);
  for I:=0 to 63 do
    Check((DocPixel(I,0)=15) and (DocPixel(I,63)=15) and
          (DocPixel(0,I)=15) and (DocPixel(63,I)=15),'four full document edges');
  ResetTest;
  AtDoc(0,0,1); AtDoc(63,63,0);
  AtDoc(63,0,1); AtDoc(0,63,0);
  for I:=0 to 63 do
    Check((DocPixel(I,I)=15) and (DocPixel(63-I,I)=15),'fast diagonal continuity');
  SelectedTool:=4; BackColor:=3; AtDoc(0,0,1); AtDoc(63,63,0);
  for I:=0 to 63 do Check(DocPixel(I,I)=3,'eraser uses background color');
  ResetTest;
  SelectedTool:=7; AtDoc(2,2,1); AtDoc(8,5,1);
  Check((DocChecksum=0) and (GetPixel(CanvasX+16,CanvasY+10)=15) and
        (GetPixel(245,51)=0),'shape preview is canvas-only before release');
  KeyInput(27,1,1);
  Check((DocChecksum=0) and (GetPixel(CanvasX+16,CanvasY+10)=0),
        'escape removes shape preview');
  AtDoc(8,5,0);
  ResetTest;
  SelectedTool:=7; AtDoc(2,2,1); AtDoc(8,5,0);
  Check((DocPixel(2,2)=15) and (DocPixel(8,5)=15) and DocCanUndo,
        'line tool commits endpoints as one action');
  DocUndo; Check(not DocDirty and (DocPixel(2,2)=0),'line tool undo');
  ResetTest;
  SelectedTool:=6; AtDoc(3,3,1); AtDoc(8,6,0);
  Check((DocPixel(3,3)=15) and (DocPixel(8,3)=15) and
        (DocPixel(8,8)=15) and (DocPixel(3,8)=15) and
        (DocPixel(5,3)=15) and (DocPixel(5,5)=0),'square tool outline');
  ResetTest;
  SelectedTool:=5; AtDoc(32,32,1); AtDoc(36,34,0);
  Check((DocPixel(36,32)=15) and (DocPixel(28,32)=15) and
        (DocPixel(32,36)=15) and (DocPixel(32,28)=15),'circle tool radius');
  Before:=DocChecksum; SelectedTool:=7; AtDoc(10,10,1); AtDoc(20,20,1);
  KeyInput(27,1,1); AtDoc(20,20,0);
  Check((DocChecksum=Before) and DocDirty and DocCanUndo,'escape cancels pending shape');
  Before:=DocChecksum; AtDoc(20,20,2); AtDoc(21,21,0);
  Check((ForeColor=0) and (DocChecksum=Before),'right drag samples without drawing');
  ResetTest;
  AtDoc(2,10,1); AtDoc(5,10,1); Feed(80,49,1); AtDoc(20,10,1); AtDoc(23,10,0);
  Check((DocPixel(5,10)=15) and (DocPixel(20,10)=15),'re-entry resumes stroke');
  for X:=6 to 19 do Check(DocPixel(X,10)=0,'no chord across canvas exit');
  ResetTest;
  Feed(4,128,1); AtDoc(10,10,1); AtDoc(20,20,0);
  Check(not DocDirty,'palette press cannot become a stroke');
  HandleClick(5,3,1); Before:=DocChecksum;
  AtDoc(50,60,1); AtDoc(51,60,0);
  Check((OpenMenu=-1) and (DocChecksum=Before),'menu dismissal cannot paint');
  ResetTest;
  ForeColor:=12; AtDoc(10,10,1); Feed(65,25,1); Feed(65,25,0);
  Check(SelectedTool=3,'stroke cannot select a tool');
  Before:=DocChecksum; AtDoc(11,11,1); EndGesture(1);
  AtDoc(30,30,1); AtDoc(31,31,0);
  Check(DocPixel(30,30)=0,'ended stroke waits for release');
  ResetTest;
  AtDoc(5,5,3); AtDoc(10,10,1); AtDoc(20,20,0);
  Check(not DocDirty,'simultaneous press is ignored');
  AtDoc(2,2,1); AtDoc(3,3,3); AtDoc(4,4,2); Before:=DocChecksum;
  AtDoc(30,30,2); AtDoc(30,30,0);
  Check(DocChecksum=Before,'second held button cannot start a new gesture');
  Z:=1;
  repeat
    ResetTest; SetZoom(Z); PanView(-64,-64);
    AtDoc(0,0,1); AtDoc(0,0,0);
    PanView(64,64); AtDoc(63,63,1); AtDoc(63,63,0);
    Check((DocPixel(0,0)=15) and (DocPixel(63,63)=15),'draw corners at every zoom');
    Z:=Z*2;
  until Z>8;
  ResetTest; DrawUI; RepaintedCells:=0;
  DocSetPixel(10,10,12); PaintChanges;
  Check((GetPixel(CanvasX+20,CanvasY+20)=12) and (GetPixel(247,56)=12),'live canvas and preview');
  Check(RepaintedCells=1,'single-pixel dirty repaint');
  PaintChanges; Check(RepaintedCells=1,'idle repaint stays zero');
  DocSetPixel(10,10,12); PaintChanges;
  Check(RepaintedCells=1,'same color does not repaint');
  InitBlankDoc(0); DocSetPixel(20,20,0); Check(not DocDirty,'same-color write stays clean');
  {Final drawing fixture and a reproducible, coarse BIOS-tick measurement.}
  InitUI; SetZoom(2); PanView(-64,-64); DrawUI; RepaintedCells:=0;
  FillChar(S,SizeOf(S),0); ForeColor:=15; T0:=MemW[$40:$6C];
  for I:=0 to 15 do
  begin
    AtDoc(4+I*3,48-I,1); PaintChanges;
  end;
  AtDoc(49,33,0); PaintChanges; T1:=MemW[$40:$6C];
  if T1>=T0 then WriteLn('16-point stroke BIOS ticks=',T1-T0);
  WriteLn('Stroke repainted document cells=',RepaintedCells);
  DrawChecks:=F;
end;

{$endif}

{$ifdef PP16_RESPONSE_TEST}
procedure PerfCase(N:Integer);
var T0,T1:Word; I:Integer;
begin
  InitUI;
  if N in [4,9] then
  begin DocBeginAction; DocSetPixel(10,10,12); DocCommitAction end;
  DrawUI;
  T0:=MemW[$40:$6C];
  case N of
    0:for I:=1 to 2 do begin HandleClick(4,3,1); KeyInput(27,1,0) end;
    1:begin
        for I:=0 to 5 do HandleClick(MenuX[I],3,1);
        KeyInput(27,1,0);
      end;
    2:begin HandleClick(24,21,1); HandleClick(8,65,1); HandleClick(8,167,1) end;
    3:begin KeyInput(0,59,0); KeyInput(27,1,0) end;
    4:begin
        KeyInput(27,1,0); KeyInput(9,15,0); KeyInput(9,15,0); KeyInput(13,28,0);
      end;
    5:begin HandleClick(24,143,1); HandleClick(43,158,2); KeyInput(9,15,0) end;
    6:begin
        HandleClick(5,21,1); HandleClick(45,40,1);
        HandleClick(65,40,1); HandleClick(65,21,1);
      end;
    7:begin
        HandleClick(142,164,1); KeyInput(0,77,0); KeyInput(0,80,0);
        HandleClick(125,164,1);
      end;
    8:HandleClick(4,3,1);
    9:KeyInput(27,1,0);
    10:begin
      for I:=0 to 19 do PointerFeedback(CanvasX+I*4,CanvasY+(I div 2)*4);
      HideCursor;
    end;
  end;
  PaintChanges;
  T1:=MemW[$40:$6C];
  if T1>=T0 then WriteLn('UI case ',N,' ticks=',T1-T0);
end;

function ResponseChecks:Word;
var F:Word; S:TMouseState; Before:DWord; I,Y:Integer;

  procedure Check(OK:Boolean; const Name:String);
  begin if not OK then begin Inc(F); WriteLn('FAIL: ',Name) end end;

  procedure Feed(X,Y:Integer; Buttons:Byte);
  begin S.X:=X; S.Y:=Y; UpdateButtons(Buttons,S); PointerInput(S) end;

  procedure CheckStatus(N:Integer; const Value:String);
  var X,Y,A:Integer;
  begin
    if N<0 then PointerFeedback(117,177)
    else PointerFeedback(CanvasX+N*4,CanvasY+N*4);
    HideCursor;
    Check(SaveArea(84,174,213,187,SavedPopup),'status capture');
    FillBox(84,174,213,187,1);
    SmallText(88,176,'GRID X:'+Value+' Y:'+Value,15);
    SmallText(88,182,'IMAGE X:'+Value+' Y:'+Value,15);
    A:=0;
    for Y:=174 to 187 do for X:=42 to 106 do begin
      Check(Mem[VideoSeg:PixelOffset(0,Y)+X]=SavedPopup[A],'opaque coordinate update');
      Inc(A);
    end;
  end;

begin
  F:=0; HideCursor; InitUI; DrawUI; Before:=DocChecksum;
  ShiftHeld:=True; KeyInput(0,77,0);
  Check(PanX=32,'Shift right moves half view');
  ShiftHeld:=False; KeyInput(0,75,0);
  Check(PanX=31,'plain arrow moves one pixel');
  HandleClick(160,164,1); Check(PanX=15,'left click arrow moves half view');
  HandleClick(160,164,2); Check(PanX=14,'right click arrow moves one pixel');
  SetZoom(8); PanView(-64,-64); RedrawView;
  HandleClick(175,164,1); Check(PanX=8,'coarse step follows zoom');
  FillChar(S,SizeOf(S),0);
  Feed(269,78,1); Check((PanX=24) and (PanY=24),'preview centers viewport');
  Feed(319,199,1); Check((PanX=48) and (PanY=48),'preview drag clamps bottom right');
  Feed(0,0,1); Check((PanX=0) and (PanY=0),'preview drag clamps top left');
  KeyInput(27,1,1); Feed(300,109,1); Feed(300,109,0);
  Check((Gesture=0) and (PanX=0) and (PanY=0),'cancel consumes held preview drag');
  Feed(300,109,1); Feed(269,78,0);
  Check((Gesture=0) and (PanX=24) and (PanY=24),'preview includes release position');
  Check((DocChecksum=Before) and not DocDirty and not DocCanUndo,'navigation leaves document intact');
  {Use an independent transparent-text redraw as the numeric-field oracle.}
  SetZoom(4); PanView(-64,-64); RedrawView;
  CheckStatus(9,'9 '); CheckStatus(10,'10'); CheckStatus(9,'9 '); CheckStatus(-1,'--');
  {Keep a final coordinate/cursor fixture for host inspection.}
  PointerFeedback(CanvasX+40,CanvasY+40);
  WriteLn('Response: pan controls, preview drag, coordinate transitions checked');
  ResponseChecks:=F;
end;

{$endif}

{$ifdef PP16_FILEUI_TEST}
function FileUIChecks:Word;
var F:Word; Before:DWord; I:Integer;

  procedure Check(OK:Boolean; const Name:String);
  begin if not OK then begin Inc(F); WriteLn('FAIL: ',Name) end end;

  procedure TypeName(const S:String);
  var I:Integer;
  begin
    for I:=1 to Length(S) do KeyInput(Ord(S[I]),0,0);
  end;

begin
  F:=0; InitUI; DrawUI; Before:=DocChecksum;
  KeyInput(19,31,0); Check(OpenMenu=9,'Save of unnamed image opens dialog');
  HandleClick(210,155,1); Check(DocChecksum=Before,'file dialog blocks canvas');
  TypeName('UITEST'); KeyInput(13,28,0);
  Check((OpenMenu=-1) and (CurrentFile='UITEST.P16') and not DocDirty,'Save adds extension');
  DocBeginAction; DocSetPixel(0,0,12); DocCommitAction; PaintChanges;
  KeyInput(19,31,0); Check((OpenMenu=-1) and not DocDirty and DocCanUndo,'Save keeps undo');
  KeyInput(8,14,0); PaintChanges;
  Check(DocDirty and (DocChecksum=Before),'undo after Save marks restored image dirty');
  ShiftHeld:=True; KeyInput(19,31,0); ShiftHeld:=False;
  Check(OpenMenu=9,'Ctrl Shift S opens Save As');
  KeyInput(13,28,0); KeyInput(13,28,0);
  Check((OpenMenu=9) and DocDirty,'overwrite defaults to Cancel');
  KeyInput(27,1,0); Check((OpenMenu=-1) and DocDirty,'cancel Save As preserves image');
  KeyInput(15,24,0); Check(OpenMenu=8,'dirty Open requires discard choice');
  KeyInput(13,28,0); Check((OpenMenu=-1) and DocDirty,'default Enter cancels dirty Open');
  KeyInput(15,24,0); KeyInput(9,15,0); KeyInput(13,28,0);
  Check(OpenMenu=9,'explicit discard opens file dialog');
  TypeName('MISSING'); KeyInput(13,28,0);
  Check((OpenMenu=9) and DocDirty and (DocChecksum=Before),'failed Open preserves image');
  TypeName('UITEST'); KeyInput(13,28,0);
  Check((OpenMenu=-1) and not DocDirty and not DocCanUndo and
        (DocPixel(0,0)=12) and (CurrentFile='UITEST.P16'),'Open replaces pixels and resets undo');
  StartFileDialog(True); TypeName('UICOPY'); KeyInput(13,28,0);
  Check(CurrentFile='UICOPY.P16','Save As changes filename');
  HandleClick(4,3,1); HandleClick(16,16,1);
  Check((CurrentFile='') and not DocDirty,'New clears filename');
  KeyInput(15,24,0); KeyInput(9,15,0); KeyInput(0,80,0); KeyInput(13,28,0);
  Check((OpenMenu=-1) and (CurrentFile<>'') and not DocDirty,'keyboard file list opens a file');
  StartFileDialog(False); HandleClick(76,73,1); HandleClick(110,130,1);
  Check((OpenMenu=-1) and (CurrentFile='UICOPY.P16'),'mouse file list and OK');
  StartFileDialog(True); KeyInput(13,28,0); KeyInput(9,15,0); KeyInput(13,28,0);
  Check((OpenMenu=-1) and not DocDirty,'explicit overwrite confirms');
  StartFileDialog(False);
  WriteLn('M6: Save/Open dialogs, overwrite, dirty protection and saved undo checked');
  FileUIChecks:=F;
end;

{$endif}

{$ifdef PP16_UNDO_TEST}
function UndoChecks:Word;
var F:Word; S:TMouseState; X,Y:Integer; Before:DWord;

  procedure Check(OK:Boolean; const Name:String);
  begin if not OK then begin Inc(F); WriteLn('FAIL: ',Name) end end;

  procedure Feed(SX,SY:Integer; Buttons:Byte);
  begin S.X:=SX; S.Y:=SY; UpdateButtons(Buttons,S); PointerInput(S) end;

  procedure AtDoc(DX,DY:Integer; Buttons:Byte);
  begin Feed(CanvasX+DX*2,CanvasY+DY*2,Buttons) end;

  procedure ResetTest;
  begin
    InitUI; InitBlankDoc(0); SetZoom(2); PanView(-64,-64);
    FillChar(S,SizeOf(S),0); DrawUI;
  end;

  procedure Choose(M,I:Integer);
  begin
    HandleClick(MenuX[M],3,1);
    HandleClick(PopupX[M]+14,MenuRowY(M,I)+1,1);
  end;

begin
  F:=0; ResetTest;
  Check(not DocCanUndo,'new document has no undo');
  AtDoc(0,0,1); AtDoc(63,0,1); AtDoc(63,63,1); AtDoc(0,63,0);
  Check(DocCanUndo and DocDirty,'completed long stroke creates undo');
  KeyInput(8,14,0); PaintChanges;
  for Y:=0 to 63 do for X:=0 to 63 do
    Check(DocPixel(X,Y)=0,'whole stroke restored pixel exactly');
  Check(not DocDirty and not DocCanUndo,'undo restores clean flag and consumes snapshot');
  KeyInput(8,14,0); Check(DocChecksum=0,'second undo does not toggle');
  AtDoc(10,10,1); AtDoc(10,10,0);
  ForeColor:=12; AtDoc(20,20,1); AtDoc(30,30,0);
  Choose(1,0);
  Check((DocPixel(10,10)=15) and (DocPixel(20,20)=0) and DocDirty,
        'menu undo restores previous dirty document');
  ForeColor:=15; AtDoc(10,10,1); AtDoc(10,10,0);
  Check(not DocCanUndo,'no-change stroke does not manufacture undo');

  ResetTest; AtDoc(10,10,1); AtDoc(10,10,0);
  AtDoc(10,10,1); AtDoc(10,10,0); {Same color.}
  AtDoc(10,10,2); AtDoc(10,10,0); {Sampler.}
  HandleClick(4,128,1); KeyInput(50,3,0); {Palette and zoom.}
  Check(DocCanUndo,'no-op stroke sampler and view preserve undo');
  HandleClick(198,21,1);
  Check((DocChecksum=0) and not DocDirty,'canvas undo button restores document');

  ResetTest; ForeColor:=12; AtDoc(2,2,1); AtDoc(10,10,0);
  Before:=DocChecksum; SelectedTool:=4; BackColor:=3;
  AtDoc(2,2,1); AtDoc(10,10,0); DocUndo;
  Check(DocChecksum=Before,'eraser undoes as one action');
  ResetTest; AtDoc(2,2,1); AtDoc(4,4,0); Before:=DocChecksum;
  AtDoc(20,20,1); AtDoc(40,40,1); PaintChanges;
  KeyInput(27,1,1); PaintChanges;
  Check((DocChecksum=Before) and DocDirty and DocCanUndo,
        'cancel restores dirty image and preserves preceding undo');
  Check((GetPixel(CanvasX+40,CanvasY+40)=0) and (GetPixel(257,66)=0),
        'cancel restores canvas and preview');
  AtDoc(50,50,1); AtDoc(50,50,0);
  Check(DocChecksum=Before,'cancel blocks held button until release');
  DocUndo; Check((DocChecksum=0) and not DocDirty,'old undo survives canceled stroke');
  ResetTest; AtDoc(0,0,1); AtDoc(63,63,1); KeyInput(27,1,0);
  AtDoc(63,63,0);
  Check((DocChecksum=0) and not DocDirty and not DocCanUndo,
        'cancel first stroke including release restores clean state');

  InitUI; Before:=DocChecksum; Choose(3,0);
  Check((DocChecksum=0) and DocDirty and DocCanUndo,'menu clear is undoable');
  DocUndo; Check((DocChecksum=Before) and not DocDirty,'clear undo restores demo');
  ForeColor:=6; Choose(3,1);
  for Y:=0 to 63 do for X:=0 to 63 do
    Check(DocPixel(X,Y)=6,'clear to foreground covers all pixels');
  Choose(3,1); DocUndo;
  Check(DocChecksum=Before,'same-color clear preserves preceding undo');
  KeyInput(0,46,0); Check(DocChecksum=0,'Alt+C clears');
  DocUndo; Check(DocChecksum=Before,'Alt+C undo');

  ResetTest; AtDoc(10,10,1); AtDoc(10,10,0); Before:=DocChecksum;
  Choose(0,0);
  Check((OpenMenu=8) and not ConfirmDiscard,'dirty New defaults to Cancel');
  HandleClick(4,3,1); HandleClick(4,128,1);
  Check((OpenMenu=8) and (DocChecksum=Before) and (ForeColor=15),
        'modal blocks menu and palette clicks');
  KeyInput(13,28,0);
  Check((OpenMenu=-1) and (DocChecksum=Before) and DocCanUndo,
        'default Enter cancels New and preserves undo');
  Choose(0,15); KeyInput(27,1,0);
  Check(not ExitRequested and (DocChecksum=Before),'Escape cancels dirty File Exit');
  KeyInput(27,1,0); HandleClick(180,115,1);
  Check(not ExitRequested and (OpenMenu=-1),'mouse Cancel keeps working image');
  Choose(0,0); KeyInput(9,15,0); KeyInput(13,28,0);
  Check((DocChecksum=0) and not DocDirty and not DocCanUndo and (OpenMenu=-1),
        'explicit discard creates clean blank and resets undo');
  InitUI; Choose(0,0);
  Check((DocChecksum=0) and (OpenMenu=-1),'clean New needs no discard prompt');
  Choose(0,15); Check(ExitRequested,'clean File Exit works');

  ResetTest; AtDoc(10,10,1); AtDoc(10,10,0); Choose(0,0);
  Feed(80,115,1); AtDoc(30,30,1); AtDoc(30,30,0);
  Check((DocChecksum=0) and not DocDirty,'discard click cannot leak into new canvas');
  ResetTest; AtDoc(10,10,1); AtDoc(10,10,0); KeyInput(27,1,0);
  KeyInput(9,15,0); KeyInput(13,28,0);
  Check(ExitRequested,'explicit keyboard discard exits');
  ResetTest; AtDoc(10,10,1); AtDoc(10,10,0); Choose(0,15);
  HandleClick(80,115,1); Check(ExitRequested,'explicit mouse discard exits');

  {Leave a realistic dirty-document prompt for the framebuffer inspection.}
  InitUI; SetZoom(2); PanView(-64,-64); DrawUI; FillChar(S,SizeOf(S),0);
  ForeColor:=15; AtDoc(4,48,1); AtDoc(49,33,0);
  RequestCommand(2);
  WriteLn('M5: whole-action undo, cancel, clear, New/Exit protection checked');
  UndoChecks:=F;
end;
{$endif}
end.

