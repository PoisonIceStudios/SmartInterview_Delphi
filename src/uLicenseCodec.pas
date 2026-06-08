unit uLicenseCodec;

interface

uses
  System.SysUtils;

type
  TLicensePayload = record
    F: string;
    U: string;
    E: Int64;
    P: string;
    V: Integer;
  end;

function LicenseNormalizeUsername(const Username: string): string;

function LicenseCodecIssue(const NormalizedFingerprint, ForumUsername: string;
  ExpiryUnixSeconds: Int64; const PrivateKeyPkcs8: TBytes): string;

function LicenseCodecTryValidate(const LicenseKey: string; const ExpectedUsername: string;
  out Payload: TLicensePayload; out ErrorMsg: string): Boolean;

function LicenseCodecTryReadPayload(const LicenseKey: string;
  out Payload: TLicensePayload): Boolean;

implementation

uses
  System.Classes,
  System.DateUtils,
  System.JSON,
  System.NetEncoding,
  System.Hash,
  Winapi.Windows,
  uBCryptApi,
  uMachineFingerprint;

const
  LicensePrefix = 'SI1';
  LicenseProduct = 'SmartInterview';

  LicensePublicKeySpki: array[0..90] of Byte = (
    $30, $59, $30, $13, $06, $07, $2A, $86, $48, $CE, $3D, $02, $01, $06, $08, $2A,
    $86, $48, $CE, $3D, $03, $01, $07, $03, $42, $00, $04, $FD, $25, $84, $AB, $44,
    $E6, $CA, $68, $65, $D8, $46, $AA, $A9, $E6, $8F, $98, $DB, $56, $4D, $6E, $1D,
    $B0, $5C, $A2, $16, $9A, $A7, $9E, $26, $9E, $4C, $B9, $74, $56, $02, $D3, $75,
    $68, $30, $C1, $53, $E0, $FB, $5D, $41, $B1, $38, $D4, $90, $5E, $06, $83, $E7,
    $59, $E6, $87, $E1, $52, $66, $9B, $AA, $81, $EB, $45
  );

function LicenseNormalizeUsername(const Username: string): string;
begin
  Result := LowerCase(Trim(Username));
end;

function Base64UrlEncode(const Data: TBytes): string;
begin
  Result := TNetEncoding.Base64.EncodeBytesToString(Data);
  Result := Result.Replace('+', '-').Replace('/', '_');
  while Result.EndsWith('=') do
    SetLength(Result, Length(Result) - 1);
end;

function Base64UrlDecode(const S: string): TBytes;
var
  Padded: string;
  Rem: Integer;
begin
  Padded := S.Replace('-', '+').Replace('_', '/');
  Rem := Length(Padded) mod 4;
  case Rem of
    2: Padded := Padded + '==';
    3: Padded := Padded + '=';
  end;
  Result := TNetEncoding.Base64.DecodeStringToBytes(Padded);
end;

function Sha256Hash(const Data: TBytes): TBytes;
var
  SHA: THashSHA2;
begin
  SHA := THashSHA2.Create;
  SHA.Update(Data);
  Result := SHA.HashAsBytes;
end;

function SpkiToEccPublicBlob(const Spki: TBytes): TBytes;
var
  I, PointStart: Integer;
  Magic, KeyLen: ULONG;
begin
  PointStart := -1;
  for I := 0 to High(Spki) do
    if (Spki[I] = $04) and (I + 64 <= High(Spki)) then
    begin
      PointStart := I;
      Break;
    end;
  if PointStart < 0 then
    raise Exception.Create('Invalid SPKI public key.');

  SetLength(Result, 8 + 64);
  Magic := BCRYPT_ECDSA_PUBLIC_P256_MAGIC;
  KeyLen := 32;
  Move(Magic, Result[0], SizeOf(Magic));
  Move(KeyLen, Result[4], SizeOf(KeyLen));
  Move(Spki[PointStart + 1], Result[8], 32);
  Move(Spki[PointStart + 33], Result[40], 32);
end;

function ImportVerifyPublicKey(out KeyHandle: BCRYPT_KEY_HANDLE): NTSTATUS;
var
  AlgHandle: BCRYPT_ALG_HANDLE;
  Blob, SpkiBytes: TBytes;
