program EllipseTest;
{$mode tp}{$H-}{$R+}{$Q+}{$M 8192,0,65536}
uses TDoc,TClip,TRaster;
const Sizes:array[0..5] of Integer=(1,2,5,6,9,64);
var A,B,K,W,H,X,Y,SX,SY,DW,DH,DL,SL:Integer;
    Failures,Checks:LongInt; C:Byte;

function Inside(X,Y,W,H:Integer):Boolean;
var DX,DY:Integer; WW,HH:DWord;
begin
  DX:=2*X+1-W; DY:=2*Y+1-H;
  WW:=DWord(W)*Word(W); HH:=DWord(H)*Word(H);
  Inside:=DWord(DX*DX)*HH+DWord(DY*DY)*WW<=WW*HH;
end;

function TestColor(X,Y:Integer):Byte;
begin TestColor:=(X+3*Y) mod 16 end;

procedure Check(OK:Boolean);
begin Inc(Checks); if not OK then Inc(Failures) end;

begin
  WriteErrorsToStdErr:=False; Failures:=0; Checks:=0;
  WriteLn('PP16 ellipse clipboard checks');
  for A:=0 to 5 do for B:=0 to 5 do
  begin
    W:=Sizes[A]; H:=Sizes[B];
    for K:=0 to 2 do
    begin
      InitBlankDoc(0);
      for Y:=0 to H-1 do for X:=0 to W-1 do
        DocSetPixel(X,Y,TestColor(X,Y));
      DocSaved; ClipboardCopy(0,0,W,H,True);
      Check(not DocDirty);
      case K of
        1:ClipboardMirror;
        2:ClipboardRotateClockwise;
      end;
      Check(ClipboardEllipse);
      DW:=ClipboardWidth; DH:=ClipboardHeight;
      InitBlankDoc(7); ClipboardPaste(0,0,DW,DH,False,0);
      for Y:=0 to DH-1 do for X:=0 to DW-1 do
      begin
        SX:=X; SY:=Y;
        case K of
          1:SX:=W-1-X;
          2:begin SX:=Y; SY:=H-1-X end;
        end;
        C:=7; if Inside(SX,SY,W,H) then C:=TestColor(SX,SY);
        Check(DocPixel(X,Y)=C);
      end;
      DocUndo; Check(DocPixel(0,0)=7);
    end;
    DW:=W; if DW<64 then Inc(DW) else Dec(DW);
    DH:=H; if DH<64 then Inc(DH) else Dec(DH);
    InitBlankDoc(0);
    for Y:=0 to H-1 do for X:=0 to W-1 do
      DocSetPixel(X,Y,TestColor(X,Y));
    ClipboardCopy(0,0,W,H,True);
    InitBlankDoc(7); ClipboardPaste(0,0,DW,DH,False,0);
    for Y:=0 to DH-1 do for X:=0 to DW-1 do
    begin
      SY:=((2*Y+1)*H) div (2*DH);
      C:=7; DL:=EllipseInset(Y,DW,DH); SL:=EllipseInset(SY,W,H);
      if Inside(X,Y,DW,DH) and (W>2*SL) then
      begin
        SX:=SL+((2*(X-DL)+1)*(W-2*SL)) div (2*(DW-2*DL));
        C:=TestColor(SX,SY);
      end;
      Check(DocPixel(X,Y)=C);
    end;
    DocUndo; Check(DocPixel(0,0)=7);
    InitBlankDoc(9); ClipboardCut(0,0,W,H,0,True);
    for Y:=0 to H-1 do for X:=0 to W-1 do
    begin
      C:=9; if Inside(X,Y,W,H) then C:=0;
      Check(DocPixel(X,Y)=C);
    end;
    DocUndo; Check(DocPixel(W div 2,H div 2)=9);
  end;
  InitBlankDoc(3); ClipboardCopy(0,0,5,5,True);
  InitBlankDoc(7); ClipboardPaste(-2,-2,ClipboardWidth,ClipboardHeight,False,0);
  Check(DocPixel(0,0)=3); Check(DocPixel(2,2)=7); Check(DocPixel(3,0)=7);
  InitBlankDoc(7); ClipboardPaste(61,61,ClipboardWidth,ClipboardHeight,False,0);
  Check(DocPixel(63,63)=3); Check(DocPixel(61,61)=7);
  InitBlankDoc(3); ClipboardCopy(0,0,5,5,False);
  Check(not ClipboardEllipse);
  InitBlankDoc(7); ClipboardPaste(0,0,ClipboardWidth,ClipboardHeight,False,0); Check(DocPixel(0,0)=3);
  {Paste Behind keys off the caller-selected background, not palette zero.}
  InitBlankDoc(6); DocSetPixel(0,0,9); DocSetPixel(1,0,0); DocSetPixel(2,0,5);
  ClipboardCopy(0,0,3,1,False);
  InitBlankDoc(4); DocSetPixel(10,10,6); DocSetPixel(11,10,6); DocSetPixel(12,10,7);
  ClipboardPaste(10,10,ClipboardWidth,ClipboardHeight,True,6);
  Check(DocPixel(10,10)=9); Check(DocPixel(11,10)=0); Check(DocPixel(12,10)=7);
  if Failures=0 then WriteLn('ELLIPSE CHECKS PASSED: ',Checks,' checks')
  else WriteLn('ELLIPSE CHECKS FAILED: ',Failures,' of ',Checks);
  if Failures<>0 then Halt(1);
end.