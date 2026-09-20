unit TFDialog;
{$mode tp}{$H-}{$R+}{$Q+}
interface
var DialogSaving:Boolean;
procedure BeginFileDialog(Saving:Boolean);
procedure DrawFileDialog;
function FileKey(Key,Scan:Byte):Byte;
function FileClick(X,Y:Integer):Byte;
implementation
uses Dos,TFiles,TVideo,TFont;
var Names:array[0..63] of TFileName;
    NameCount,Chosen,Top,Focus,Cursor:Integer;
    Entry:TFileName; SelectAll,ConfirmReplace:Boolean;

procedure Border(X1,Y1,X2,Y2:Integer; C:Byte);
var Y:Integer;
begin
  HSpan(X1,X2,Y1,C); HSpan(X1,X2,Y2,C);
  for Y:=Y1+1 to Y2-1 do begin PutPixel(X1,Y,C); PutPixel(X2,Y,C) end;
end;

procedure DrawName;
var BG,FG:Byte;
begin
  BG:=0; FG:=15;
  if (Focus=0) and SelectAll then begin BG:=15; FG:=0 end;
  FillBox(104,56,255,64,BG); SmallText(108,58,Entry,FG);
  if (Focus=0) and not SelectAll then HSpan(108+Cursor*4,110+Cursor*4,64,15);
end;

procedure DrawList;
var I,N:Integer; BG,FG:Byte;
begin
  for I:=0 to 5 do begin
    N:=Top+I; BG:=1; FG:=15;
    if (N=Chosen) and (Focus=1) then begin BG:=15; FG:=1 end;
    FillBox(70,71+I*7,245,77+I*7,BG);
    if N<NameCount then SmallText(76,72+I*7,Names[N],FG);
  end;
  SmallText(250,74,'^',15); SmallText(250,106,'V',15);
end;

procedure DrawButtons;
var C:Byte;
begin
  FillBox(85,125,145,136,7); FillBox(174,125,234,136,7);
  if ConfirmReplace then SmallText(92,128,'REPLACE',4) else SmallText(110,128,'OK',4);
  SmallText(190,128,'CANCEL',4);
  C:=8; if Focus=2 then C:=4; Border(85,125,145,136,C);
  C:=8; if Focus=3 then C:=4; Border(174,125,234,136,C);
end;

procedure DrawMessage;
begin
  FillBox(58,115,261,121,1);
  if ConfirmReplace then SmallText(60,116,'REPLACE '+Entry+'? CANCEL IS DEFAULT.',14)
  else SmallText(60,116,FileError,14);
end;

procedure DrawFileDialog;
begin
  FillBox(50,36,269,145,1); Border(50,36,269,145,9); Border(53,39,266,142,7);
  if DialogSaving then Text8(88,43,'Save Image File',15)
  else Text8(88,43,'Open Image File',15);
  SmallText(68,58,'FILE',15); DrawName;
  Border(68,69,258,113,9); DrawList; DrawMessage; DrawButtons;
  SmallText(64,138,'TAB:FIELD ENTER:OK ESC:CANCEL',15);
end;

procedure BeginFileDialog(Saving:Boolean);
var S:SearchRec; I,J:Integer; Temp:TFileName;
begin
  DialogSaving:=Saving; ConfirmReplace:=False; Focus:=0; SelectAll:=True;
  Entry:=CurrentFile; if Entry='' then Entry:='UNTITLED.P16';
  FileError:=''; Cursor:=Length(Entry); NameCount:=0; Chosen:=0; Top:=0;
  FindFirst('*.P16',AnyFile,S);
  while (DosError=0) and (NameCount<64) do begin
    if (S.Attr and $18)=0 then begin Names[NameCount]:=S.Name; Inc(NameCount) end;
    FindNext(S);
  end;
  for I:=1 to NameCount-1 do begin
    Temp:=Names[I]; J:=I;
    while (J>0) and (Names[J-1]>Temp) do begin Names[J]:=Names[J-1]; Dec(J) end;
    Names[J]:=Temp;
  end;
end;

