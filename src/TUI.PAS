unit TUI;
{$mode tp}{$H-}{$R+}{$Q+}
interface
uses TMouse;
var ForeColor,BackColor,BrushSize:Byte; SelectedTool:Integer;
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
{$ifdef PP16_CLIP_TEST}function ClipChecks:Word;{$endif}
{$ifdef PP16_GRADIENT_TEST}function GradientChecks:Word;{$endif}
{$ifdef PP16_IMPORT_TEST}function ImportChecks:Word;{$endif}
procedure PointerFeedback(X,Y:Integer);
implementation
uses Dos,TVideo,TCursor,TDoc,TView,TFont,TFiles,TFDialog,TRaster,TPaint
{$ifdef PP16_CLIP_ENABLED},TClip{$endif};
const ToolNames:array[0..7] of String[12]=
      ('SELECT','CLIPBOARD','BUCKET FILL','BRUSH','CUT','CIRCLE','SQUARE','LINE');
      MenuX:array[0..5] of Integer=(4,56,108,160,220,284);
const ImagePreviewX=233; ImagePreviewY=29;
      ToolAtlasName='PP16UI.P16'; ToolAtlasCell=14; ToolAtlasStep=16;
      ToolAtlasTransparent=11; {Light cyan: icon-cell background / transparent key.}
      EllipseSelectSprite=12;
      NavigationY=161;
      ZoomButtonX=84; ZoomButtonWidth=13; ZoomButtonHeight=11; ZoomButtonStep=21;
      ClipPreviewX=233; ClipPreviewY=113; ClipPreviewSize=64;
      ClipClearButtonX=300; ClipClearButtonY=112;
      ClipClearButtonWidth=18; ClipClearButtonHeight=10;
      ClipTransformButtonX=300; ClipTransformButtonSize=18;
      ClipMirrorButtonY=123; ClipRotateButtonY=142; ClipScaleButtonY=161;
      PaletteY=126; PaletteStep=11; PaletteHeight=10;
      GradientY=177; GradientHeight=13; GradientBoxWidth=12;
      GradientAX=2; GradientBX=66; GradientRampX=16; GradientRampWidth=48;
var OpenMenu:Integer;
    HoverDX,HoverDY:Integer; ExitRequested:Boolean;
    Gesture:Byte; StrokeColor,StrokeSize:Byte; StrokeX,StrokeY:Integer;
    ShapeTool:Byte; ShapeX,ShapeY:Integer;
    ShapePreviewX,ShapePreviewY:Integer; ShapePreviewVisible:Boolean;
    StrokeValid,ShapeValid,PointerBlocked,PaintedDirty:Boolean;
    RepaintedCells:Word;
    PendingCommand:Byte; ConfirmDiscard:Boolean;
    ToolAtlas:TDocPixels; ToolAtlasLoaded:Boolean;
    CachedTool,CachedFore,CachedBack:Integer;
    GradientArm:Byte;
    PreviewValid:Boolean; PreviewX1,PreviewY1,PreviewX2,PreviewY2:Integer;
    ViewedZoom,ViewedPanX,ViewedPanY:Integer; ViewedGrid:Boolean;
    SavedPopup:TSavedArea; PopupSaved:Boolean;
    SavedX1,SavedY1,SavedX2,SavedY2:Integer;
    CanvasFrame:array[0..127,0..64] of Byte;
    StatusValid,ShiftHeld,CtrlHeld,PasteBehind:Boolean;
    StatusValues:array[0..3] of String[2];
{$ifdef PP16_CLIP_ENABLED}
    SelectionValid,PasteMode,EllipseSelectTool,SelectionEllipse:Boolean;
    SelectionX,SelectionY,SelectionW,SelectionH:Integer;
    SelectionAnchorX,SelectionAnchorY,PasteX,PasteY,PasteMouseX,PasteMouseY:Integer;
    PasteShown:Boolean;
{$endif}

procedure PaintChanges; forward;
procedure StartFileDialog(Saving:Boolean); forward;
procedure Title; forward;
{$ifdef PP16_CLIP_ENABLED}
procedure PreviewShapePixel(X,Y:Integer; C:Integer); forward;
{$endif}

function Num(N:Integer):String;
var S:String[6];
begin Str(N,S); Num:=S end;

procedure Button(X,Y,W,H:Integer; Down:Boolean);
var A,B:Byte; I:Integer;
begin
  FillBox(X,Y,X+W-1,Y+H-1,7);
  if Down then begin A:=8; B:=15 end else begin A:=15; B:=8 end;
  HSpan(X,X+W-1,Y,A); HSpan(X,X+W-1,Y+H-1,B);
  for I:=Y+1 to Y+H-2 do begin PutPixel(X,I,A); PutPixel(X+W-1,I,B) end;
end;

procedure UILinePixel(X,Y,C:Integer);
begin PutPixel(X,Y,Byte(C)) end;
procedure Line(X1,Y1,X2,Y2:Integer; C:Byte);
begin RasterLine(X1,Y1,X2,Y2,C,UILinePixel) end;
procedure ToolFrame(I:Integer);
var X,Y:Integer; A,B,C:Byte;
begin
  X:=2+(I mod 4)*19; Y:=18+(I div 4)*19;
  if I=SelectedTool then begin A:=8; B:=15; C:=14 end
  else begin A:=15; B:=8; C:=7 end;
  HSpan(X,X+17,Y,A); HSpan(X,X+17,Y+17,B);
  Line(X,Y+1,X,Y+16,A); Line(X+17,Y+1,X+17,Y+16,B);
  DrawBorder(X+1,Y+1,X+16,Y+16,C);
end;

function ToolUsesBrushSize:Boolean;
begin ToolUsesBrushSize:=SelectedTool in [3,5,6,7] end;

function ToolIcon(I:Integer):Integer;
begin
  ToolIcon:=I;
  {$ifdef PP16_CLIP_ENABLED}
  if (I=0) and EllipseSelectTool then ToolIcon:=EllipseSelectSprite;
  {$endif}
end;

function ToolAtlasPixel(Tool,X,Y:Integer):Byte;
var A:Word; SX,SY:Integer;
begin
  SX:=(Tool mod 4)*ToolAtlasStep+X;
  SY:=(Tool div 4)*ToolAtlasStep+Y;
  A:=Word(SY)*32+Word(SX div 2);
  if Odd(SX) then ToolAtlasPixel:=ToolAtlas[A] and 15
  else ToolAtlasPixel:=ToolAtlas[A] shr 4;
end;

procedure AtlasIcon(Sprite,X,Y:Integer);
var J,K:Integer; C:Byte;
begin
  if not ToolAtlasLoaded then Exit;
  for J:=0 to ToolAtlasCell-1 do for K:=0 to ToolAtlasCell-1 do
  begin
    C:=ToolAtlasPixel(Sprite,K,J);
    if C<>ToolAtlasTransparent then PutPixel(X+K,Y+J,C);
  end;
end;