begin
  Result := BCryptOpenAlgorithmProvider(AlgHandle, BCRYPT_ECDSA_P256_ALGORITHM, nil, 0);
  if Result < 0 then
    Exit;
  try
    SetLength(SpkiBytes, Length(LicensePublicKeySpki));
    Move(LicensePublicKeySpki[0], SpkiBytes[0], Length(SpkiBytes));
    Blob := SpkiToEccPublicBlob(SpkiBytes);
    Result := BCryptImportKeyPair(AlgHandle, nil, BCRYPT_ECCPUBLIC_BLOB, KeyHandle,
      @Blob[0], Length(Blob), 0);
  finally
    BCryptCloseAlgorithmProvider(AlgHandle, 0);
  end;
end;

function VerifyEcdsaSha256(const Data, Signature: TBytes): Boolean;
var
  KeyHandle: BCRYPT_KEY_HANDLE;
  Hash: TBytes;
  Status: NTSTATUS;
begin
  Result := False;
  Status := ImportVerifyPublicKey(KeyHandle);
  if Status < 0 then
    Exit;
  try
    Hash := Sha256Hash(Data);
    Status := BCryptVerifySignature(KeyHandle, nil, @Hash[0], Length(Hash),
      @Signature[0], Length(Signature), 0);
    Result := Status = 0;
  finally
    BCryptDestroyKey(KeyHandle);
  end;
end;

function PayloadToJson(const Payload: TLicensePayload): string;
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('F', Payload.F);
    Obj.AddPair('U', Payload.U);
    Obj.AddPair('E', TJSONNumber.Create(Payload.E));
    Obj.AddPair('P', Payload.P);
    Obj.AddPair('V', TJSONNumber.Create(Payload.V));
    Result := Obj.ToJSON;
  finally
    Obj.Free;
  end;
end;

function JsonToPayload(const Json: string; out Payload: TLicensePayload): Boolean;
var
  Obj: TJSONObject;
begin
  Result := False;
  FillChar(Payload, SizeOf(Payload), 0);
  Obj := TJSONObject.ParseJSONValue(Json) as TJSONObject;
  if Obj = nil then
    Exit;
  try
    Payload.F := Obj.GetValue<string>('F', '');
    Payload.U := Obj.GetValue<string>('U', '');
    Payload.E := Obj.GetValue<Int64>('E', 0);
    Payload.P := Obj.GetValue<string>('P', '');
    Payload.V := Obj.GetValue<Integer>('V', 0);
    Result := True;
  finally
    Obj.Free;
  end;
end;

function SignPayload(const Payload: TLicensePayload;
  const PrivateKeyPkcs8: TBytes): string;
var
  Json, PayloadB64: string;
  PayloadBytes, Hash, Sig: TBytes;
  AlgHandle: BCRYPT_ALG_HANDLE;
  KeyHandle: BCRYPT_KEY_HANDLE;
  Status: NTSTATUS;
  SigLen: ULONG;
begin
  Json := PayloadToJson(Payload);
  PayloadB64 := Base64UrlEncode(TEncoding.UTF8.GetBytes(Json));
  PayloadBytes := TEncoding.UTF8.GetBytes(PayloadB64);
  Hash := Sha256Hash(PayloadBytes);

  Status := BCryptOpenAlgorithmProvider(AlgHandle, BCRYPT_ECDSA_P256_ALGORITHM, nil, 0);
  if Status < 0 then
    raise Exception.Create('BCryptOpenAlgorithmProvider failed.');
  try
    Status := BCryptImportKeyPair(AlgHandle, nil, BCRYPT_ECCPRIVATE_BLOB, KeyHandle,
      @PrivateKeyPkcs8[0], Length(PrivateKeyPkcs8), 0);
    if Status < 0 then
      raise Exception.Create('BCryptImportKeyPair failed (expected ECCPRIVATE blob).');
    try
      SigLen := 0;
      Status := BCryptSignHash(KeyHandle, nil, @Hash[0], Length(Hash), nil, 0, @SigLen, 0);
      if Status < 0 then
        raise Exception.Create('BCryptSignHash size query failed.');
      SetLength(Sig, SigLen);
      Status := BCryptSignHash(KeyHandle, nil, @Hash[0], Length(Hash), @Sig[0], SigLen,
        @SigLen, 0);
      if Status < 0 then
        raise Exception.Create('BCryptSignHash failed.');
      SetLength(Sig, SigLen);
    finally
      BCryptDestroyKey(KeyHandle);
    end;
  finally
    BCryptCloseAlgorithmProvider(AlgHandle, 0);
  end;

  Result := Format('%s.%s.%s', [LicensePrefix, PayloadB64, Base64UrlEncode(Sig)]);