procedure Choose(N:Integer);
begin
  if NameCount=0 then Exit;
  if N<0 then N:=0; if N>=NameCount then N:=NameCount-1;
  Chosen:=N;
  if Chosen<Top then Top:=Chosen;
  if Chosen>=Top+6 then Top:=Chosen-5;
  Entry:=Names[Chosen]; Cursor:=Length(Entry); SelectAll:=True;
  DrawName; DrawList;
end;

function Submit:Byte;
var Name:TFileName; OK:Boolean;
begin
  Submit:=0;
  if not NormalizeName(Entry,Name) then begin DrawMessage; Exit end;
  Entry:=Name;
  if DialogSaving and not ConfirmReplace and Exists(Name) then begin
    ConfirmReplace:=True; Focus:=3; DrawFileDialog; Exit;
  end;
  if DialogSaving then OK:=SaveImage(Name,ConfirmReplace) else OK:=LoadImage(Name);
  ConfirmReplace:=False;
  if OK then Submit:=2 else begin Focus:=0; SelectAll:=True; DrawFileDialog end;
end;

function FileKey(Key,Scan:Byte):Byte;
begin
  FileKey:=0;
  if Key=27 then begin
    if ConfirmReplace then begin ConfirmReplace:=False; Focus:=0; DrawFileDialog end
    else FileKey:=1;
    Exit;
  end;
  if Key=9 then begin
    if ConfirmReplace then begin if Focus=3 then Focus:=2 else Focus:=3 end
    else Focus:=(Focus+1) mod 4;
    DrawName; DrawList; DrawButtons; Exit;
  end;
  if Key=13 then begin
    if Focus=3 then FileKey:=FileKey(27,1) else FileKey:=Submit;
    Exit;
  end;
  if ConfirmReplace then Exit;
  if (Scan=72) or (Scan=80) or (Scan=73) or (Scan=81) then begin
    Focus:=1;
    case Scan of
      72:Choose(Chosen-1); 80:Choose(Chosen+1);
      73:Choose(Chosen-6); 81:Choose(Chosen+6);
    end;
    DrawButtons; Exit;
  end;
  if Focus=1 then begin
    if Scan=71 then Choose(0) else if Scan=79 then Choose(NameCount-1);
    Exit;
  end;
  if Focus<>0 then Exit;
  if Scan in [71,75,77,79] then begin
    SelectAll:=False;
    case Scan of
      71:Cursor:=0; 75:if Cursor>0 then Dec(Cursor);
      77:if Cursor<Length(Entry) then Inc(Cursor); 79:Cursor:=Length(Entry);
    end;
  end else if (Key=8) or (Scan=83) then begin
    if SelectAll then begin Entry:=''; Cursor:=0 end
    else if Key=8 then begin if Cursor>0 then begin Delete(Entry,Cursor,1); Dec(Cursor) end end
    else Delete(Entry,Cursor+1,1);
    SelectAll:=False;
  end else if (Key>=32) and (Key<=126) then begin
    if SelectAll then begin Entry:=''; Cursor:=0 end;
    SelectAll:=False;
    if Length(Entry)<12 then begin Insert(UpCase(Chr(Key)),Entry,Cursor+1); Inc(Cursor) end;
  end;
  FileError:=''; DrawName; DrawMessage;
end;

function FileClick(X,Y:Integer):Byte;
begin
  FileClick:=0;
  if (Y>=125) and (Y<=136) then begin
    if (X>=85) and (X<=145) then FileClick:=Submit
    else if (X>=174) and (X<=234) then FileClick:=FileKey(27,1);
    Exit;
  end;
  if ConfirmReplace then Exit;
  if (X>=104) and (X<=255) and (Y>=56) and (Y<=65) then begin
    Focus:=0; SelectAll:=True; DrawName; DrawList; DrawButtons;
  end else if (X>=70) and (X<=257) and (Y>=71) and (Y<=112) then begin
    Focus:=1;
    if X>=248 then begin
      if Y<92 then Choose(Chosen-1) else Choose(Chosen+1);
    end else Choose(Top+(Y-71) div 7);
    DrawName; DrawList; DrawButtons;
  end;
end;
end.
