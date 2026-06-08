unit uRegistryStore;

interface

uses
  System.SysUtils,
  System.Hash;

const
  EulaVersion = 3;

function RegistryGetString(const Name: string): string;
procedure RegistrySetString(const Name, Value: string);
function RegistryTrySetString(const Name, Value: string): Boolean;
function RegistryGetInt(const Name: string; Fallback: Integer = 0): Integer;
procedure RegistrySetInt(const Name: string; Value: Integer);

function IsEulaAccepted: Boolean;
procedure SetEulaAccepted;
procedure RegistryClearAll;

implementation

uses
  Winapi.Windows,
  System.Win.Registry;

const
  KeyPath = 'Software\SmartInterview';
  EulaValue = 'EulaToken';

function OpenRead: TRegistry;
begin
  Result := TRegistry.Create(KEY_READ);
  try
    Result.RootKey := HKEY_CURRENT_USER;
    if not Result.OpenKey(KeyPath, False) then
    begin
      FreeAndNil(Result);
    end;
  except
    FreeAndNil(Result);
  end;
end;

function OpenWrite: TRegistry;
begin
  Result := TRegistry.Create(KEY_WRITE);
  try
    Result.RootKey := HKEY_CURRENT_USER;
    Result.OpenKey(KeyPath, True);
  except
    FreeAndNil(Result);
  end;
end;

function ExpectedEulaToken: string;
var
  Material: string;
begin
  Material := Format('%s|%s|eula-v%d', [GetEnvironmentVariable('COMPUTERNAME'),
    GetEnvironmentVariable('USERNAME'), EulaVersion]);
  Result := UpperCase(THashSHA2.GetHashString(Material, THashSHA2.TSHA2Version.SHA256));
end;

function RegistryGetString(const Name: string): string;
var
  Reg: TRegistry;
begin
  Result := '';
  Reg := OpenRead;
  if Reg = nil then
    Exit;
  try
    if Reg.ValueExists(Name) then
      Result := Reg.ReadString(Name);
  except
    Result := '';
  end;
  Reg.Free;
end;

procedure RegistrySetString(const Name, Value: string);
begin
  RegistryTrySetString(Name, Value);
end;

function RegistryTrySetString(const Name, Value: string): Boolean;
var
  Reg: TRegistry;
begin
  Result := False;
  Reg := OpenWrite;
  if Reg = nil then
    Exit;
  try
    Reg.WriteString(Name, Value);
    Result := True;
  except
    Result := False;
  end;
  Reg.Free;
end;

function RegistryGetInt(const Name: string; Fallback: Integer): Integer;
var
  Reg: TRegistry;
begin
  Result := Fallback;
  Reg := OpenRead;
  if Reg = nil then
    Exit;
  try
    if Reg.ValueExists(Name) then
      Result := Reg.ReadInteger(Name);
  except
    Result := Fallback;
  end;
  Reg.Free;
end;

procedure RegistrySetInt(const Name: string; Value: Integer);
var
  Reg: TRegistry;
begin
  Reg := OpenWrite;
  if Reg = nil then
    Exit;
  try
    Reg.WriteInteger(Name, Value);
  except
  end;
  Reg.Free;
end;

function IsEulaAccepted: Boolean;
var
  Stored: string;
begin
  Stored := RegistryGetString(EulaValue);
  Result := (Stored <> '') and SameText(Stored, ExpectedEulaToken);
end;

procedure SetEulaAccepted;
begin
  RegistrySetString(EulaValue, ExpectedEulaToken);
end;

procedure RegistryClearAll;
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create(KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.KeyExists(KeyPath) then
      Reg.DeleteKey(KeyPath);
  except
  end;
  Reg.Free;
end;

end.
