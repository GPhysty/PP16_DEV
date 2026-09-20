program HXTest;

{$mode tp}
{$H-}
{$R+}
{$Q+}
{$M 8192,0,65536}

{$ifndef CPUI8086}
  {$fatal Build this program with the i8086 cross-compiler}
{$endif}
{$ifndef MSDOS}
  {$fatal This program targets real-mode MS-DOS}
{$endif}

uses Dos;

var
  Version: Word;
  I: Integer;
  Product: DWord;
  TestFile: Text;
  TestLine: String[80];

procedure CheckIO;
var
  Code: Integer;
begin
  Code := IOResult;
  if Code <> 0 then
  begin
    WriteLn('FAIL: DOS file I/O error ', Code);
    Halt(1);
  end;
end;

begin
  WriteErrorsToStdErr := False;
  WriteLn('Tandy 1000HX / V20 - Free Pascal DOS test');
  Version := DosVersion;
  WriteLn('Reported DOS version: ', Lo(Version), '.', Hi(Version));
  WriteLn('Integer size: ', SizeOf(Integer), ' bytes');
  WriteLn('Available Pascal heap: ', MemAvail, ' bytes');

  Product := 1;
  for I := 2 to 8 do
    Product := Product * DWord(I);
  WriteLn('Arithmetic result: 8! = ', Product);
  if Product <> 40320 then
    Halt(3);
  WriteLn('PASS: 16-bit target and 32-bit integer arithmetic (8! = ', Product, ')');

  {$I-}
  Assign(TestFile, 'HXTEST.TXT');
  Rewrite(TestFile);
  CheckIO;
  WriteLn(TestFile, 'DOS file round-trip OK');
  CheckIO;
  Close(TestFile);
  CheckIO;
  Reset(TestFile);
  CheckIO;
  ReadLn(TestFile, TestLine);
  CheckIO;
  Close(TestFile);
  CheckIO;
  {$I+}
  if TestLine <> 'DOS file round-trip OK' then
    Halt(4);
  WriteLn('PASS: DOS text file write/read');
  WriteLn('ALL TESTS PASSED');
end.
