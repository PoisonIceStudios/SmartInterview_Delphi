unit uLicenseEcdsa;

interface

uses
  System.SysUtils;

function LicenseEcdsaHash(const Data: TBytes): TBytes;
function LicenseEcdsaVerify(const PayloadHash, Signature: TBytes): Boolean;

implementation

uses
  Winapi.Windows,
  System.Hash,
  uBCryptApi,
  uLicensePublicKey;

function NT_SUCCESS(Status: NTSTATUS): Boolean;
begin
  Result := Status >= 0;
end;

function LicenseEcdsaVerify(const PayloadHash, Signature: TBytes): Boolean;
var
  Alg: BCRYPT_ALG_HANDLE;
  Key: BCRYPT_KEY_HANDLE;
  PubBlob: TBytes;
  Status: NTSTATUS;
begin
  Result := False;
  if (Length(PayloadHash) <> 32) or (Length(Signature) <> 64) then
    Exit;

  PubBlob := LicensePublicKeyBlob;
  if Length(PubBlob) < 72 then
    Exit;

  Alg := nil;
  Key := nil;
  if not NT_SUCCESS(BCryptOpenAlgorithmProvider(Alg, BCRYPT_ECDSA_P256_ALGORITHM, nil, 0)) then
    Exit;
  try
    Status := BCryptImportKeyPair(Alg, nil, BCRYPT_ECCPUBLIC_BLOB, Key,
      @PubBlob[0], Length(PubBlob), 0);
    if not NT_SUCCESS(Status) then
      Exit;
    Status := BCryptVerifySignature(Key, nil, @PayloadHash[0], Length(PayloadHash),
      @Signature[0], Length(Signature), 0);
    Result := NT_SUCCESS(Status);
  finally
    if Key <> nil then
      BCryptDestroyKey(Key);
    BCryptCloseAlgorithmProvider(Alg, 0);
  end;
end;

function LicenseEcdsaHash(const Data: TBytes): TBytes;
begin
  Result := THashSHA2.GetHashBytes(Data);
end;

end.
