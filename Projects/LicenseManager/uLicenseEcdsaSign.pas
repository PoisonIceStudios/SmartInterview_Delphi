unit uLicenseEcdsaSign;

interface

uses
  System.SysUtils;

function LicenseEcdsaSignHash(const PayloadHash: TBytes): TBytes;

implementation

uses
  Winapi.Windows,
  System.IOUtils,
  uBCryptApi;

const
  SigBytes = 64;

function NT_SUCCESS(Status: NTSTATUS): Boolean;
begin
  Result := Status >= 0;
end;

function PrivateKeyPath: string;
begin
  Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'Keys\license_signing.priv');
  if not TFile.Exists(Result) then
    Result := TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\Keys\license_signing.priv');
end;

function LicenseEcdsaSignHash(const PayloadHash: TBytes): TBytes;
var
  Alg: BCRYPT_ALG_HANDLE;
  Key: BCRYPT_KEY_HANDLE;
  PrivBlob: TBytes;
  Status: NTSTATUS;
  SigLen: ULONG;
  Path: string;
begin
  SetLength(Result, 0);
  if Length(PayloadHash) <> 32 then
    raise EArgumentException.Create('Payload hash must be 32 bytes.');

  Path := PrivateKeyPath;
  if not TFile.Exists(Path) then
    raise EFileNotFoundException.Create(
      'Signing key not found. Run: dotnet run --project tools/KeyGen/KeyGen.csproj');

  PrivBlob := TFile.ReadAllBytes(Path);
  if Length(PrivBlob) < 104 then
    raise EArgumentException.Create('Invalid signing key blob.');

  Alg := nil;
  Key := nil;
  if not NT_SUCCESS(BCryptOpenAlgorithmProvider(Alg, BCRYPT_ECDSA_P256_ALGORITHM, nil, 0)) then
    raise Exception.Create('BCryptOpenAlgorithmProvider failed.');
  try
    Status := BCryptImportKeyPair(Alg, nil, BCRYPT_ECCPRIVATE_BLOB, Key,
      @PrivBlob[0], Length(PrivBlob), 0);
    if not NT_SUCCESS(Status) then
      raise Exception.Create('Could not import signing key.');

    SetLength(Result, SigBytes);
    SigLen := 0;
    Status := BCryptSignHash(Key, nil, @PayloadHash[0], Length(PayloadHash),
      @Result[0], SigBytes, @SigLen, 0);
    if not NT_SUCCESS(Status) then
      raise Exception.Create('BCryptSignHash failed.');
    SetLength(Result, SigLen);
  finally
    if Key <> nil then
      BCryptDestroyKey(Key);
    BCryptCloseAlgorithmProvider(Alg, 0);
  end;
end;

end.
