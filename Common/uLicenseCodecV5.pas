unit uLicenseCodecV5;

{ License v5 keys (SI5-...). Compact, variable-length payload + ECDSA P-256 signature.
  Payload: magic(1) flags(1) expiryDay(2, UInt16 LE) userLen(1) username(userLen).
  Combined = payload || signature(64). Base32, grouped in 4s, prefixed "SI5-". }

interface

uses
  System.SysUtils,
  uLicenseCodec;

const
  LicenseKeyPrefixV5 = 'SI5-';
  LicenseMagicV5 = $55;
  LicenseSigBytesV5 = 64;
  LicenseV5HeaderBytes = 5;

function LicenseCodecIsV5Key(const LicenseKey: string): Boolean;
function LicenseCodecNormalizeKeyV5(const LicenseKey: string): string;
function LicenseCodecFormatKeyV5(const RawKey: string): string;

function LicenseCodecBuildPayloadV5(const ForumUsername: string; const ExpiryDate: TDateTime;
  Lifetime, Active: Boolean): TBytes;

function LicenseCodecFormatSignedKeyV5(const Payload, Signature: TBytes): string;

function LicenseCodecTryDecodePayloadV5(const LicenseKey: string; out Payload: TLicensePayload;
  out ErrorMsg: string): Boolean;

function LicenseCodecTryValidateV5(const LicenseKey, ExpectedUsername: string;
  const UtcNow: TDateTime; out ErrorMsg: string): Boolean;

implementation

uses
  System.DateUtils,
  uLicenseEcdsa;

function Base32CharCount(ByteCount: Integer): Integer;
begin
  Result := (ByteCount * 8 + 4) div 5;
end;

function LicenseCodecIsV5Key(const LicenseKey: string): Boolean;
begin
  Result := UpperCase(Trim(LicenseKey)).StartsWith('SI5');
end;

function LicenseCodecNormalizeKeyV5(const LicenseKey: string): string;
var
  S: string;
begin
  S := UpperCase(Trim(LicenseKey));
  if S.StartsWith('SI5-') then
    S := Copy(S, 5, MaxInt)
  else if S.StartsWith('SI5') then
    S := Copy(S, 4, MaxInt);
  Result := StringReplace(S, '-', '', [rfReplaceAll]);
end;

function LicenseCodecFormatKeyV5(const RawKey: string): string;
var
  Raw, Group: string;
  I: Integer;
begin
  Raw := LicenseCodecNormalizeKeyV5(RawKey);
  Result := LicenseKeyPrefixV5;
  I := 0;
  while I * 4 < Length(Raw) do
  begin
    Group := Copy(Raw, I * 4 + 1, 4);
    if I > 0 then
      Result := Result + '-';
    Result := Result + Group;
    Inc(I);
  end;
end;

function LicenseCodecBuildPayloadV5(const ForumUsername: string; const ExpiryDate: TDateTime;
  Lifetime, Active: Boolean): TBytes;
var
  UserNorm: string;
  UserUtf8: TBytes;
  Flags: Byte;
  ExpiryDay: UInt32;
  Expiry16: Word;
begin
  UserNorm := LicenseNormalizeUsername(ForumUsername);
  if UserNorm = '' then
    raise EArgumentException.Create('Forum username is required.');

  UserUtf8 := TEncoding.UTF8.GetBytes(UserNorm);
  if Length(UserUtf8) > LicenseMaxUsernameLen then
    raise EArgumentException.Create(
      Format('Forum username is too long (max %d characters).', [LicenseMaxUsernameLen]));

  Flags := 0;
  if Active then
    Flags := Flags or LicenseFlagActive;
  if Lifetime then
  begin
    Flags := Flags or LicenseFlagLifetime;
    ExpiryDay := 0;
  end
  else
    ExpiryDay := LicenseCodecUnixDayFromLocalDate(ExpiryDate);

  if ExpiryDay > High(Word) then
    raise EArgumentException.Create('Expiry date is out of range.');
  Expiry16 := Word(ExpiryDay);

  SetLength(Result, LicenseV5HeaderBytes + Length(UserUtf8));
  Result[0] := LicenseMagicV5;
  Result[1] := Flags;
  Result[2] := Byte(Expiry16 and $FF);
  Result[3] := Byte((Expiry16 shr 8) and $FF);
  Result[4] := Byte(Length(UserUtf8));
  if Length(UserUtf8) > 0 then
    Move(UserUtf8[0], Result[LicenseV5HeaderBytes], Length(UserUtf8));
end;

function LicenseCodecFormatSignedKeyV5(const Payload, Signature: TBytes): string;
var
  Combined: TBytes;
  Total: Integer;
  Raw: string;
begin
  if (Length(Payload) < LicenseV5HeaderBytes) or (Length(Signature) <> LicenseSigBytesV5) then
    raise EArgumentException.Create('Invalid v5 license payload or signature length.');

  Total := Length(Payload) + LicenseSigBytesV5;
  SetLength(Combined, Total);
  Move(Payload[0], Combined[0], Length(Payload));
  Move(Signature[0], Combined[Length(Payload)], LicenseSigBytesV5);
  Raw := LicenseCodecEncodeBase32(Combined, Base32CharCount(Total));
  Result := LicenseCodecFormatKeyV5(Raw);
