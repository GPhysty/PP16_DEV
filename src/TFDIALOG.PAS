unit TFDialog;
{$mode tp}{$H-}{$R+}{$Q+}
interface
var DialogSaving,DialogImporting:Boolean;
procedure BeginFileDialog(Saving:Boolean);
procedure BeginImportDialog;
procedure DrawFileDialog;
function FileKey(Key,Scan:Byte):Byte;
function FileClick(X,Y:Integer):Byte;
implementation
uses Dos,TFiles,TVideo,TFont,TDoc,TImport;
var Names:array[0..63] of TFileName;
    NameCount,Chosen,Top,Focus,Cursor:Integer;
    Entry:TFileName; SelectAll,ConfirmReplace:Boolean;
    ImportDetails:Boolean; ImportSource:TFileName;
    ImageNumber,ImageCount,ImportWidth,ImportHeight:Word;

function Number(N:Word):String;
var S:String[6];
begin Str(N,S); Number:=S end;

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
  if ImportDetails then begin
    FillBox(70,71,257,112,1);
    SmallText(76,76,'IMAGE '+Number(ImageNumber)+' / '+Number(ImageCount),15);
    DrawBorder(198,72,219,85,7); SmallText(207,77,'<',15);
    DrawBorder(232,72,253,85,7); SmallText(241,77,'>',15);
    if Focus=1 then DrawBorder(71,71,255,86,14);
    SmallText(76,91,'SIZE '+Number(ImportWidth)+' X '+Number(ImportHeight),15);
    SmallText(76,102,'TOP LEFT; BLACK PADDING',15); Exit;
  end;
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
  if ConfirmReplace then begin
    if DialogSaving then SmallText(92,128,'REPLACE',4)
    else SmallText(92,128,'DISCARD',4);
  end else SmallText(110,128,'OK',4);
  SmallText(190,128,'CANCEL',4);
  C:=8; if Focus=2 then C:=4; DrawBorder(85,125,145,136,C);
  C:=8; if Focus=3 then C:=4; DrawBorder(174,125,234,136,C);
end;

procedure DrawMessage;
begin
  FillBox(58,115,261,121,1);
  if ConfirmReplace then begin
    if DialogSaving then SmallText(60,116,'REPLACE '+Entry+'? CANCEL IS DEFAULT.',14)
    else SmallText(60,116,'DISCARD UNSAVED IMAGE? CANCEL IS DEFAULT.',14);
  end
  else SmallText(60,116,FileError,14);
end;

procedure DrawFileDialog;
begin
  FillBox(50,36,269,145,1); DrawBorder(50,36,269,145,9); DrawBorder(53,39,266,142,7);
  if ImportDetails then Text8(88,43,'Import PUT',15)
  else if DialogImporting then Text8(88,43,'Import PCX/PUT',15)
  else if DialogSaving then Text8(88,43,'Save P16 / CLP',15)
  else Text8(88,43,'Open P16 / CLP',15);
  if ImportDetails then SmallText(68,58,'PAL',15) else SmallText(68,58,'FILE',15);
  DrawName;
  DrawBorder(68,69,258,113,9); DrawList; DrawMessage; DrawButtons;
  SmallText(64,138,'TAB:FIELD ENTER:OK ESC:CANCEL',15);
end;

procedure StartDialog(Saving,Importing:Boolean);
var S:SearchRec; I,J:Integer; Temp:TFileName;
    Valid:Boolean;
begin
  DialogSaving:=Saving; DialogImporting:=Importing; ImportDetails:=False;
  ConfirmReplace:=False; Focus:=0; SelectAll:=True;
  Entry:=CurrentFile; if Entry='' then Entry:='UNTITLED.P16';
  if Importing then Entry:='IMAGE.PCX';
  FileError:=''; Cursor:=Length(Entry); NameCount:=0; Chosen:=0; Top:=0;
  FindFirst('*.*',AnyFile,S);
  while (DosError=0) and (NameCount<64) do begin
    if (S.Attr and $18)=0 then begin
      if Importing then Valid:=NormalizeImportName(S.Name,Temp)
      else Valid:=NormalizeName(S.Name,Temp);
      if Valid and (Temp=S.Name) then begin Names[NameCount]:=Temp; Inc(NameCount) end;
    end;
    FindNext(S);
  end;
  for I:=1 to NameCount-1 do begin
    Temp:=Names[I]; J:=I;
    while (J>0) and (Names[J-1]>Temp) do begin Names[J]:=Names[J-1]; Dec(J) end;
    Names[J]:=Temp;
  end;
  FileError:='';
