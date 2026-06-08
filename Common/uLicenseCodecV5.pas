unit uLicenseCodecV5;

interface

uses
  System.SysUtils,
  uLicenseCodec;

const
  LicenseKeyPrefixV5 = 'SI5-';
  LicenseMagicV5 = $55;
  LicensePayloadBytesV5 = 21;
  LicenseSigBytesV5 = 64;
  LicenseV5TotalBytes = 85;
  LicenseV5Base32Chars = 136;
  LicenseV5Groups = 34;

function LicenseCodecIsV5Key(const LicenseKey: string): Boolean;
function LicenseCodecNormalizeKeyV5(const LicenseKey: string): string;
function LicenseCodecFormatKeyV5(const RawKey: string): string;

function LicenseCodecBuildPayloadV5(const ForumUsername: string; const ExpiryDate: TDateTime;
  const IssuedUtc: TDateTime; Lifetime, Active: Boolean): TBytes;

function LicenseCodecFormatSignedKeyV5(const Payload, Signature: TBytes): string;

function LicenseCodecTryDecodePayloadV5(const LicenseKey: string; out Payload: TLicensePayload;
  out ErrorMsg: string): Boolean;

function LicenseCodecTryValidateV5(const LicenseKey, ExpectedUsername: string;
  const UtcNow: TDateTime; out ErrorMsg: string): Boolean;

implementation

uses
  System.Classes,
  System.DateUtils,
  uLicenseEcdsa;

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
  Raw: string;
  I: Integer;
begin
  Raw := LicenseCodecNormalizeKeyV5(RawKey);
  Result := LicenseKeyPrefixV5;
  for I := 0 to LicenseV5Groups - 1 do
  begin
    if I > 0 then
      Result := Result + '-';
    Result := Result + Copy(Raw, I * 4 + 1, 4);
  end;
end;

function LicenseCodecBuildPayloadV5(const ForumUsername: string; const ExpiryDate: TDateTime;
  const IssuedUtc: TDateTime; Lifetime, Active: Boolean): TBytes;
var
  UserNorm: string;
  UserUtf8: TBytes;
  Flags: Byte;
  ExpiryUnixDay, IssuedUnixDay: UInt32;
  I, FillStart: Integer;
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
    ExpiryUnixDay := 0;
  end
  else
    ExpiryUnixDay := LicenseCodecUnixDayFromLocalDate(ExpiryDate);

  IssuedUnixDay := LicenseCodecUnixDayFromUtc(IssuedUtc);

  SetLength(Result, LicensePayloadBytesV5);
  FillChar(Result[0], LicensePayloadBytesV5, 0);
  Result[0] := LicenseMagicV5;
  Result[1] := Flags;
  Move(ExpiryUnixDay, Result[2], SizeOf(UInt32));
  Move(IssuedUnixDay, Result[6], SizeOf(UInt32));
  Result[10] := Length(UserUtf8);
  if Length(UserUtf8) > 0 then
    Move(UserUtf8[0], Result[11], Length(UserUtf8));

  FillStart := 11 + Length(UserUtf8);
  for I := FillStart to LicensePayloadBytesV5 - 1 do
    Result[I] := 0;
end;

function LicenseCodecFormatSignedKeyV5(const Payload, Signature: TBytes): string;
var
  Combined: TBytes;
  Raw: string;
begin
  if (Length(Payload) <> LicensePayloadBytesV5) or (Length(Signature) <> LicenseSigBytesV5) then
    raise EArgumentException.Create('Invalid v5 license payload or signature length.');

  SetLength(Combined, LicenseV5TotalBytes);
  Move(Payload[0], Combined[0], LicensePayloadBytesV5);
  Move(Signature[0], Combined[LicensePayloadBytesV5], LicenseSigBytesV5);
  Raw := LicenseCodecEncodeBase32(Combined, LicenseV5Base32Chars);
  Result := LicenseCodecFormatKeyV5(Raw);
end;

function LicenseCodecTryParsePayloadV5(const Plain: TBytes; out Payload: TLicensePayload;
  out ErrorMsg: string): Boolean;
var
  Len: Integer;
  UserBytes: TBytes;
  Flags: Byte;
  ExpiryUnixDay, IssuedUnixDay: UInt32;
begin
  FillChar(Payload, SizeOf(Payload), 0);
  ErrorMsg := '';
  Result := False;
  Payload.Version := 5;

  if Length(Plain) <> LicensePayloadBytesV5 then
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
  Move(Plain[2], ExpiryUnixDay, SizeOf(UInt32));
  Move(Plain[6], IssuedUnixDay, SizeOf(UInt32));
  Len := Plain[10];
  if (Len < 1) or (Len > LicenseMaxUsernameLen) or ((11 + Len) > LicensePayloadBytesV5) then
  begin
    ErrorMsg := 'License key format is invalid.';
    Exit;
  end;

  SetLength(UserBytes, Len);
  Move(Plain[11], UserBytes[0], Len);
  Payload.ForumUsername := LicenseNormalizeUsername(TEncoding.UTF8.GetString(UserBytes));
  if Payload.ForumUsername = '' then
  begin
    ErrorMsg := 'License username is missing.';
    Exit;
  end;

  Payload.Active := (Flags and LicenseFlagActive) <> 0;
  Payload.Lifetime := (Flags and LicenseFlagLifetime) <> 0;
  Payload.ExpiryUnixDay := ExpiryUnixDay;
  Payload.IssuedUnixDay := IssuedUnixDay;
  Result := True;
end;

function LicenseCodecTryDecodePayloadV5(const LicenseKey: string; out Payload: TLicensePayload;
  out ErrorMsg: string): Boolean;
var
  Normalized: string;
  Combined, PayloadBytes, SigBytes, Hash: TBytes;
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
  if Length(Normalized) <> LicenseV5Base32Chars then
  begin
    ErrorMsg := 'License key format is invalid.';
    Exit;
  end;

  try
    Combined := LicenseCodecDecodeBase32(Normalized, LicenseV5TotalBytes);
    SetLength(PayloadBytes, LicensePayloadBytesV5);
    SetLength(SigBytes, LicenseSigBytesV5);
    Move(Combined[0], PayloadBytes[0], LicensePayloadBytesV5);
    Move(Combined[LicensePayloadBytesV5], SigBytes[0], LicenseSigBytesV5);

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