end;

function LicenseCodecTryParsePayloadV5(const Plain: TBytes; out Payload: TLicensePayload;
  out ErrorMsg: string): Boolean;
var
  Len: Integer;
  UserBytes: TBytes;
  Flags: Byte;
  ExpiryDay: UInt32;
begin
  FillChar(Payload, SizeOf(Payload), 0);
  ErrorMsg := '';
  Result := False;
  Payload.Version := 5;

  if Length(Plain) < LicenseV5HeaderBytes then
  begin
    ErrorMsg := 'License payload size is invalid.';
    Exit;
  end;

  if Plain[0] <> LicenseMagicV5 then
  begin
    ErrorMsg := 'License key format is invalid (expected v5).';
    Exit;
  end;

  Flags := Plain[1];
  ExpiryDay := UInt32(Plain[2]) or (UInt32(Plain[3]) shl 8);
  Len := Plain[4];
  if (Len < 1) or (Len > LicenseMaxUsernameLen) or ((LicenseV5HeaderBytes + Len) <> Length(Plain)) then
  begin
    ErrorMsg := 'License key format is invalid.';
    Exit;
  end;

  SetLength(UserBytes, Len);
  Move(Plain[LicenseV5HeaderBytes], UserBytes[0], Len);
  Payload.ForumUsername := LicenseNormalizeUsername(TEncoding.UTF8.GetString(UserBytes));
  if Payload.ForumUsername = '' then
  begin
    ErrorMsg := 'License username is missing.';
    Exit;
  end;

  Payload.Active := (Flags and LicenseFlagActive) <> 0;
  Payload.Lifetime := (Flags and LicenseFlagLifetime) <> 0;
  Payload.ExpiryUnixDay := ExpiryDay;
  Payload.IssuedUnixDay := 0;
  Result := True;
end;

function LicenseCodecTryDecodePayloadV5(const LicenseKey: string; out Payload: TLicensePayload;
  out ErrorMsg: string): Boolean;
var
  Normalized: string;
  Header, Combined, PayloadBytes, SigBytes, Hash: TBytes;
  UserLen, PayloadLen, Total: Integer;
begin
  FillChar(Payload, SizeOf(Payload), 0);
  ErrorMsg := '';
  Result := False;

  if not LicenseCodecIsV5Key(LicenseKey) then
  begin
    ErrorMsg := 'Not a v5 license key.';
    Exit;
  end;

  Normalized := LicenseCodecNormalizeKeyV5(LicenseKey);
  if Length(Normalized) < Base32CharCount(LicenseV5HeaderBytes) then
  begin
    ErrorMsg := 'License key format is invalid.';
    Exit;
  end;

  try
    Header := LicenseCodecDecodeBase32(Copy(Normalized, 1, Base32CharCount(LicenseV5HeaderBytes)),
      LicenseV5HeaderBytes);
    UserLen := Header[4];
    if (UserLen < 1) or (UserLen > LicenseMaxUsernameLen) then
    begin
      ErrorMsg := 'License key format is invalid.';
      Exit;
    end;

    PayloadLen := LicenseV5HeaderBytes + UserLen;
    Total := PayloadLen + LicenseSigBytesV5;
    if Length(Normalized) <> Base32CharCount(Total) then
    begin
      ErrorMsg := 'License key format is invalid.';
      Exit;
    end;

    Combined := LicenseCodecDecodeBase32(Normalized, Total);
    SetLength(PayloadBytes, PayloadLen);
    SetLength(SigBytes, LicenseSigBytesV5);
    Move(Combined[0], PayloadBytes[0], PayloadLen);
    Move(Combined[PayloadLen], SigBytes[0], LicenseSigBytesV5);

    if not LicenseCodecTryParsePayloadV5(PayloadBytes, Payload, ErrorMsg) then
      Exit;

    Hash := LicenseEcdsaHash(PayloadBytes);
    if not LicenseEcdsaVerify(Hash, SigBytes) then
    begin
      ErrorMsg := 'License signature is invalid.';
      Exit;
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

function LicenseCodecTryValidateV5(const LicenseKey, ExpectedUsername: string;
  const UtcNow: TDateTime; out ErrorMsg: string): Boolean;
var
  Expected: string;
  Payload: TLicensePayload;
begin
  ErrorMsg := '';
  Result := False;

  Expected := LicenseNormalizeUsername(ExpectedUsername);
  if Expected = '' then
  begin
    ErrorMsg := 'Enter your forum username.';
    Exit;
  end;

  if not LicenseCodecTryDecodePayloadV5(LicenseKey, Payload, ErrorMsg) then
    Exit;

  if LicenseNormalizeUsername(Payload.ForumUsername) <> Expected then
  begin
    ErrorMsg := 'This license is not valid for the forum username entered.';
    Exit;
  end;

  if not Payload.Active then
  begin
    ErrorMsg := 'This license has been deactivated.';
    Exit;
  end;

  if LicenseCodecIsExpired(Payload, UtcNow) then
  begin
    ErrorMsg := 'This license has expired. Enter a new license code from the seller.';
    Exit;
  end;

  Result := True;
end;

end.