end;

procedure BeginFileDialog(Saving:Boolean);
begin StartDialog(Saving,False) end;
procedure BeginImportDialog;
begin StartDialog(False,True) end;

procedure ChangeImage(N:Integer);
begin
  if N<1 then N:=1; if N>ImageCount then N:=ImageCount;
  if InspectImport(ImportSource,N,ImageCount,ImportWidth,ImportHeight) then begin
    ImageNumber:=N; FileError:='';
  end
  else FileError:=ImportError;
  Focus:=1; DrawList; DrawButtons; DrawMessage;
end;

function ImportCancelled:Boolean;
var R:Registers;
begin
  ImportCancelled:=False; FillChar(R,SizeOf(R),0); R.AH:=1; Intr($16,R);
  if (R.Flags and $40)<>0 then Exit;
  R.AH:=0; Intr($16,R); ImportCancelled:=R.AL=27;
end;

function SubmitImport:Byte;
var Name:TFileName; OK:Boolean;
begin
  SubmitImport:=0;
  if ImportDetails then begin
    if not NormalizePaletteName(Entry,Name) then begin DrawMessage; Exit end;
    FillBox(58,115,261,121,1); SmallText(60,116,'CONVERTING... ESC TO CANCEL',14);
    OK:=ImportImage(ImportSource,ImageNumber,Name,ImportCancelled);
  end else begin
    if not NormalizeImportName(Entry,Name) then begin DrawMessage; Exit end;
    Entry:=Name;
    if not InspectImport(Name,1,ImageCount,ImportWidth,ImportHeight) then begin
      FileError:=ImportError; DrawMessage; Exit;
    end;
    if Copy(Name,Length(Name)-3,4)='.PUT' then begin
      ImportSource:=Name; ImportDetails:=True; ImageNumber:=1;
      Entry:=Copy(Name,1,Length(Name)-4)+'.APF'; Cursor:=Length(Entry);
      SelectAll:=True; Focus:=0; FileError:='CHOOSE IMAGE; ASSOCIATED APF OR YOUR PAL';
      DrawFileDialog; Exit;
    end;
    FillBox(58,115,261,121,1); SmallText(60,116,'CONVERTING... ESC TO CANCEL',14);
    OK:=ImportImage(Name,1,'',ImportCancelled);
  end;
  if OK then SubmitImport:=2 else begin Focus:=0; SelectAll:=True; DrawFileDialog end;
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
  if DialogImporting then begin Submit:=SubmitImport; Exit end;
  if not NormalizeName(Entry,Name) then begin DrawMessage; Exit end;
  Entry:=Name;
  if not ConfirmReplace and
     ((DialogSaving and Exists(Name)) or
      (not DialogSaving and not ClipName(Name) and DocDirty)) then begin
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
  if ImportDetails and ((Scan in [72,80,73,81]) or
     ((Focus=1) and (Scan in [71,75,77,79]))) then begin
    case Scan of
      71:ChangeImage(1); 79:ChangeImage(ImageCount);
      72,75:ChangeImage(ImageNumber-1); 80,77:ChangeImage(ImageNumber+1);
      73:ChangeImage(ImageNumber-10); 81:ChangeImage(ImageNumber+10);
    end;
    Exit;
  end;
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
  if ImportDetails and (Y>=71) and (Y<=86) then begin
    if (X>=198) and (X<=219) then ChangeImage(ImageNumber-1)
    else if (X>=232) and (X<=253) then ChangeImage(ImageNumber+1);
    Exit;
  end;
  if (X>=104) and (X<=255) and (Y>=56) and (Y<=65) then begin
    Focus:=0; SelectAll:=True; DrawName; DrawList; DrawButtons;
  end else if not ImportDetails and (X>=70) and (X<=257) and (Y>=71) and (Y<=112) then begin
    Focus:=1;
    if X>=248 then begin
      if Y<92 then Choose(Chosen-1) else Choose(Chosen+1);
    end else Choose(Top+(Y-71) div 7);
    DrawName; DrawList; DrawButtons;
  end;
end;
end.
