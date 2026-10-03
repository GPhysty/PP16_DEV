program ClipFileTest;
{$mode tp}{$H-}{$R+}{$Q+}{$M 8192,0,65536}
uses Dos,TDoc,TClip,TFiles;
const Names:array[0..3] of TFileName=('RECT.CLP','OVAL.CLP','TINY.CLP','FULL.CLP');
      Widths:array[0..3] of Integer=(5,5,1,64);
      Heights:array[0..3] of Integer=(2,7,1,64);
var Failures:Word; I,J,X,Y:Integer; Before:DWord; OldClip,NowClip:TDocPixels;
    Name:TFileName; S:String[4]; G:File; Attr:Word;
procedure Check(OK:Boolean; const Message:String);
begin if not OK then begin Inc(Failures); WriteLn('FAIL: ',Message) end end;
procedure Unchanged;
begin
  Check((DocChecksum=Before) and DocDirty and DocCanUndo and
        (CurrentFile='WORK.P16'),'document, undo, dirty flag and filename preserved');
end;
begin
  Failures:=0; FileFault:=0; InitBlankDoc(0); CurrentFile:='WORK.P16';
  DocBeginAction;
  for Y:=0 to 63 do for X:=0 to 63 do DocSetPixel(X,Y,(X+3*Y) and 15);
  DocCommitAction; Before:=DocChecksum;
  if ParamStr(1)='/WRITE' then begin
    ClearClipboard;
    Check(not SaveImage('EMPTY.CLP',False),'empty clipboard cannot save'); Unchanged;
    for I:=0 to 3 do begin
      ClipboardCopy(0,0,Widths[I],Heights[I],I=1);
      Check(SaveImage(Names[I],False),'save clip'); Unchanged;
    end;
  end else begin
    Check(NormalizeName('sprite.clp',Name) and (Name='SPRITE.CLP'),'CLP normalization');
    for I:=0 to 3 do begin
      ClearClipboard; Check(LoadImage(Names[I]),'load clip from previous process'); Unchanged;
      Check(ClipboardValid and (ClipboardWidth=Widths[I]) and
            (ClipboardHeight=Heights[I]) and (ClipboardEllipse=(I=1)),'clip metadata');
      for Y:=0 to ClipboardHeight-1 do for X:=0 to ClipboardWidth-1 do begin
        {Rectangle cases have a simple independent pixel oracle. Ellipse payload
         and mask are checked independently by clpfixtures.py and ELLIPSETEST.}
        if I<>1 then Check(ClipboardPixel(X,Y)=((X+3*Y) and 15),'clip pixel');
      end;
    end;
    Assign(G,'HOST.CLP'); GetFAttr(G,Attr); SetFAttr(G,Attr or 1);
    Check(LoadImage('HOST.CLP'),'load read-only independent clip');
    SetFAttr(G,Attr); Unchanged;
    Check((ClipboardWidth=3) and (ClipboardHeight=2) and not ClipboardEllipse,'host dimensions');
    for Y:=0 to 1 do for X:=0 to 2 do Check(ClipboardPixel(X,Y)=X+3*Y,'host pixels');
    ClipboardExport(OldClip);
    for I:=0 to 15 do begin
      Str(I,S); Name:='BAD'+S+'.CLP';
      Check(not LoadImage(Name),'reject malformed clip'); Unchanged;
      ClipboardExport(NowClip);
      Check((CompareByte(OldClip,NowClip,DocBytes)=0) and ClipboardValid and
            (ClipboardWidth=3) and (ClipboardHeight=2) and not ClipboardEllipse,
            'failed load preserves entire clipboard');
    end;
    Check(not LoadImage('CLIP.P16'),'CLP cannot masquerade as P16'); Unchanged;
    Check(not SaveImage('DCLIP.CLP',True),'refuse directory target'); Unchanged;
    Check(not SaveImage('RECT.CLP',False),'overwrite requires confirmation');
    for I:=1 to 2 do begin
      FileFault:=I;
      Check(not SaveImage('RECT.CLP',True),'failed CLP write or rename'); Unchanged;
    end;
    FileFault:=0;
    Check(SaveImage('RECT.CLP',True),'confirmed CLP replacement'); Unchanged;
    ClipboardPaste(10,10,False,0);
    for Y:=0 to 1 do for X:=0 to 2 do Check(DocPixel(10+X,10+Y)=X+3*Y,'paste loaded clip');
    DocUndo; Check(DocChecksum=Before,'undo loaded paste');
  end;
  if Failures<>0 then Halt(1);
  WriteLn('CLP FILE CHECKS PASSED');
end.