end;

function LicenseCodecIssue(const NormalizedFingerprint, ForumUsername: string;
  ExpiryUnixSeconds: Int64; const PrivateKeyPkcs8: TBytes): string;
var
  Payload: TLicensePayload;
  UserNorm: string;
begin
  UserNorm := LicenseNormalizeUsername(ForumUsername);
  if UserNorm = '' then
    raise EArgumentException.Create('Forum username is required.');

  Payload.F := MachineFingerprintNormalize(NormalizedFingerprint);
  Payload.U := UserNorm;
  Payload.E := ExpiryUnixSeconds;
  Payload.P := LicenseProduct;
  Payload.V := 2;
  Result := SignPayload(Payload, PrivateKeyPkcs8);
end;

function LicenseCodecTryValidate(const LicenseKey: string; const ExpectedUsername: string;
  out Payload: TLicensePayload; out ErrorMsg: string): Boolean;
var
  Parts: TArray<string>;
  PayloadBytes, SigBytes: TBytes;
  Json: string;
  NowUnix: Int64;
begin
  FillChar(Payload, SizeOf(Payload), 0);
  ErrorMsg := '';
  Result := False;

  if Trim(LicenseKey) = '' then
  begin
    ErrorMsg := 'License key is empty.';
    Exit;
  end;

  Parts := LicenseKey.Trim.Split(['.']);
  if (Length(Parts) <> 3) or (Parts[0] <> LicensePrefix) then
  begin
    ErrorMsg := 'License key format is invalid.';
    Exit;
  end;

  try
    PayloadBytes := TEncoding.UTF8.GetBytes(Parts[1]);
    SigBytes := Base64UrlDecode(Parts[2]);

    if not VerifyEcdsaSha256(PayloadBytes, SigBytes) then
    begin
      ErrorMsg := 'License signature is invalid.';
      Exit;
    end;

    Json := TEncoding.UTF8.GetString(Base64UrlDecode(Parts[1]));
    if not JsonToPayload(Json, Payload) or (Payload.P <> LicenseProduct) then
    begin
      ErrorMsg := 'License payload is invalid.';
      Exit;
    end;

    if (Payload.V < 1) or (Payload.V > 2) then
    begin
      ErrorMsg := 'License version is not supported.';
      Exit;
    end;

    if not MachineFingerprintMatches(Payload.F) then
    begin
      ErrorMsg := 'This license is not valid for this computer.';
      Exit;
    end;

    if Payload.V >= 2 then
    begin
      Payload.U := LicenseNormalizeUsername(Payload.U);
      if Payload.U = '' then
      begin
        ErrorMsg := 'License username is missing.';
        Exit;
      end;
      if (ExpectedUsername <> '') and
        (Payload.U <> LicenseNormalizeUsername(ExpectedUsername)) then
      begin
        ErrorMsg := 'This license is not valid for the forum username entered.';
        Exit;
      end;
    end;

    if Payload.E > 0 then
    begin
      NowUnix := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False);
      if NowUnix > Payload.E then
      begin
        ErrorMsg := 'This license has expired.';
        Exit;
      end;
    end;

    Result := True;
  except
    on E: Exception do
    begin
      ErrorMsg := 'License key could not be read: ' + E.Message;
      Result := False;
    end;
  end;
end;

function LicenseCodecTryReadPayload(const LicenseKey: string;
  out Payload: TLicensePayload): Boolean;
var
  Parts: TArray<string>;
  Json: string;
begin
  FillChar(Payload, SizeOf(Payload), 0);
  Result := False;
  Parts := LicenseKey.Trim.Split(['.']);
  if Length(Parts) <> 3 then
    Exit;
  try
    Json := TEncoding.UTF8.GetString(Base64UrlDecode(Parts[1]));
    Result := JsonToPayload(Json, Payload);
  except
    Result := False;
  end;
end;

end.
