unit uMachineFingerprint;

interface

function MachineRequestCode: string;
function MachineNormalizedRequestCode: string;
function MachineFingerprintMatches(const NormalizedFingerprint: string): Boolean;
function MachineFingerprintNormalize(const Code: string): string;

implementation

uses
  System.SysUtils,
  System.Hash,
  System.Classes,
  System.NetEncoding,
  System.Win.Registry,
  Winapi.Windows,
  Winapi.ActiveX,
  System.Win.ComObj,
  System.Variants;

const
  AppSalt = 'SmartInterview|v1|machine';
  Base32Alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

function QueryWmi(const WmiClass, Prop: string): string;
var
  Locator, Services, Objects, Item, Value: OleVariant;
  Enum: IEnumVariant;
  Fetched: ULONG;
begin
  Result := '';
  try
    Locator := CreateOleObject('WbemScripting.SWbemLocator');
    Services := Locator.ConnectServer('', 'root\CIMV2', '', '');
    Objects := Services.ExecQuery(Format('SELECT %s FROM %s', [Prop, WmiClass]));
    Enum := IUnknown(Objects) as IEnumVariant;
    while Enum.Next(1, Item, Fetched) = S_OK do
    begin
      Value := Item.Properties_[Prop].Value;
      if VarIsNull(Value) or VarIsEmpty(Value) then
        Continue;
      Result := Trim(string(Value));
      if Result = '' then
        Continue;
      if SameText(Result, 'To be filled by O.E.M.') then
        Continue;
      if SameText(Result, 'Default string') then
        Continue;
      if Result.Replace('-', '').Replace('0', '') = '' then
        Continue;
      Exit;
    end;
  except
    Result := '';
  end;
end;

function CollectMaterial: string;
var
  Parts: TStringList;
  Guid: string;
  Reg: TRegistry;
  I: Integer;
begin
  Parts := TStringList.Create;
  try
    try
      Reg := TRegistry.Create(KEY_READ);
      try
        Reg.RootKey := HKEY_LOCAL_MACHINE;
        if Reg.OpenKey('SOFTWARE\Microsoft\Cryptography', False) then
        begin
          Guid := Trim(Reg.ReadString('MachineGuid'));
          if Guid <> '' then
            Parts.Add('mg:' + Guid);
        end;
      finally
        Reg.Free;
      end;
    except
    end;

    Parts.Add('mb:' + QueryWmi('Win32_ComputerSystemProduct', 'UUID'));
    Parts.Add('bios:' + QueryWmi('Win32_BIOS', 'SerialNumber'));

    if Parts.Count = 0 then
      Parts.Add('fallback:' + GetEnvironmentVariable('COMPUTERNAME'));

    Result := '';
    for I := 0 to Parts.Count - 1 do
    begin
      if I > 0 then
        Result := Result + '|';
      Result := Result + Parts[I];
    end;
  finally
    Parts.Free;
  end;
end;

function ComputeHash: TBytes;
var
  Material: string;
  SHA: THashSHA2;
  Utf8: TBytes;
begin
  Material := CollectMaterial;
  Utf8 := TEncoding.UTF8.GetBytes(AppSalt + '|' + Material);
  SHA := THashSHA2.Create;
  SHA.Update(Utf8);
  Result := SHA.HashAsBytes;
end;

function EncodeBase32(const Data: TBytes; Chars: Integer): string;
var
  Buffer, Bits: Integer;
  B: Byte;
  I: Integer;
begin
  Result := '';
  Buffer := 0;
  Bits := 0;
  for B in Data do
  begin
    Buffer := (Buffer shl 8) or B;
    Inc(Bits, 8);
    while (Bits >= 5) and (Length(Result) < Chars) do
    begin
      Dec(Bits, 5);
      Result := Result + Base32Alphabet[((Buffer shr Bits) and $1F) + 1];
    end;
    if Length(Result) >= Chars then
      Break;
  end;
  while Length(Result) < Chars do
  begin
    Buffer := Buffer shl 5;
    Inc(Bits, 5);
    Result := Result + Base32Alphabet[(Buffer and $1F) + 1];
  end;
end;

function FormatRequestCode(const Hash: TBytes): string;
var
  Raw: string;
  I: Integer;
begin
  Raw := EncodeBase32(Hash, 16);
  Result := '';
  for I := 0 to 3 do
  begin
    if I > 0 then
      Result := Result + '-';
    Result := Result + Copy(Raw, I * 4 + 1, 4);
  end;
end;

function MachineFingerprintNormalize(const Code: string): string;
begin
  Result := UpperCase(StringReplace(Code, '-', '', [rfReplaceAll]));
  Result := Trim(Result);
end;

function MachineRequestCode: string;
begin
  Result := FormatRequestCode(ComputeHash);
end;

function MachineNormalizedRequestCode: string;
begin
  Result := MachineFingerprintNormalize(MachineRequestCode);
end;

function MachineFingerprintMatches(const NormalizedFingerprint: string): Boolean;
begin
  if Trim(NormalizedFingerprint) = '' then
    Exit(False);
  Result := SameStr(MachineNormalizedRequestCode,
    MachineFingerprintNormalize(NormalizedFingerprint));
end;

initialization
  CoInitialize(nil);

finalization
  CoUninitialize;

end.