procedure LoadToolAtlas;
begin
  ToolAtlasLoaded:=LoadImage(ToolAtlasName);
  if ToolAtlasLoaded then DocCopy(ToolAtlas);
  {The atlas is a startup resource, never the user's current document.}
  InitDemoDoc; CurrentFile:=''; FileError:='';
end;

procedure Tools;
var I,X,Y,J,K:Integer; C:Byte;
begin
  if CachedTool<0 then for I:=0 to 7 do
  begin
    X:=2+(I mod 4)*19; Y:=18+(I div 4)*19;
    Button(X,Y,18,18,I=SelectedTool);
    FillBox(X+2,Y+2,X+15,Y+15,11);
    AtlasIcon(ToolIcon(I),X+2,Y+2);
    if I=SelectedTool then DrawBorder(X+1,Y+1,X+16,Y+16,14);
  end;
  if CachedTool>=0 then
    if CachedTool<>SelectedTool then
    begin ToolFrame(CachedTool); ToolFrame(SelectedTool) end;
  FillBox(2,63,76,69,1);
  {$ifdef PP16_CLIP_ENABLED}
  if (SelectedTool=0) and SelectionValid then
    SmallText(7,64,'SELECT:'+Num(SelectionW)+'X'+Num(SelectionH),15)
  else
  {$endif}
    SmallText(7,64,ToolNames[SelectedTool],15);
  FillBox(0,70,78,79,0);
  Button(2,70,9,9,False); Button(68,70,9,9,False);
  if ToolUsesBrushSize then
  begin
    if BrushSize>1 then SmallText(5,72,'-',4) else SmallText(5,72,'-',8);
    if BrushSize<5 then SmallText(71,72,'+',4) else SmallText(71,72,'+',8);
    SmallText(17,72,'SIZE:'+Num(BrushSize),15);
  end
  else
  begin
    SmallText(5,72,'-',8); SmallText(71,72,'+',8);
    SmallText(17,72,'SIZE:--',8);
  end;
  CachedTool:=SelectedTool;
end;

procedure ChangeBrushSize(Delta:Integer);
var NewSize:Integer;
begin
  if not ToolUsesBrushSize then Exit;
  NewSize:=Integer(BrushSize)+Delta;
  if (NewSize<1) or (NewSize>5) then Exit;
  BrushSize:=NewSize; Tools;
end;

function RampStep(X:Integer):Byte;
begin RampStep:=((X-GradientRampX)*11) div GradientRampWidth end;

procedure GradientPanel;
var X,Y,M:Integer; A,B:Byte; S:String[16];
begin
  FillBox(1,170,78,190,0);
  S:='DITHER '+Num(GradientStep*10)+'%';
  if GradientArm=1 then S:='PICK A: PALETTE'
  else if GradientArm=2 then S:='PICK B: PALETTE';
  SmallText(4,170,S,7);
  A:=7; B:=7;
  if GradientArm=1 then A:=14 else if GradientArm=2 then B:=14;
  DrawBorder(GradientAX,GradientY,GradientAX+GradientBoxWidth-1,
    GradientY+GradientHeight-1,A);
  DrawBorder(GradientBX,GradientY,GradientBX+GradientBoxWidth-1,
    GradientY+GradientHeight-1,B);
  FillBox(GradientAX+1,GradientY+1,GradientAX+GradientBoxWidth-2,
    GradientY+GradientHeight-2,GradientFirst);
  FillBox(GradientBX+1,GradientY+1,GradientBX+GradientBoxWidth-2,
    GradientY+GradientHeight-2,GradientLast);
  for Y:=GradientY+1 to GradientY+GradientHeight-2 do
    for X:=GradientRampX+1 to GradientRampX+GradientRampWidth-2 do
      PutPixel(X,Y,MixColor(X-GradientRampX,Y-GradientY,RampStep(X)));
  DrawBorder(GradientRampX,GradientY,GradientRampX+GradientRampWidth-1,
    GradientY+GradientHeight-1,8);
  M:=GradientRampX+((Integer(GradientStep)*2+1)*GradientRampWidth) div 22;
  if ForeColor=GradientPaint then A:=15 else A:=8;
  HSpan(M-1,M+1,190,A);
end;

procedure Colors;
var I,X,Y:Integer; S:String[6];
begin
  if (CachedFore=ForeColor) and (CachedBack=BackColor) then Exit;
  if CachedFore<0 then begin
  FillBox(1,80,78,115,0);
  SmallText(2,86,'>',15); DrawBorder(12,80,48,94,15);
  DrawBorder(12,99,48,113,15);
  SmallText(7,118,'PALETTE',7);
  end;
  if (CachedFore<0) or (CachedFore<>ForeColor) then begin
    if ForeColor=GradientPaint then
      for Y:=82 to 92 do for X:=14 to 46 do
        PutPixel(X,Y,PaintColor(X-14,Y-82,GradientPaint))
    else FillBox(14,82,46,92,ForeColor);
    FillBox(52,85,77,89,0);
    if ForeColor=GradientPaint then S:=Num(GradientStep*10)+'%'
    else S:=Num(ForeColor);
    SmallText(52,85,':'+S,15);
  end;
  if (CachedFore<0) or (CachedBack<>BackColor) then begin
    FillBox(14,101,46,111,BackColor); FillBox(52,104,77,108,0);
    SmallText(52,104,':'+Num(BackColor),15);
  end;
  for I:=0 to 15 do
  if (CachedFore<0) or (I=CachedFore) or (I=CachedBack) or
     (I=ForeColor) or (I=BackColor) then
  begin
    X:=2+(I mod 4)*19; Y:=PaletteY+(I div 4)*PaletteStep;
    FillBox(X,Y,X+17,Y+PaletteHeight-1,I);
    DrawBorder(X,Y,X+17,Y+PaletteHeight-1,8);
    if I=ForeColor then DrawBorder(X+1,Y+1,X+16,Y+PaletteHeight-2,15);
    if I=BackColor then PutPixel(X+3,Y+PaletteHeight-4,15);
  end;
  if (CachedFore<0) or ((ForeColor=GradientPaint)<>(CachedFore=GradientPaint)) then
    GradientPanel;
  CachedFore:=ForeColor; CachedBack:=BackColor;
end;

procedure SwapColors;
var C:Byte;
begin
  C:=ForeColor; ForeColor:=BackColor;
  if C<>GradientPaint then BackColor:=C;
  if GradientArm<>0 then begin GradientArm:=0; CachedFore:=-1 end;
  Colors;
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
        A:=(X*Zoom+1) div 2; H:=Zoom div 2;
        PairColor:=Col or (Col shl 4);
        Row[A]:=(Row[A] and $F0) or Col;
        for J:=1 to H-1 do Row[A+J]:=PairColor;
        if GridVisible and (Zoom>=2) then Edge:=8 else Edge:=Col;
        Row[A+H]:=(Row[A+H] and 15) or (Edge shl 4);
      end;
    for R:=0 to Zoom-1 do
      if GridVisible and (Zoom>=2) and (R=Zoom-1) then
        Move(GridRow,CanvasFrame[Y+R],SizeOf(Row))
      else Move(Row,CanvasFrame[Y+R],SizeOf(Row));
    Inc(Y,Zoom);
  end;
  HideCursor;
  FillBox(84,18,213,25,0);
  SmallText(86,20,'GRID:'+Num(C)+'X'+Num(C),15);
  HSpan(84,213,28,7); HSpan(84,213,157,7);
  for Y:=0 to 127 do WriteVideoBytes(42,CanvasY+Y,65,CanvasFrame[Y]);
end;

procedure PaintPreviewRows;
var Y,J:Integer; Source:TDocRow; Row:array[0..32] of Byte;
begin
  {The preview starts on an odd pixel. Repack each document row into its
   33-byte video span, including the frame-edge nibbles. This is also used
   after undo/cancel, when every document row changed at once.}
  for Y:=0 to 63 do
  begin
    DocReadRow(Y,Source);
    Row[0]:=$70 or (Source[0] shr 4);
    for J:=1 to 31 do
      Row[J]:=((Source[J-1] and $0F) shl 4) or (Source[J] shr 4);
    Row[32]:=((Source[31] and $0F) shl 4) or 7;
    WriteVideoBytes(ImagePreviewX div 2,ImagePreviewY+Y,33,Row);
  end;
end;

procedure Preview;
var X,Y,X1,Y1,X2,Y2:Integer;

  procedure RestorePixel(X,Y:Integer);
  var C:Byte;
  begin
    C:=0;
    if (X>=ImagePreviewX) and (X<ImagePreviewX+64) and
       (Y>=ImagePreviewY) and (Y<ImagePreviewY+64) then
      C:=DocPixel(X-ImagePreviewX,Y-ImagePreviewY);
    PutPixel(X,Y,C);
  end;

begin
  if PreviewValid then begin
    for X:=PreviewX1 to PreviewX2 do begin RestorePixel(X,PreviewY1); RestorePixel(X,PreviewY2) end;
    for Y:=PreviewY1+1 to PreviewY2-1 do begin RestorePixel(PreviewX1,Y); RestorePixel(PreviewX2,Y) end;
  end else begin
  SmallText(219,20,'IMAGE:64X64',15);
  DrawBorder(ImagePreviewX-1,28,ImagePreviewX+64,94,7);
  FillBox(ImagePreviewX,ImagePreviewY,ImagePreviewX+63,ImagePreviewY+63,0);
  PaintPreviewRows;
  end;
  {The complete image is visible at 1x and 2x, so only 4x/8x need a viewport
   indicator. The fixed frame is always painted last after temporary cleanup.}
  if Zoom>=4 then
  begin
    X1:=ImagePreviewX+PanX; Y1:=ImagePreviewY+PanY;
    X2:=X1+VisibleCells-1; Y2:=Y1+VisibleCells-1;
    if X2>=ImagePreviewX+64 then X2:=ImagePreviewX+63;
    if Y2>=ImagePreviewY+64 then Y2:=ImagePreviewY+63;
    DrawBorder(X1-1,Y1-1,X2+1,Y2+1,8);
    PreviewX1:=X1-1; PreviewY1:=Y1-1; PreviewX2:=X2+1; PreviewY2:=Y2+1;
    PreviewValid:=True;
  end
  else PreviewValid:=False;
  DrawBorder(ImagePreviewX-1,28,ImagePreviewX+64,94,7);
end;

procedure ClipboardPanel;
{$ifdef PP16_CLIP_ENABLED}
var X,Y,OffsetX,OffsetY:Integer; S:String[12];
{$endif}
begin
  FillBox(218,101,318,190,0);
  DrawBorder(ClipPreviewX-1,112,ClipPreviewX+64,178,7);
  {$ifdef PP16_CLIP_ENABLED}
  Button(ClipClearButtonX,ClipClearButtonY,ClipClearButtonWidth,
    ClipClearButtonHeight,False);
  SmallText(ClipClearButtonX+3,ClipClearButtonY+2,'CLR',4);
  Button(ClipTransformButtonX,ClipMirrorButtonY,ClipTransformButtonSize,
    ClipTransformButtonSize,False);
  Button(ClipTransformButtonX,ClipRotateButtonY,ClipTransformButtonSize,
    ClipTransformButtonSize,False);
  Button(ClipTransformButtonX,ClipScaleButtonY,ClipTransformButtonSize,
    ClipTransformButtonSize,False);
  AtlasIcon(9,ClipTransformButtonX+2,ClipMirrorButtonY+2);
  AtlasIcon(8,ClipTransformButtonX+2,ClipRotateButtonY+2);
  AtlasIcon(10,ClipTransformButtonX+2,ClipScaleButtonY+2);
  if ClipboardValid then
  begin
    S:='CLIP:'+Num(ClipboardWidth)+'X'+Num(ClipboardHeight);
    SmallText(219,104,S,15);
    OffsetX:=(ClipPreviewSize-ClipboardWidth) div 2;
    OffsetY:=(ClipPreviewSize-ClipboardHeight) div 2;
    for Y:=0 to ClipboardHeight-1 do for X:=0 to ClipboardWidth-1 do
      PutPixel(ClipPreviewX+OffsetX+X,ClipPreviewY+OffsetY+Y,ClipboardPixel(X,Y));
  end
  else SmallText(219,104,'CLIP: EMPTY',8);
  {$else}
  SmallText(219,104,'CLIP: OFF',8);
  {$endif}
end;

function ControlHit(X,Y,StartX,Width,Height,Step,Count:Integer; var Index:Integer):Boolean;
begin
  ControlHit:=False;
  if (X<StartX) or (Y<NavigationY) or (Y>=NavigationY+Height) then Exit;
  Index:=(X-StartX) div Step;
  if (Index<0) or (Index>=Count) or ((X-StartX) mod Step>=Width) then Exit;
  ControlHit:=True;
end;

function InZoomControl(X,Y:Integer):Boolean;
var I:Integer;
begin
  InZoomControl:=ControlHit(X,Y,ZoomButtonX,ZoomButtonWidth,
    ZoomButtonHeight,ZoomButtonStep,3,I);
end;

procedure Navigation;
var I,Z:Integer;
begin
  Z:=2;
  for I:=0 to 2 do begin Button(ZoomButtonX+I*ZoomButtonStep,NavigationY,
    ZoomButtonWidth,ZoomButtonHeight,Zoom=Z);
    SmallText(ZoomButtonX+(ZoomButtonWidth-7) div 2+I*ZoomButtonStep,
      NavigationY+(ZoomButtonHeight-5) div 2,Num(Z)+'X',4); Z:=Z*2 end;
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
  begin GX:=(X-CanvasX) div Zoom;
        GY:=(Y-CanvasY) div Zoom end;
  V[0]:=Coord(GX); V[1]:=Coord(GY); V[2]:=Coord(DX); V[3]:=Coord(DY);
  Changed:=not StatusValid;
  for I:=0 to 3 do if V[I]<>StatusValues[I] then Changed:=True;
  HoverDX:=DX; HoverDY:=DY;
  if not Changed then Exit;
  if CursorOverlaps(84,175,213,187) then HideCursor;
  if not StatusValid then begin
    FillBox(84,175,213,187,1);
    SmallText(88,176,'GRID X:',15); SmallText(124,176,' Y:',15);
    SmallText(88,182,'IMAGE X:',15); SmallText(128,182,' Y:',15);
    for I:=0 to 3 do StatusValues[I]:='??';
  end;
  for I:=0 to 3 do for J:=1 to 2 do
    if V[I][J]<>StatusValues[I][J] then SmallCharOpaque(SX[I]+(J-1)*4,SY[I],V[I][J],15,1);
  for I:=0 to 3 do StatusValues[I]:=V[I];
  StatusValid:=True;
end;

const PopupX:array[0..5] of Integer=(1,32,64,96,136,184);
      PopupW:array[0..5] of Integer=(168,152,104,200,176,112);
      MenuRows:array[0..5] of Integer=(6,7,1,2,0,2);
      Labels:array[0..5,0..7] of String[20]=(
       ('New','Open...','Save','Save As...','Import...','Exit','',''),
       ('Undo','','Cut','Copy','Paste','','Paste Behind',''),
       ('Grid On','','','','','','',''),
       ('Clear','Clear to Colour','','','','','',''),
       ('','','','','','','',''),
       ('Quick Help','About PP16','','','','','',''));

function MenuRowY(M,I:Integer):Integer;
var J,Y:Integer;
begin
  Y:=15;
  for J:=0 to I-1 do if Labels[M,J]='' then Inc(Y,5) else Inc(Y,9);
  MenuRowY:=Y;
end;

function Enabled(M,I:Integer):Boolean;
begin
  Enabled:=((M=0) and (I in [0..5])) or
{$ifdef PP16_CLIP_ENABLED}
           ((M=1) and (((I=0) and DocCanUndo) or
                       ((I in [2,3]) and SelectionValid) or
                       ((I=4) and ClipboardValid) or (I=6))) or
{$else}
           ((M=1) and (I=0) and DocCanUndo) or
{$endif}
           ((M=3) and (I in [0,1])) or ((M=2) and (I=0)) or
           ((M=5) and (I in [0,1]));
end;

function Shortcut(M,I:Integer):String;
begin
  Shortcut:='';
  case M of
    1:case I of 2:Shortcut:='Ctrl+X'; 3:Shortcut:='Ctrl+C'; 4:Shortcut:='Ctrl+V' end;
    2:if I=0 then Shortcut:='F4';
    3:if I=0 then Shortcut:='Alt+C';


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
    FillBox(36,49,283,143,1); DrawBorder(36,49,283,143,9); DrawBorder(39,52,280,140,7);
    if PendingCommand=1 then Text8(64,59,'New blank image?',15)
    else Text8(88,59,'Exit PP16?',15);
    SmallText(52,78,'THIS IMAGE HAS UNSAVED CHANGES.',14);
    SmallText(52,88,'CANCEL TO SAVE FIRST, OR DISCARD.',15);
    Button(60,108,84,15,ConfirmDiscard);
    Button(164,108,84,15,not ConfirmDiscard);
    SmallText(86,113,'DISCARD',4); SmallText(190,113,'CANCEL',4);
    if ConfirmDiscard then DrawBorder(62,110,141,120,4) else DrawBorder(166,110,245,120,4);
    SmallText(52,131,'TAB: SELECT  ENTER: OK  ESC: CANCEL',15);
    Exit;
  end;
  if OpenMenu=6 then
  begin
    {217 screen pixels wide means 109 packed bytes per row. At 112 rows this
     stays inside the 12,288-byte popup save area while leaving room for a
     readable two-column quick reference.}
    FillBox(52,44,268,155,1); DrawBorder(52,44,268,155,9); DrawBorder(55,47,265,152,7);
    Text8(100,52,'PP16 QUICK HELP',15);
    HSpan(62,258,65,8);
    SmallText(64,70,'CANVAS',14); SmallText(164,70,'EDIT',14);
    SmallText(64,79,'DRAG: DRAW',15);
    SmallText(64,87,'RIGHT DRAG: PICK',15);
    SmallText(64,95,'2/4/8: ZOOM',15);
    SmallText(64,103,'ARROWS: PAN',15);
    SmallText(64,111,'SHIFT+ARROWS: FAST',15);
    SmallText(164,79,'CTRL+Z: UNDO',15);
    SmallText(164,87,'ESC: CANCEL STROKE',15);
    SmallText(164,95,'CTRL+C/X/V: CLIP',15);
    SmallText(164,103,'TAB: SWAP COLORS',15);
    SmallText(164,111,'ALT+C: CLEAR',15);
    HSpan(62,258,121,8);
    SmallText(64,126,'DITHER: END BOX, THEN PALETTE',15);
    SmallText(64,133,'RAMP: MIX  PALETTE: SOLID',15);
    SmallText(64,141,'F4: GRID   ESC/CLICK: CLOSE',15); Exit;
  end;
  if OpenMenu=7 then
  begin
    {244 screen pixels means 122 saved bytes per row; the 100-row dialog
     fits inside the 12,288-byte popup area while keeping the full credit
     block readable in the native 3x5 UI font.}
    FillBox(38,42,281,141,1); DrawBorder(38,42,281,141,9); DrawBorder(41,45,278,138,7);
    Text8(118,48,'ABOUT PP16',15);
    SmallText(100,60,'64X64 16-COLOR SPRITE EDITOR',15);
    SmallText(90,66,'TARGET SYSTEM: TANDY 1000HX / DOS',15);
    HSpan(52,267,73,8);
    SmallText(88,78,'PP16 (C) 2026 BARTHOLOMEW HARNER',15);
    SmallText(72,84,'DESIGNED AND DEVELOPED BY BARTHOLOMEW HARNER',15);
    HSpan(52,267,91,8);
    SmallText(88,96,'WORKFLOW INSPIRATION AND REFERENCE:',14);
    SmallText(76,102,'PIXELPLUS 256 (C) 1995 CHRIS CHADWICK',15);
    SmallText(88,108,'SOMERSET, ENGLAND',15);
    HSpan(52,267,115,8);
    SmallText(76,120,'IMPLEMENTATION ASSISTANCE: OPENAI CODEX',14);
    SmallText(88,126,'AI ASSISTANT (C) 2026 OPENAI',15);
    SmallText(88,132,'INDEPENDENT; PP256 NOT PP16 SOURCE.',15); Exit;
  end;
  X:=PopupX[OpenMenu]; W:=PopupW[OpenMenu]; H:=MenuRowY(OpenMenu,MenuRows[OpenMenu])+4;
  FillBox(X,9,X+W-1,H,1); DrawBorder(X,9,X+W-1,H,9); DrawBorder(X+3,12,X+W-4,H-3,7);
  for I:=0 to MenuRows[OpenMenu]-1 do
  begin
    Y:=MenuRowY(OpenMenu,I);
    if Labels[OpenMenu,I]='' then HSpan(X+4,X+W-5,Y+2,8)
    else begin
      if Enabled(OpenMenu,I) then C:=15 else C:=8;
      Text8(X+12,Y,Labels[OpenMenu,I],C);
      S:=Shortcut(OpenMenu,I);
      if S<>'' then SmallText(X+W-7-Length(S)*4,Y+1,S,C);
      if ((OpenMenu=2) and (I=0) and GridVisible) or ((OpenMenu=1) and (I=6) and PasteBehind) then
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
    6:begin SavedX1:=52; SavedY1:=44; SavedX2:=268; SavedY2:=155 end;
    7:begin SavedX1:=38; SavedY1:=42; SavedX2:=281; SavedY2:=141 end;
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

{$ifdef PP16_CLIP_ENABLED}
procedure ClearSelection;
begin
  SelectionValid:=False; SelectionEllipse:=False;
  PasteMode:=False; PasteShown:=False;
end;

procedure SetSelection(Ax,Ay,Bx,By:Integer);
var T:Integer;
begin
  if Ax>Bx then begin T:=Ax; Ax:=Bx; Bx:=T end;
  if Ay>By then begin T:=Ay; Ay:=By; By:=T end;
  if Ax<0 then Ax:=0; if Ay<0 then Ay:=0;
  if Bx>=DocWidth then Bx:=DocWidth-1;
  if By>=DocHeight then By:=DocHeight-1;
  SelectionX:=Ax; SelectionY:=Ay;
  SelectionW:=Bx-Ax+1; SelectionH:=By-Ay+1;
  SelectionValid:=(SelectionW>0) and (SelectionH>0);
end;

procedure SetSquareSelection(Ax,Ay,Bx,By:Integer);
var DX,DY,DirX,DirY,Span,Limit:Integer;
begin
  DX:=Bx-Ax; DY:=By-Ay;
  if DX<0 then DirX:=-1 else if DX>0 then DirX:=1
  else if DY<0 then DirX:=-1 else DirX:=1;
  if DY<0 then DirY:=-1 else if DY>0 then DirY:=1
  else DirY:=DirX;
  Span:=Abs(DX); if Abs(DY)>Span then Span:=Abs(DY);
  if DirX>0 then Limit:=DocWidth-1-Ax else Limit:=Ax;
  if DirY>0 then
  begin
    if DocHeight-1-Ay<Limit then Limit:=DocHeight-1-Ay;
  end
  else if Ay<Limit then Limit:=Ay;
  if Span>Limit then Span:=Limit;
  SetSelection(Ax,Ay,Ax+DirX*Span,Ay+DirY*Span);
end;

procedure SelectionBorder(X,Y,W,H:Integer; C:Byte; Restore,Ellipse:Boolean);
var I,J,K,L,P,N,SX,SY,EX,X1,Y1,X2,Y2,DX,DY:Integer; Shade:Byte;

  procedure BorderPixel(PX,PY:Integer);
  begin
    if (PX<CanvasX) or (PY<CanvasY) or (PX>=CanvasX+CanvasSize) or (PY>=CanvasY+CanvasSize) then Exit;
    if Restore then
    begin
      Shade:=8;
        if ScreenToDoc(PX,PY,DX,DY) then
        begin
          Shade:=DocPixel(DX,DY);
          if GridVisible and (Zoom>=2) and
           (((PX-CanvasX) mod Zoom=Zoom-1) or
            ((PY-CanvasY) mod Zoom=Zoom-1)) then Shade:=8;
        end;
    end else begin
      Shade:=C;
      {The saved selection marquee is a true screen-pixel stipple, rather than
       a sequence of zoom-sized document cells.}
      if C=14 then if Odd(PX+PY) then Shade:=7 else Shade:=8;
    end;
    PutPixel(PX,PY,Shade);
  end;

begin
  if (W<1) or (H<1) then Exit;
  if Ellipse then begin
    P:=W; L:=EllipseInset(0,W,H);
    for J:=0 to H-1 do begin
      if J=H-1 then N:=W else N:=EllipseInset(J+1,W,H);
      SX:=CanvasX+(X+L-PanX)*Zoom;
      EX:=CanvasX+(X+W-L-PanX)*Zoom-1;
      SY:=CanvasY+(Y+J-PanY)*Zoom;
      if SX<=EX then for K:=0 to Zoom-1 do begin BorderPixel(SX,SY+K); BorderPixel(EX,SY+K) end;
      for I:=L to W-1-L do begin
        if (I<P) or (I>=W-P) then for K:=0 to Zoom-1 do
          BorderPixel(SX+(I-L)*Zoom+K,SY);
        if (I<N) or (I>=W-N) then for K:=0 to Zoom-1 do
          BorderPixel(SX+(I-L)*Zoom+K,SY+Zoom-1);
      end;
      P:=L; L:=N;
    end;
    Exit;
  end;
  X1:=CanvasX+(X-PanX)*Zoom;
  Y1:=CanvasY+(Y-PanY)*Zoom;
  X2:=CanvasX+(X+W-PanX)*Zoom-1;
  Y2:=CanvasY+(Y+H-PanY)*Zoom-1;
  if (X2<CanvasX) or (Y2<CanvasY) or
     (X1>=CanvasX+CanvasSize) or (Y1>=CanvasY+CanvasSize) then Exit;
  if X1<CanvasX then X1:=CanvasX; if Y1<CanvasY then Y1:=CanvasY;
  if X2>=CanvasX+CanvasSize then X2:=CanvasX+CanvasSize-1;
  if Y2>=CanvasY+CanvasSize then Y2:=CanvasY+CanvasSize-1;
  for I:=X1 to X2 do begin BorderPixel(I,Y1); BorderPixel(I,Y2) end;
  for I:=Y1+1 to Y2-1 do begin BorderPixel(X1,I); BorderPixel(X2,I) end;
end;

procedure ShowSelectionOverlay;
begin
  DrawCanvas;
  if SelectionValid then
    SelectionBorder(SelectionX,SelectionY,SelectionW,SelectionH,14,False,SelectionEllipse);
  Tools;
end;

procedure DismissSelection;
begin
  if SelectionValid then
    SelectionBorder(SelectionX,SelectionY,SelectionW,SelectionH,0,True,SelectionEllipse);
  ClearSelection;
end;

procedure ShowPasteOverlay;
begin
  SelectionBorder(PasteX,PasteY,ClipboardWidth,ClipboardHeight,14,False,ClipboardEllipse);
  PasteShown:=True;
end;

procedure MovePaste(X,Y:Integer);
begin
  if (X=PasteX) and (Y=PasteY) then Exit;
  if PasteShown then
  begin
    SelectionBorder(PasteX,PasteY,ClipboardWidth,ClipboardHeight,0,True,ClipboardEllipse);
    PasteShown:=False;
  end;
  PasteX:=X; PasteY:=Y; ShowPasteOverlay;
end;

procedure CancelPaste;
begin
  if PasteShown then
    SelectionBorder(PasteX,PasteY,ClipboardWidth,ClipboardHeight,0,True,ClipboardEllipse);
  PasteShown:=False; PasteMode:=False;
  if SelectionValid then ShowSelectionOverlay;
  Title;
end;

procedure CommitPaste(Buttons:Byte);
begin
  if PasteShown then
    SelectionBorder(PasteX,PasteY,ClipboardWidth,ClipboardHeight,0,True,ClipboardEllipse);
  PasteShown:=False;
  ClipboardPaste(PasteX,PasteY,PasteBehind,BackColor);
  PasteMode:=False;
  PointerBlocked:=Buttons<>0;
  Title;
end;

procedure CopySelection;
begin
  if SelectionValid then
  begin
    ClipboardCopy(SelectionX,SelectionY,SelectionW,SelectionH,SelectionEllipse);
    ClipboardPanel;
  end;
end;

procedure CutSelection;
begin
  if SelectionValid then
  begin
    ClipboardCut(SelectionX,SelectionY,SelectionW,SelectionH,BackColor,SelectionEllipse);
    ClipboardPanel;
  end;
end;

procedure BeginPaste;
begin
  if not ClipboardValid then Exit;
  PasteX:=PanX+(VisibleCells-ClipboardWidth) div 2;
  PasteY:=PanY+(VisibleCells-ClipboardHeight) div 2;
  PasteMouseX:=-1; PasteMouseY:=-1;
  PasteShown:=False; DrawCanvas; ShowPasteOverlay;
  PasteMode:=True;
  FillBox(0,192,319,199,1);
  SmallText(3,194,'PASTE: MOVE OR ARROWS ENTER/CLICK: PLACE ESC: CANCEL',14);
end;
{$endif}

procedure InitUI;
begin LoadToolAtlas; InitView; InitPaint; GradientArm:=0;
  ForeColor:=15; BackColor:=0;
  BrushSize:=1; StrokeSize:=1;
  StatusValid:=False; ShiftHeld:=False; CtrlHeld:=False;
  CachedTool:=-1; CachedFore:=-1; CachedBack:=-1;
  PreviewValid:=False; PopupSaved:=False; ViewedZoom:=-1;
  Gesture:=0; PointerBlocked:=False; StrokeValid:=False; ShapeValid:=False;
  ShapePreviewVisible:=False;
  PaintedDirty:=False;
  RepaintedCells:=0;
  PendingCommand:=0; ConfirmDiscard:=False;
  {$ifdef PP16_CLIP_ENABLED}ClearClipboard; ClearSelection; EllipseSelectTool:=False;{$endif} PasteBehind:=False;
  ExitRequested:=False; SelectedTool:=3; OpenMenu:=-1; HoverDX:=-1; HoverDY:=-1 end;

procedure Title;
var S:String[32]; C:Byte;
begin
  FillBox(0,192,319,199,1);
  if not MouseReady then
  begin
    SmallText(3,194,'NO MOUSE - 2/4/8 ZOOM - ARROWS PAN - ESC EXIT',14);
    Exit;
  end;
  S:=CurrentFile; if S='' then S:='UNTITLED';
  S:='PP16 ['+S+']'; C:=10;
  if DocDirty then begin S:=S+'*'; C:=14 end;
  SmallText(3,194,S,C);
end;

procedure DrawUI;
var Y,A,B:Integer;
begin
  StatusValid:=False;
  CachedTool:=-1; CachedFore:=-1; CachedBack:=-1;
  PreviewValid:=False; PopupSaved:=False;
  FillBox(0,0,319,199,0); FillBox(0,0,319,7,1);
  Text8(4,0,'File',15); Text8(56,0,'Edit',15); Text8(108,0,'View',15);
  Text8(160,0,'Action',15); Text8(284,0,'Help',15);
  Tools; Colors; DrawCanvas;
  {$ifdef PP16_CLIP_ENABLED}
  if PasteMode then ShowPasteOverlay
  else if SelectionValid then
    SelectionBorder(SelectionX,SelectionY,SelectionW,SelectionH,14,False,SelectionEllipse);
  {$endif}
  Preview; ClipboardPanel; Navigation; Status(-1,-1);
  Title;
  CapturePopup; Popup;
  for Y:=0 to 63 do TakeDirtyRow(Y,A,B);
  PaintedDirty:=DocDirty;
  ViewedZoom:=Zoom; ViewedPanX:=PanX; ViewedPanY:=PanY; ViewedGrid:=GridVisible;
end;

procedure RedrawView;
begin
  if (ViewedZoom=Zoom) and (ViewedPanX=PanX) and (ViewedPanY=PanY) and
     (ViewedGrid=GridVisible) then Exit;
  DrawCanvas;
  {$ifdef PP16_CLIP_ENABLED}
  if PasteMode then ShowPasteOverlay
  else if SelectionValid then
    SelectionBorder(SelectionX,SelectionY,SelectionW,SelectionH,14,False,SelectionEllipse);
  {$endif}
  Preview; Navigation; Status(-1,-1);
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
  if (M<0) or (M>6) then Exit;
  OpenMenu:=M; DrawUI;
end;

procedure CompleteCommand;
begin
  ClosePopup;
  if PendingCommand=1 then
  begin InitBlankDoc(0); CurrentFile:=''; InitView;
    {$ifdef PP16_CLIP_ENABLED}ClearSelection{$endif} end
  else if PendingCommand=2 then ExitRequested:=True;
  PendingCommand:=0; OpenMenu:=-1; DrawUI;
end;

procedure RequestCommand(C:Byte);
begin
  if C=3 then begin StartFileDialog(False); Exit end;
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
    if not DialogSaving and not FileIsClip then begin InitView;
      {$ifdef PP16_CLIP_ENABLED}ClearSelection{$endif} end;
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
    if (Y<8) and (Button=1) then
    begin
      I:=0; while (I<5) and (X>=MenuX[I+1]-2) do Inc(I);
      if I=4 then Exit; {Image management needs variable-size documents.}
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
                2:SaveCurrent; 3:StartFileDialog(True);
                4:begin ClosePopup; BeginImportDialog; SetPopup(9) end;
                5:RequestCommand(2);
              end;
              Exit;
            end
            else if M=1 then
            begin
              {$ifdef PP16_CLIP_ENABLED}
              case I of
                0:DocUndo;
                2:CutSelection;
                3:CopySelection;
                4:BeginPaste; 6:PasteBehind:=not PasteBehind;
              end;
              {$else}DocUndo;{$endif}
            end
            else if M=3 then
            begin if I=0 then DocClear(0) else DocClear(ForeColor) end
            else if M=2 then begin GridVisible:=not GridVisible; RedrawView end
            else if M=5 then begin if I=0 then SetPopup(6) else SetPopup(7); Exit end;
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
    if I=4 then Exit; {No fixed-64x64 Image menu in M9.}
    SetPopup(I); Exit;
  end;
  if (X>=0) and (X<=78) and (Y>=70) and (Y<=78) then
  begin
    if Button=1 then
    begin
      if (X>=2) and (X<=10) then ChangeBrushSize(-1)
      else if (X>=68) and (X<=76) then ChangeBrushSize(1);
    end;
    Exit;
  end;
  if (X>=2) and (X<78) and (Y>=PaletteY) and (Y<PaletteY+4*PaletteStep) then
  begin
    if ((X-2) mod 19>=18) or ((Y-PaletteY) mod PaletteStep>=PaletteHeight) then Exit;
    I:=((Y-PaletteY) div PaletteStep)*4+(X-2) div 19;
    if Button=1 then
      if GradientArm<>0 then
      begin
        if GradientArm=1 then SetGradient(I,GradientLast,GradientStep)
        else SetGradient(GradientFirst,I,GradientStep);
        GradientArm:=0; ForeColor:=GradientPaint; CachedFore:=-1;
      end else ForeColor:=I
    else if Button=2 then BackColor:=I;
    Colors; Exit;
  end;
  if (Button=1) and (Y>=GradientY) and (Y<GradientY+GradientHeight) then
  begin
    if (X>=GradientAX) and (X<GradientAX+GradientBoxWidth) then GradientArm:=1
    else if (X>=GradientBX) and (X<GradientBX+GradientBoxWidth) then GradientArm:=2
    else if (X>=GradientRampX) and (X<GradientRampX+GradientRampWidth) then
    begin
      SetGradient(GradientFirst,GradientLast,RampStep(X));
      ForeColor:=GradientPaint; GradientArm:=0;
    end else Exit;
    CachedFore:=-1; Colors; Exit;
  end;
  {Any other control ends endpoint assignment without consuming its action.}
  if GradientArm<>0 then begin GradientArm:=0; CachedFore:=-1; Colors end;
  {$ifdef PP16_CLIP_ENABLED}
  if (Button=2) and (X>=2) and (X<20) and (Y>=18) and (Y<36) then
  begin
    EllipseSelectTool:=not EllipseSelectTool; SelectedTool:=0;
    CachedTool:=-1; Tools; Exit;
  end;
  if (Button=1) and (X>=ClipClearButtonX) and
     (X<ClipClearButtonX+ClipClearButtonWidth) and
     (Y>=ClipClearButtonY) and (Y<ClipClearButtonY+ClipClearButtonHeight) then
  begin
    ClearClipboard; ClipboardPanel; Exit;
  end;
  if (Button in [1,2]) and
     (X>=ClipTransformButtonX) and (X<ClipTransformButtonX+ClipTransformButtonSize) then
  begin
    if (Y>=ClipScaleButtonY) and (Y<ClipScaleButtonY+ClipTransformButtonSize) then
    begin
      if ClipboardValid then begin ClipboardScale(Button=1); ClipboardPanel end;
      Exit
    end;
    if Button=1 then
    begin
      if (Y>=ClipMirrorButtonY) and (Y<ClipMirrorButtonY+ClipTransformButtonSize) then
      begin if ClipboardValid then begin ClipboardMirror; ClipboardPanel end; Exit end;
      if (Y>=ClipRotateButtonY) and (Y<ClipRotateButtonY+ClipTransformButtonSize) then
      begin if ClipboardValid then begin ClipboardRotateClockwise; ClipboardPanel end; Exit end;
    end;
  end;
  {$endif}
  if Button<>1 then Exit;
  if (X>=12) and (X<=48) and (Y>=99) and (Y<=113) then
  begin SwapColors; Exit end;
  {$ifdef PP16_CLIP_ENABLED}
  if (Button=1) and (X>=218) and (X<=318) and (Y>=101) and (Y<=190) then
  begin BeginPaste; Exit end;
  {$endif}
  if (X>=2) and (X<78) and (Y>=18) and (Y<56) then
  begin
    if ((X-2) mod 19>=18) or ((Y-18) mod 19>=18) then Exit;
    I:=((Y-18) div 19)*4+(X-2) div 19;
    if I=1 then
    begin
      {$ifdef PP16_CLIP_ENABLED}if Button=1 then BeginPaste;{$endif}
      Exit;
    end;
    {$ifdef PP16_CLIP_ENABLED}
    if I=4 then begin CutSelection; Exit end;
    {$endif}
    {$ifdef PP16_CLIP_ENABLED}
    if (SelectedTool=0) and (I<>0) then DismissSelection;
    {$endif}
    SelectedTool:=I; Tools; Exit;
  end;
  if ControlHit(X,Y,ZoomButtonX,ZoomButtonWidth,ZoomButtonHeight,ZoomButtonStep,3,I) then
  begin SetZoom(2 shl I); RedrawView end;
end;

procedure PaintChanges;
var X,Y,A,B,SX,SY,J,PX1,PY1,PX2,PY2:Integer; C:Byte;
    OverlayChanged:Boolean;
begin
  if OpenMenu>=0 then Exit;
  if DocAllDirty then
  begin
    {DocUndo and DocCancelAction use MarkAll. Rebuild those complete images
     with packed scanline writes; ordinary strokes still take the cheaper
     dirty-cell path below.}
    DrawCanvas;
    if PreviewValid then PaintPreviewRows;
    Preview;
    for Y:=0 to 63 do TakeDirtyRow(Y,A,B);
    for Y:=PanY to PanY+VisibleCells-1 do
      for X:=PanX to PanX+VisibleCells-1 do
        if RepaintedCells<65535 then Inc(RepaintedCells);
    {$ifdef PP16_CLIP_ENABLED}
    if PasteMode then ShowPasteOverlay
    else if SelectionValid then
      SelectionBorder(SelectionX,SelectionY,SelectionW,SelectionH,14,False,SelectionEllipse);
    {$endif}
    if DocDirty<>PaintedDirty then
    begin
      Title;
      PaintedDirty:=DocDirty;
    end;
    Exit;
  end;
  OverlayChanged:=False;
  PX1:=PanX-1; PY1:=PanY-1; PX2:=PanX+VisibleCells; PY2:=PanY+VisibleCells;
  if PX2>64 then PX2:=64; if PY2>64 then PY2:=64;
  for Y:=0 to 63 do if TakeDirtyRow(Y,A,B) then
    for X:=A to B do
    begin
      C:=DocPixel(X,Y);
      if (X>=PanX) and (X<PanX+VisibleCells) and
         (Y>=PanY) and (Y<PanY+VisibleCells) then
      begin
        SX:=CanvasX+(X-PanX)*Zoom;
        SY:=CanvasY+(Y-PanY)*Zoom;
        FillBox(SX,SY,SX+Zoom-1,SY+Zoom-1,C);
        if GridVisible and (Zoom>=2) then
        begin
          HSpan(SX,SX+Zoom-1,SY+Zoom-1,8);
          for J:=SY to SY+Zoom-2 do PutPixel(SX+Zoom-1,J,8);
        end;
        {A diagnostic counter, not a lifetime total. Saturate rather than wrap.}
        if RepaintedCells<65535 then Inc(RepaintedCells);
        OverlayChanged:=True;
      end;
      if (((X=PX1) or (X=PX2)) and (Y>=PY1) and (Y<=PY2)) or
         (((Y=PY1) or (Y=PY2)) and (X>=PX1) and (X<=PX2)) then C:=8;
      PutPixel(ImagePreviewX+X,ImagePreviewY+Y,C);
    end;
  {$ifdef PP16_CLIP_ENABLED}
  if OverlayChanged then
    if PasteMode then ShowPasteOverlay
    else if SelectionValid then
      SelectionBorder(SelectionX,SelectionY,SelectionW,SelectionH,14,False,SelectionEllipse);
  {$endif}
  if DocDirty<>PaintedDirty then
  begin
    Title;
    PaintedDirty:=DocDirty;
  end;
end;

procedure PreviewShapePixel(X,Y:Integer; C:Integer);
var SX,SY,J:Integer;
begin
  {The live outline is a canvas-only overlay. It never enters the document or
   the 1:1 image preview, so release remains the one commit point.}
  if (X<PanX) or (X>=PanX+VisibleCells) or
     (Y<PanY) or (Y>=PanY+VisibleCells) then Exit;
  if C<0 then C:=DocPixel(X,Y) else C:=PaintColor(X,Y,C);
  SX:=CanvasX+(X-PanX)*Zoom;
  SY:=CanvasY+(Y-PanY)*Zoom;
  FillBox(SX,SY,SX+Zoom-1,SY+Zoom-1,C);
  if GridVisible and (Zoom>=2) then
  begin
    HSpan(SX,SX+Zoom-1,SY+Zoom-1,8);
    for J:=SY to SY+Zoom-2 do PutPixel(SX+Zoom-1,J,8);
  end;
end;

procedure PreviewShapeStamp(X,Y:Integer; C:Integer);
begin
  RasterStamp(X,Y,C,StrokeSize,PreviewShapePixel);
end;

procedure DrawShapeOutline(X,Y:Integer; C:Integer);
begin
  case ShapeTool of
    5:RasterCircle(StrokeX,StrokeY,X,Y,C,PreviewShapeStamp);
    6:RasterSquare(StrokeX,StrokeY,X,Y,C,PreviewShapeStamp);
    7:RasterLine(StrokeX,StrokeY,X,Y,C,PreviewShapeStamp);
  end;
end;

procedure ShowShapePreview;
begin
  if not ShapeValid then Exit;
  {Restore only the cells of the prior temporary outline, including grid
   borders, then paint the new outline. This avoids a full 128x128 rebuild
   for every pointer movement.}
  if ShapePreviewVisible then
    DrawShapeOutline(ShapePreviewX,ShapePreviewY,-1);
  DrawShapeOutline(ShapeX,ShapeY,StrokeColor);
  ShapePreviewX:=ShapeX; ShapePreviewY:=ShapeY; ShapePreviewVisible:=True;
end;

procedure EndGesture(Buttons:Byte);
begin
  if Gesture=4 then
    if ShapeValid then
      case ShapeTool of
        5:DocCircle(StrokeX,StrokeY,ShapeX,ShapeY,StrokeColor,StrokeSize);
        6:DocSquare(StrokeX,StrokeY,ShapeX,ShapeY,StrokeColor,StrokeSize);
        7:DocLine(StrokeX,StrokeY,ShapeX,ShapeY,StrokeColor,StrokeSize);
      end;
  if Gesture in [1,4] then DocCommitAction;
  Gesture:=0; StrokeValid:=False; ShapeValid:=False; ShapePreviewVisible:=False;
  PointerBlocked:=Buttons<>0;
end;

procedure CancelGesture(Buttons:Byte);
var WasShape{$ifdef PP16_CLIP_ENABLED},WasOverlay{$endif}:Boolean;
begin
  WasShape:=Gesture=4;
  {$ifdef PP16_CLIP_ENABLED}WasOverlay:=Gesture=5;{$endif}
  if Gesture in [1,4] then DocCancelAction;
  if WasShape and ShapePreviewVisible then
    DrawShapeOutline(ShapePreviewX,ShapePreviewY,-1);
  Gesture:=0; StrokeValid:=False; ShapeValid:=False; ShapePreviewVisible:=False;
  PointerBlocked:=Buttons<>0;
  {$ifdef PP16_CLIP_ENABLED}
  if WasOverlay then ShowSelectionOverlay;
  {$endif}
end;

procedure ApplyGesture(X,Y:Integer);
var DX,DY:Integer; C:Byte;
begin
  if Gesture=3 then begin
    if X<ImagePreviewX then X:=ImagePreviewX;
    if X>=ImagePreviewX+64 then X:=ImagePreviewX+63;
    if Y<ImagePreviewY then Y:=ImagePreviewY;
    if Y>=ImagePreviewY+64 then Y:=ImagePreviewY+63;
    PanView(X-ImagePreviewX-VisibleCells div 2-PanX,
            Y-ImagePreviewY-VisibleCells div 2-PanY);
    RedrawView; Exit;
  end;
  if not ScreenToDoc(X,Y,DX,DY) then begin StrokeValid:=False; Exit end;
  if Gesture=2 then
  begin
    C:=DocPixel(DX,DY);
    if GradientArm<>0 then begin GradientArm:=0; CachedFore:=-1 end;
    if ForeColor<>C then begin ForeColor:=C; Colors end;
    Exit;
  end;
  if Gesture=4 then
  begin
    ShapeValid:=True; ShapeX:=DX; ShapeY:=DY;
    ShowShapePreview;
    Exit;
  end;
  {$ifdef PP16_CLIP_ENABLED}
  if Gesture=5 then
  begin
    if CtrlHeld then
      SetSquareSelection(SelectionAnchorX,SelectionAnchorY,DX,DY)
    else SetSelection(SelectionAnchorX,SelectionAnchorY,DX,DY);
    ShowSelectionOverlay;
    Exit;
  end;
  {$endif}
  if StrokeValid then DocLine(StrokeX,StrokeY,DX,DY,StrokeColor,StrokeSize)
  else DocBrush(DX,DY,StrokeColor,StrokeSize);
  StrokeX:=DX; StrokeY:=DY; StrokeValid:=True;
end;

procedure PointerInput(const S:TMouseState);
var DX,DY:Integer; Owner:Byte;
begin
  {$ifdef PP16_CLIP_ENABLED}
  if PasteMode then
  begin
    if (S.X<>PasteMouseX) or (S.Y<>PasteMouseY) then
    begin
      PasteMouseX:=S.X; PasteMouseY:=S.Y;
      if ScreenToDoc(S.X,S.Y,DX,DY) then
        MovePaste(DX-ClipboardWidth div 2,DY-ClipboardHeight div 2);
    end;
    if (S.Pressed and 1)<>0 then CommitPaste(S.Buttons);
    Exit;
  end;
  {$endif}
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
     (S.X>=ImagePreviewX) and (S.X<ImagePreviewX+64) and
     (S.Y>=ImagePreviewY) and (S.Y<ImagePreviewY+64) then
  begin Gesture:=3; ApplyGesture(S.X,S.Y); Exit end;
  if (OpenMenu<0) and ScreenToDoc(S.X,S.Y,DX,DY) then
  begin
    if GradientArm<>0 then begin GradientArm:=0; CachedFore:=-1; Colors end;
    if (S.Pressed and 2)<>0 then Gesture:=2
    {$ifdef PP16_CLIP_ENABLED}
    else if SelectedTool=0 then
    begin
      Gesture:=5; SelectionAnchorX:=DX; SelectionAnchorY:=DY;
      SelectionEllipse:=EllipseSelectTool;
      SetSelection(DX,DY,DX,DY);
    end
    {$endif}
    else if SelectedTool=2 then
    begin
      DocFloodFill(DX,DY,ForeColor);
    end
    else if SelectedTool=3 then
    begin
      Gesture:=1; DocBeginAction;
      StrokeColor:=ForeColor;
      StrokeSize:=BrushSize;
    end
    else if SelectedTool in [5,6,7] then
    begin
      Gesture:=4; ShapeTool:=SelectedTool; StrokeColor:=ForeColor;
      StrokeSize:=BrushSize;
      StrokeX:=DX; StrokeY:=DY; ShapeX:=DX; ShapeY:=DY; ShapeValid:=True;
      ShapePreviewVisible:=False;
      DocBeginAction;
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
begin
  if Gesture<>0 then
  begin
    if Key=27 then CancelGesture(Buttons);
    Exit;
  end;
  {$ifdef PP16_CLIP_ENABLED}
  if PasteMode then
  begin
    if Key=27 then CancelPaste
    else if PasteMode then
      if Key=13 then CommitPaste(Buttons)
      else case Scan of
        72:MovePaste(PasteX,PasteY-1);
        80:MovePaste(PasteX,PasteY+1);
        75:MovePaste(PasteX-1,PasteY);
        77:MovePaste(PasteX+1,PasteY);
      end;
    Exit;
  end;
  {$endif}
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
    if OpenMenu>=0 then ClosePopup
    else if GradientArm<>0 then begin GradientArm:=0; CachedFore:=-1; Colors end
    else if not MouseReady then RequestCommand(2);
    PointerBlocked:=Buttons<>0; Exit;
  end;
  if PointerBlocked or (Buttons<>0) then Exit;
  if Scan=59 then SetPopup(6)
  else if OpenMenu<0 then
  begin
    if CtrlHeld and (Scan=44) then DocUndo {Physical Ctrl+Z}
    else case Key of
      26:DocUndo; {BIOS ASCII Ctrl+Z}
      {$ifdef PP16_CLIP_ENABLED}
      3:CopySelection; {Ctrl+C}
      {$endif}
      50,52,56:begin SetZoom(Key-48); RedrawView end;
      9:SwapColors;
      {$ifdef PP16_CLIP_ENABLED}
      22:BeginPaste; {Ctrl+V}
      24:CutSelection; {Ctrl+X}
      {$endif}
    end;
    case Scan of
      46:if Key=0 then DocClear(0); {Alt+C}
      62:begin GridVisible:=not GridVisible; RedrawView end;
      72:PanCommand(2,ShiftHeld);
      80:PanCommand(3,ShiftHeld);
      75:PanCommand(0,ShiftHeld);
      77:PanCommand(1,ShiftHeld);
    end;
  end;
end;

procedure RunUI;
var S,Old:TMouseState; R:Registers; Key,Scan:Byte; DX,DY:Integer;
    Quit,Changed,MotionOnly,DeferHide,NewShift,NewCtrl:Boolean;
begin
  FillChar(S,SizeOf(S),0); S.X:=160; S.Y:=100;
  if MouseReady then PollMouse(S);
  Old:=S; Quit:=False; PointerBlocked:=S.Buttons<>0;
  Title;
  if MouseReady then ShowCursor(S.X,S.Y);
  repeat
    Key:=0; Scan:=0; FillChar(R,SizeOf(R),0); R.AH:=1; Intr($16,R);
    if (R.Flags and $40)=0 then begin R.AH:=0; Intr($16,R); Key:=R.AL; Scan:=R.AH end;
    if MouseReady then PollMouse(S);
    NewShift:=(Mem[$40:$17] and 3)<>0;
    NewCtrl:=(Mem[$40:$17] and 4)<>0;
    Changed:=(S.X<>Old.X) or (S.Y<>Old.Y) or (S.Buttons<>Old.Buttons) or
      (Scan<>0) or (NewShift<>ShiftHeld) or (NewCtrl<>CtrlHeld);
    if Changed then
    begin
      ShiftHeld:=NewShift; CtrlHeld:=NewCtrl;
      MotionOnly:=(Scan=0) and (S.Buttons=Old.Buttons) and (Gesture=0)
        {$ifdef PP16_CLIP_ENABLED}and not PasteMode{$endif};
      if MotionOnly and MouseReady then PointerFeedback(S.X,S.Y)
      else begin
        {Keep the pointer visible during offscreen canvas construction.}
        DeferHide:=(OpenMenu<0) and
          (((Gesture=0) and (S.Buttons=0) and
            ((Key in [50,52,56]) or (Scan in [62,72,75,77,80]))) or
           (Gesture=3) or ((Scan=0) and (Gesture=0) and
            (InZoomControl(S.X,S.Y) or
             ((S.X>=ImagePreviewX) and (S.X<ImagePreviewX+64) and
              (S.Y>=ImagePreviewY) and (S.Y<ImagePreviewY+64)))));
        if not DeferHide then HideCursor;
        KeyInput(Key,Scan,S.Buttons);
        if not ExitRequested then PointerInput(S);
        PaintChanges;
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

  procedure CheckPreviewFrames;
  begin
    if (GetPixel(ImagePreviewX-1,46)<>7) or (GetPixel(ImagePreviewX+31,28)<>7) or
       (GetPixel(ImagePreviewX+64,46)<>7) or (GetPixel(ImagePreviewX+31,94)<>7) or
       (GetPixel(ClipPreviewX-1,130)<>7) or (GetPixel(ClipPreviewX+31,112)<>7) or
       (GetPixel(ClipPreviewX+64,130)<>7) or (GetPixel(ClipPreviewX+31,178)<>7) then Inc(F);
  end;

begin
  F:=0; Before:=DocChecksum; Z:=2;
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
          if (not OK) or (DX<>PanX+X div Z) or
             (DY<>PanY+Y div Z) then Inc(F);
          C:=DocPixel(PanX+X div Z,PanY+Y div Z);
          if GridVisible and (Z>=2) and
             ((X mod Z=Z-1) or (Y mod Z=Z-1)) then C:=8;
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
  HandleClick(62,PaletteY+3*PaletteStep+2,2); if BackColor<>15 then Inc(F);
  HandleClick(ZoomButtonX+2,NavigationY+2,1); if Zoom<>2 then Inc(F);
  HandleClick(ZoomButtonX+2*ZoomButtonStep+2,NavigationY+2,1); if Zoom<>8 then Inc(F);
  HandleClick(5,3,1); HandleClick(ZoomButtonX+2,NavigationY+2,1); if Zoom<>8 then Inc(F);
  HandleClick(5,21,1); if SelectedTool<>0 then Inc(F);
  if (Shortcut(1,2)<>'Ctrl+X') or (Shortcut(1,3)<>'Ctrl+C') or
     (Shortcut(1,4)<>'Ctrl+V') then Inc(F);
  HandleClick(125,110,1); HandleClick(125,110,2);
  {The former Utilities tile is now a non-selecting clipboard action.}
  HandleClick(24,21,1); if SelectedTool<>0 then Inc(F);
  if DocChecksum<>Before then Inc(F);
  InitUI; DrawUI;
  for I:=0 to 2 do
  begin
    SetZoom(2 shl I);
    RedrawView; CheckPreviewFrames;
    if I=0 then for Y:=0 to 63 do for X:=0 to 63 do
      if GetPixel(ImagePreviewX+X,ImagePreviewY+Y)<>DocPixel(X,Y) then Inc(F);
    if (Zoom<4) and PreviewValid then Inc(F);
    if (Zoom>=4) and not PreviewValid then Inc(F);
  end;
  ViewChecks:=F;
end;
{$endif}

{$ifdef PP16_CLIP_TEST}
function ClipChecks:Word;
var F:Word; S:TMouseState; Before:DWord; I:Integer;
const ClipFile='UI.CLP';

  procedure Check(OK:Boolean; const Name:String);
  begin if not OK then begin Inc(F); WriteLn('FAIL: ',Name) end end;

  procedure Feed(SX,SY:Integer; Buttons:Byte);
  begin S.X:=SX; S.Y:=SY; UpdateButtons(Buttons,S); PointerInput(S) end;

  procedure AtDoc(DX,DY:Integer; Buttons:Byte);
  begin Feed(CanvasX+(DX-PanX)*Zoom,
             CanvasY+(DY-PanY)*Zoom,Buttons) end;

begin
  F:=0; InitUI; InitBlankDoc(0); SetZoom(2); PanView(-64,-64); DrawUI;
  FillChar(S,SizeOf(S),0); SelectedTool:=0; DocSetPixel(2,3,5);
  DocSaved; Before:=DocChecksum;

  HandleClick(5,21,2); CtrlHeld:=True; AtDoc(4,5,1); AtDoc(7,9,1); AtDoc(7,9,0); CtrlHeld:=False;
  Check(SelectionEllipse and SelectionValid and (SelectionX=4) and (SelectionY=5) and
        (SelectionW=5) and (SelectionH=5),'right-click Select enables Ctrl-constrained circle selection');
  AtDoc(2,3,1); AtDoc(2,3,0); KeyInput(3,0,0);
  Check(ClipboardValid and (ClipboardPixel(0,0)=5) and (DocChecksum=Before),
        'copy is document-neutral');
  HandleClick(5,40,1);
  Check((SelectedTool=0) and ClipboardValid and (ClipboardPixel(0,0)=5) and
        (DocPixel(2,3)=BackColor) and DocCanUndo,
        'toolbar Cut copies and clears without changing tools');
  DocUndo;
  Check(DocChecksum=Before,'toolbar Cut is one undoable action');
  HandleClick(62,21,1);
  Check((SelectedTool=3) and not SelectionValid and
        (GetPixel(CanvasX+10,CanvasY+10)=0),
        'choosing another tool clears the selection marquee');

  KeyInput(22,0,0); KeyInput(0,77,0); AtDoc(63,63,0);
  Check(PasteMode and (PasteX=63) and (PasteY=63) and (DocChecksum=Before),
        'floating paste follows arrows and mouse');
  AtDoc(63,63,1); Check(DocPixel(63,63)=5,'click commits paste');
  DocUndo; KeyInput(22,0,0); KeyInput(27,1,0);
  Check((DocChecksum=Before) and not PasteMode,'Escape cancels floating paste');

  HandleClick(ClipTransformButtonX+8,ClipScaleButtonY+8,1);
  Check((ClipboardWidth=2) and (ClipboardHeight=2) and
        (ClipboardPixel(0,0)=5),'left-click Scale enlarges clipboard');
  HandleClick(ClipTransformButtonX+8,ClipScaleButtonY+8,2);
  Check((ClipboardWidth=1) and (ClipboardHeight=1) and
        (ClipboardPixel(0,0)=5),'right-click Scale shrinks clipboard');
  CurrentFile:='CANVAS.P16'; DocBeginAction; DocSetPixel(0,0,9); DocCommitAction;
  Before:=DocChecksum; SetZoom(4); PanView(-64,-64); PanView(2,3); ClearSelection;
  StartFileDialog(True);
  for I:=1 to Length(ClipFile) do KeyInput(Ord(ClipFile[I]),0,0);
  KeyInput(13,0,0);
  Check((OpenMenu=-1) and DocDirty and DocCanUndo and
        (CurrentFile='CANVAS.P16'),'Save As CLP preserves document state');
  ClearClipboard; StartFileDialog(False);
  for I:=1 to Length(ClipFile) do KeyInput(Ord(ClipFile[I]),0,0);
  KeyInput(13,0,0);
  Check((OpenMenu=-1) and ClipboardValid and ClipboardEllipse and
        (ClipboardPixel(0,0)=5) and (DocChecksum=Before) and DocDirty and
        DocCanUndo and (Zoom=4) and (PanX=2) and (PanY=3) and
        (CurrentFile='CANVAS.P16'),'Open CLP preserves image, undo and view');
  KeyInput(22,0,0); KeyInput(13,0,0);
  Check(DocChecksum<>Before,'loaded clip pastes into existing image');
  DocUndo; Check(DocChecksum=Before,'loaded clip paste can be undone');
  HandleClick(ClipClearButtonX+8,ClipClearButtonY+4,1);
  Check(not ClipboardValid and (ClipboardWidth=0) and (ClipboardHeight=0) and
        (DocChecksum=Before),
        'clipboard clear button discards only the clipboard');
  ClipChecks:=F;
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
  begin Feed(CanvasX+(DX-PanX)*Zoom,
             CanvasY+(DY-PanY)*Zoom,Buttons) end;

  procedure ResetTest;
  begin
    InitUI; InitBlankDoc(0); SetZoom(2); PanView(-64,-64);
    FillChar(S,SizeOf(S),0); SelectedTool:=3; ForeColor:=15; BackColor:=0;
  end;

begin
  F:=0; ResetTest;
  Check(BrushSize=1,'default brush size');
  HandleClick(72,74,1); Check(BrushSize=2,'size selector increments');
  for I:=1 to 4 do HandleClick(72,74,1);
  Check(BrushSize=5,'size selector caps at five');
  HandleClick(6,74,1); Check(BrushSize=4,'size selector decrements');
  SelectedTool:=2; Tools; HandleClick(72,74,1);
  Check(BrushSize=4,'size selector ignores unsupported tool');
  ResetTest;
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
  ResetTest; BrushSize:=3;
  AtDoc(10,10,1); BrushSize:=5; AtDoc(10,10,0);
  for Y:=9 to 11 do for X:=9 to 11 do
    Check(DocPixel(X,Y)=15,'three-pixel brush stamp');
  Check(DocPixel(12,10)=0,'brush size freezes at press');
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
  ResetTest; BrushSize:=3; SelectedTool:=7;
  AtDoc(10,10,1); AtDoc(15,10,1);
  Check((DocChecksum=0) and
        (GetPixel(CanvasX+(15-PanX)*Zoom,
                  CanvasY+(9-PanY)*Zoom)=15),
        'thick line preview is canvas-only');
  AtDoc(15,10,0);
  Check((DocPixel(9,9)=15) and (DocPixel(16,11)=15) and
        (DocPixel(12,10)=15),'three-pixel line outline');
  ResetTest; BrushSize:=3; SelectedTool:=6;
  AtDoc(10,10,1); AtDoc(15,14,0);
  Check((DocPixel(12,9)=15) and (DocPixel(9,12)=15) and
        (DocPixel(12,12)=0),'three-pixel square outline');
  ResetTest; BrushSize:=3; SelectedTool:=5;
  AtDoc(32,32,1); AtDoc(36,34,0);
  Check((DocPixel(37,32)=15) and (DocPixel(32,27)=15),
        'three-pixel circle outline');
  ResetTest;
  SelectedTool:=7; AtDoc(2,2,1); AtDoc(8,5,1);
  Check((DocChecksum=0) and (GetPixel(CanvasX+16,CanvasY+10)=15) and
        (GetPixel(ImagePreviewX+8,ImagePreviewY+5)=0),'shape preview is canvas-only before release');
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
  Z:=2;
  repeat
    ResetTest; SetZoom(Z); PanView(-64,-64);
    AtDoc(0,0,1); AtDoc(0,0,0);
    PanView(64,64); AtDoc(63,63,1); AtDoc(63,63,0);
    Check((DocPixel(0,0)=15) and (DocPixel(63,63)=15),'draw corners at every zoom');
    Z:=Z*2;
  until Z>8;
  ResetTest; DrawUI; RepaintedCells:=0;
  DocSetPixel(10,10,12); PaintChanges;
  Check((GetPixel(CanvasX+20,CanvasY+20)=12) and
        (GetPixel(ImagePreviewX+10,ImagePreviewY+10)=12),'live canvas and preview');
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
        RequestCommand(2); KeyInput(9,15,0); KeyInput(9,15,0); KeyInput(13,28,0);
      end;
    5:begin HandleClick(24,PaletteY+PaletteStep+2,1);
        HandleClick(43,PaletteY+2*PaletteStep+2,2); KeyInput(9,15,0) end;
    6:begin
        HandleClick(5,21,1); HandleClick(45,40,1);
        HandleClick(65,40,1); HandleClick(65,21,1);
      end;
    7:begin
        HandleClick(142,164,1); KeyInput(0,77,0); KeyInput(0,80,0);
        HandleClick(125,164,1);
      end;
    8:HandleClick(4,3,1);
    9:RequestCommand(2);
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
    FillBox(84,175,213,187,1);
    SmallText(88,176,'GRID X:',15); SmallText(124,176,' Y:',15);
    SmallText(88,182,'IMAGE X:',15); SmallText(128,182,' Y:',15);
    SmallCharOpaque(116,176,Value[1],15,1); SmallCharOpaque(120,176,Value[2],15,1);
    SmallCharOpaque(136,176,Value[1],15,1); SmallCharOpaque(140,176,Value[2],15,1);
    SmallCharOpaque(120,182,Value[1],15,1); SmallCharOpaque(124,182,Value[2],15,1);
    SmallCharOpaque(140,182,Value[1],15,1); SmallCharOpaque(144,182,Value[2],15,1);
    A:=0;
    for Y:=174 to 187 do for X:=42 to 106 do begin
      Check(Mem[VideoSeg:PixelOffset(0,Y)+X]=SavedPopup[A],'opaque coordinate update');
      Inc(A);
    end;
  end;

begin
  F:=0; HideCursor; InitUI; DrawUI; Before:=DocChecksum;
  KeyInput(0,59,0); Check((OpenMenu=6) and PopupSaved,'F1 opens Quick Help');
  KeyInput(27,1,0);
  HandleClick(MenuX[5],3,1);
  HandleClick(PopupX[5]+14,MenuRowY(5,1)+1,1);
  Check((OpenMenu=7) and PopupSaved and (SavedX1=38) and (SavedY1=42) and
        (SavedX2=281) and (SavedY2=141),'Help About opens full credit window');
  HandleClick(0,190,1); Check(OpenMenu=-1,'About closes on click');
  HandleClick(MenuX[5],3,1);
  HandleClick(PopupX[5]+14,MenuRowY(5,1)+1,1);
  KeyInput(27,1,0); Check(OpenMenu=-1,'About closes');
  ShiftHeld:=True; KeyInput(0,77,0);
  Check(PanX=32,'Shift right moves half view');
  ShiftHeld:=False; KeyInput(0,75,0);
  Check(PanX=31,'plain arrow moves one pixel');
  SetZoom(8); PanView(-64,-64); RedrawView;
  FillChar(S,SizeOf(S),0);
  Feed(ImagePreviewX+32,ImagePreviewY+32,1);
  Check((PanX=24) and (PanY=24),'preview centers viewport');
  Feed(ImagePreviewX+63,ImagePreviewY+63,1);
  Check((PanX=48) and (PanY=48),'preview drag clamps bottom right');
  Feed(0,0,1); Check((PanX=0) and (PanY=0),'preview drag clamps top left');
  KeyInput(27,1,1); Feed(ImagePreviewX+63,ImagePreviewY+63,1);
  Feed(ImagePreviewX+63,ImagePreviewY+63,0);
  Check((Gesture=0) and (PanX=0) and (PanY=0),'cancel consumes held preview drag');
  Feed(ImagePreviewX+63,ImagePreviewY+63,1);
  Feed(ImagePreviewX+32,ImagePreviewY+32,0);
  Check((Gesture=0) and (PanX=24) and (PanY=24),'preview includes release position');
  Check((DocChecksum=Before) and not DocDirty and not DocCanUndo,'navigation leaves document intact');
  {Use an independent transparent-text redraw as the numeric-field oracle.}
  SetZoom(4); PanView(-64,-64); RedrawView;
  CheckStatus(9,'9 '); CheckStatus(10,'10'); CheckStatus(9,'9 '); CheckStatus(-1,'--');
  {Keep a final coordinate/cursor fixture for host inspection.}
  PointerFeedback(CanvasX+40,CanvasY+40);
  WriteLn('Response: keyboard pan, preview drag, coordinate transitions checked');
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

  procedure Choose(M,N:Integer);
  begin
    HandleClick(MenuX[M],3,1);
    HandleClick(PopupX[M]+14,MenuRowY(M,N)+1,1);
  end;

begin
  F:=0; InitUI; DrawUI; Before:=DocChecksum;
  KeyInput(19,31,0); KeyInput(15,24,0);
  Check(OpenMenu=-1,'removed Save/Open shortcuts do nothing');
  Choose(0,2); Check(OpenMenu=9,'Save of unnamed image opens dialog');
  HandleClick(210,155,1); Check(DocChecksum=Before,'file dialog blocks canvas');
  TypeName('UITEST'); KeyInput(13,28,0);
  Check((OpenMenu=-1) and (CurrentFile='UITEST.P16') and not DocDirty,'Save adds extension');
  DocBeginAction; DocSetPixel(0,0,12); DocCommitAction; PaintChanges;
  Choose(0,2); Check((OpenMenu=-1) and not DocDirty and DocCanUndo,'Save keeps undo');
  Choose(1,0); PaintChanges;
  Check(DocDirty and (DocChecksum=Before),'undo after Save marks restored image dirty');
  Choose(0,3); Check(OpenMenu=9,'File Save As opens dialog');
  KeyInput(13,28,0); KeyInput(13,28,0);
  Check((OpenMenu=9) and DocDirty,'overwrite defaults to Cancel');
  KeyInput(27,1,0); Check((OpenMenu=-1) and DocDirty,'cancel Save As preserves image');
  Choose(0,1); Check(OpenMenu=9,'dirty Open first opens file chooser');
  KeyInput(13,28,0); KeyInput(13,28,0);
  Check((OpenMenu=9) and DocDirty,'default Enter cancels discard confirmation');
  KeyInput(27,1,0); Check((OpenMenu=-1) and DocDirty,'cancel chooser preserves image');
  Choose(0,1); TypeName('MISSING'); KeyInput(13,28,0);
  KeyInput(9,15,0); KeyInput(13,28,0);
  Check((OpenMenu=9) and DocDirty and (DocChecksum=Before),'failed Open preserves image');
  TypeName('UITEST'); KeyInput(13,28,0); KeyInput(9,15,0); KeyInput(13,28,0);
  Check((OpenMenu=-1) and not DocDirty and not DocCanUndo and
        (DocPixel(0,0)=12) and (CurrentFile='UITEST.P16'),'Open replaces pixels and resets undo');
  StartFileDialog(True); TypeName('UICOPY'); KeyInput(13,28,0);
  Check(CurrentFile='UICOPY.P16','Save As changes filename');
  HandleClick(4,3,1); HandleClick(16,16,1);
  Check((CurrentFile='') and not DocDirty,'New clears filename');
  Choose(0,1); KeyInput(9,15,0); KeyInput(0,79,0); KeyInput(13,28,0);
  Check((OpenMenu=-1) and (CurrentFile<>'') and not DocDirty,'keyboard file list opens a file');
  StartFileDialog(False); HandleClick(76,72,1); HandleClick(110,130,1);
  Check((OpenMenu=-1) and (CurrentFile=ToolAtlasName),'mouse file list and OK');
  StartFileDialog(True); KeyInput(13,28,0); KeyInput(9,15,0); KeyInput(13,28,0);
  Check((OpenMenu=-1) and not DocDirty,'explicit overwrite confirms');
  StartFileDialog(False);
  WriteLn('M6: Save/Open dialogs, overwrite, dirty protection and saved undo checked');
  FileUIChecks:=F;
end;

{$endif}

{$ifdef PP16_UNDO_TEST}
function UndoChecks:Word;
var F:Word; S:TMouseState; X,Y:Integer; Before:DWord; C:Byte;

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

  procedure CheckCleared(Color:Byte);
  var X,Y:Integer;
  begin
    for Y:=0 to 63 do for X:=0 to 63 do
    begin
      Check(DocPixel(X,Y)=Color,'clear fills every document pixel');
      Check(GetPixel(CanvasX+X*2,CanvasY+Y*2)=Color,'clear redraws every canvas cell');
      Check(GetPixel(ImagePreviewX+X,ImagePreviewY+Y)=Color,'clear redraws every preview pixel');
      Check((GetPixel(CanvasX+X*2+1,CanvasY+Y*2)=8) and
            (GetPixel(CanvasX+X*2,CanvasY+Y*2+1)=8),'clear preserves the canvas grid');
    end;
  end;

begin
  F:=0; ResetTest;
  MouseReady:=True; KeyInput(27,1,0);
  Check(not ExitRequested,'idle Escape is not an exit shortcut'); MouseReady:=False;
  Check(not DocCanUndo,'new document has no undo');
  AtDoc(0,0,1); AtDoc(63,0,1); AtDoc(63,63,1); AtDoc(0,63,0);
  Check(DocCanUndo and DocDirty,'completed long stroke creates undo');
  KeyInput(8,14,0);
  Check(DocCanUndo,'Backspace is not an undo shortcut');
  CtrlHeld:=True; KeyInput(0,44,0); CtrlHeld:=False; PaintChanges;
  for Y:=0 to 63 do for X:=0 to 63 do
  begin
    Check(DocPixel(X,Y)=0,'whole stroke restored pixel exactly');
    Check(GetPixel(CanvasX+X*2,CanvasY+Y*2)=0,
          'undo scanline redraw restores every canvas cell');
    Check(GetPixel(ImagePreviewX+X,ImagePreviewY+Y)=0,
          'undo scanline redraw restores every preview pixel');
  end;
  Check(not DocDirty and not DocCanUndo,'physical Ctrl+Z restores clean flag and consumes snapshot');
  DocUndo; Check(DocChecksum=0,'second undo does not toggle');
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
  Choose(1,0);
  Check((DocChecksum=0) and not DocDirty,'Edit menu restores document');

  ResetTest; AtDoc(2,2,1); AtDoc(4,4,0); Before:=DocChecksum;
  AtDoc(20,20,1); AtDoc(40,40,1); PaintChanges;
  KeyInput(27,1,1); PaintChanges;
  Check((DocChecksum=Before) and DocDirty and DocCanUndo,
        'cancel restores dirty image and preserves preceding undo');
  Check((GetPixel(CanvasX+40,CanvasY+40)=0) and
        (GetPixel(ImagePreviewX+21,ImagePreviewY+37)=0),
        'cancel restores canvas and preview');
  AtDoc(50,50,1); AtDoc(50,50,0);
  Check(DocChecksum=Before,'cancel blocks held button until release');
  DocUndo; Check((DocChecksum=0) and not DocDirty,'old undo survives canceled stroke');
  ResetTest; AtDoc(0,0,1); AtDoc(63,63,1); KeyInput(27,1,0);
  AtDoc(63,63,0);
  Check((DocChecksum=0) and not DocDirty and not DocCanUndo,
        'cancel first stroke including release restores clean state');

  InitUI; SetZoom(2); PanView(-64,-64); DrawUI; Before:=DocChecksum; Choose(3,0);
  Check((DocChecksum=0) and DocDirty and DocCanUndo,'menu clear is undoable');
  CheckCleared(0);
  DocUndo; Check((DocChecksum=Before) and not DocDirty,'clear undo restores demo');
  ForeColor:=6; Choose(3,1);
  CheckCleared(6);
  Choose(3,1); DocUndo;
  Check(DocChecksum=Before,'same-color clear preserves preceding undo');
  KeyInput(0,46,0); PaintChanges; Check(DocChecksum=0,'Alt+C clears');
  CheckCleared(0);
  DocUndo; Check(DocChecksum=Before,'Alt+C undo');

  {Sparse changes must still use the complete-image redraw for either nibble.}
  for C:=0 to 15 do
  begin
    ResetTest; InitBlankDoc(C); DrawUI; DocClear(C);
    Check(not DocDirty and not DocCanUndo and not DocAllDirty,
          'unchanged clear stays clean without undo or repaint');
    DocBeginAction; DocSetPixel(10,10,C xor 1); DocCommitAction; Before:=DocChecksum;
    DocClear(C);
    Check(DocAllDirty and DocDirty and DocCanUndo,'sparse clear requests complete-image redraw');
    PaintChanges; CheckCleared(C);
    DocClear(C);
    Check(not DocAllDirty and DocDirty and DocCanUndo,'unchanged clear keeps dirty state and undo');
    DocUndo;
    Check((DocChecksum=Before) and DocDirty and not DocCanUndo,'clear undo restores dirty image');
  end;

  ResetTest; AtDoc(10,10,1); AtDoc(10,10,0); Before:=DocChecksum;
  Choose(0,0);
  Check((OpenMenu=8) and not ConfirmDiscard,'dirty New defaults to Cancel');
  HandleClick(4,3,1); HandleClick(4,128,1);
  Check((OpenMenu=8) and (DocChecksum=Before) and (ForeColor=15),
        'modal blocks menu and palette clicks');
  KeyInput(13,28,0);
  Check((OpenMenu=-1) and (DocChecksum=Before) and DocCanUndo,
        'default Enter cancels New and preserves undo');
  Choose(0,5); KeyInput(27,1,0);
  Check(not ExitRequested and (DocChecksum=Before),'Escape cancels dirty File Exit');
  KeyInput(27,1,0); HandleClick(180,115,1);
  Check(not ExitRequested and (OpenMenu=-1),'mouse Cancel keeps working image');
  Choose(0,0); KeyInput(9,15,0); KeyInput(13,28,0);
  Check((DocChecksum=0) and not DocDirty and not DocCanUndo and (OpenMenu=-1),
        'explicit discard creates clean blank and resets undo');
  InitUI; Choose(0,0);
  Check((DocChecksum=0) and (OpenMenu=-1),'clean New needs no discard prompt');
  Choose(0,5); Check(ExitRequested,'clean File Exit works');

  ResetTest; AtDoc(10,10,1); AtDoc(10,10,0); Choose(0,0);
  Feed(80,115,1); AtDoc(30,30,1); AtDoc(30,30,0);
  Check((DocChecksum=0) and not DocDirty,'discard click cannot leak into new canvas');
  ResetTest; AtDoc(10,10,1); AtDoc(10,10,0); Choose(0,5);
  KeyInput(9,15,0); KeyInput(13,28,0);
  Check(ExitRequested,'explicit keyboard discard exits');
  ResetTest; AtDoc(10,10,1); AtDoc(10,10,0); Choose(0,5);
  HandleClick(80,115,1); Check(ExitRequested,'explicit mouse discard exits');

  {Leave a realistic dirty-document prompt for the framebuffer inspection.}
  InitUI; SetZoom(2); PanView(-64,-64); DrawUI; FillChar(S,SizeOf(S),0);
  ForeColor:=15; AtDoc(4,48,1); AtDoc(49,33,0);
  RequestCommand(2);
  WriteLn('M5: whole-action undo, cancel, clear, New/Exit protection checked');
  UndoChecks:=F;
end;
{$endif}
{$ifdef PP16_GRADIENT_TEST}{$I ../tests/GRADTEST.INC}{$endif}
{$ifdef PP16_IMPORT_TEST}{$I ../tests/IMPTEST.INC}{$endif}
end.
