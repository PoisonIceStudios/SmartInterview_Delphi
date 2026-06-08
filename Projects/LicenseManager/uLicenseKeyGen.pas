unit uLicenseKeyGen;

{ Generates the ECDSA P-256 signing keypair using Windows BCrypt — no external tool.
  Writes Keys\license_signing.priv (BCRYPT_ECCPRIVATE_BLOB, 104 bytes) and
  Keys\license_signing.pub (BCRYPT_ECCPUBLIC_BLOB, 72 bytes).
  Returns the public-key hex to embed in Common\uLicensePublicKey.pas and Engine\LicenseCodecV5.cs. }

interface

uses
  System.SysUtils;

function LicenseSigningKeyExists: Boolean;
function LicenseSigningKeyPath: string;

implementation

uses
  Winapi.Windows,
  System.IOUtils,
  uBCryptApi;

function NT_SUCCESS(Status: NTSTATUS): Boolean;
begin
  Result := Status >= 0;
end;

function KeysDir: string;
begin
  Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'Keys');
end;

function LicenseSigningKeyPath: string;
begin
  Result := TPath.Combine(KeysDir, 'license_signing.priv');
end;

function LicenseSigningKeyExists: Boolean;
begin
  Result := TFile.Exists(LicenseSigningKeyPath);
end;

function BytesToHex(const Data: TBytes): string;
const
  Hex = '0123456789ABCDEF';
var
  I: Integer;
begin
  SetLength(Result, Length(Data) * 2);
  for I := 0 to High(Data) do
  begin
    Result[I * 2 + 1] := Hex[(Data[I] shr 4) + 1];
    Result[I * 2 + 2] := Hex[(Data[I] and $0F) + 1];
  end;
end;

function ExportBlob(Key: BCRYPT_KEY_HANDLE; const BlobType: string): TBytes;
var
  Needed: ULONG;
  Status: NTSTATUS;
begin
  Needed := 0;
  Status := BCryptExportKey(Key, nil, PWideChar(BlobType), nil, 0, @Needed, 0);
  if not NT_SUCCESS(Status) or (Needed = 0) then
    raise Exception.Create('BCryptExportKey size query failed.');
  SetLength(Result, Needed);
  Status := BCryptExportKey(Key, nil, PWideChar(BlobType), @Result[0], Needed, @Needed, 0);
  if not NT_SUCCESS(Status) then
    raise Exception.Create('BCryptExportKey failed.');
  SetLength(Result, Needed);
end;

end.
