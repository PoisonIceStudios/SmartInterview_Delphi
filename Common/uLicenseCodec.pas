unit uLicenseCodec;

interface

uses
  System.SysUtils;

const
  LicenseKeyChars = 32;
  LicenseKeyGroups = 8;
  LicenseMaxUsernameLen = 30;
  LicenseFlagActive = $01;
  LicenseFlagLifetime = $02;

type
  TLicensePayload = record
    ForumUsername: string;
    Active: Boolean;
    Lifetime: Boolean;
    ExpiryUnixDay: UInt32;
    IssuedUnixDay: UInt32;
    Version: Byte;
  end;

function LicenseCodecEncodeBase32(const Data: TBytes; Chars: Integer): string;
function LicenseCodecDecodeBase32(const Encoded: string; OutBytes: Integer): TBytes;

function LicenseNormalizeUsername(const Username: string): string;
function LicenseCodecNormalizeKey(const LicenseKey: string): string;
function LicenseCodecFormatKey(const RawKey: string): string;

function LicenseCodecEncode(const ForumUsername: string; const ExpiryDate: TDateTime;
  Lifetime, Active: Boolean): string;

function LicenseCodecTryDecodePayload(const LicenseKey: string; out Payload: TLicensePayload;
  out ErrorMsg: string): Boolean;

function LicenseCodecTryValidate(const LicenseKey, ExpectedUsername: string;
  const UtcNow: TDateTime; out ErrorMsg: string): Boolean;

function LicenseCodecIsExpired(const Payload: TLicensePayload; const UtcNow: TDateTime): Boolean;
function LicenseCodecExpiryToDate(ExpiryUnixDay: UInt32): TDateTime;
function LicenseCodecFormatExpiry(const Payload: TLicensePayload): string;
function LicenseCodecUnixDayFromUtc(const Utc: TDateTime): UInt32;
function LicenseCodecUnixDayFromLocalDate(const LocalDate: TDateTime): UInt32;

implementation

uses
  System.Classes,
  System.DateUtils,
  System.Hash,
  System.NetEncoding,
  uLicenseCodecV5;

const
  LicenseHmacSecret = 'SmartInterview|License|v4|hmac';
  LicenseXorSecret = 'SmartInterview|License|v4|xor';
  LicenseMagic = $54;
  LicensePayloadBytes = 20;
  Base32Alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  UnixEpochDate = 25569;

function LicenseNormalizeUsername(const Username: string): string;
begin
  Result := LowerCase(Trim(Username));
end;

function LicenseCodecNormalizeKey(const LicenseKey: string): string;
begin
  Result := UpperCase(StringReplace(LicenseKey, '-', '', [rfReplaceAll]));
  Result := Trim(Result);
end;

function LicenseCodecFormatKey(const RawKey: string): string;
var
  Raw: string;
  I: Integer;
begin
  Raw := LicenseCodecNormalizeKey(RawKey);
  Result := '';
  for I := 0 to LicenseKeyGroups - 1 do
  begin
    if I > 0 then
      Result := Result + '-';
    Result := Result + Copy(Raw, I * 4 + 1, 4);
  end;
end;

function LicenseCodecUnixDayFromUtc(const Utc: TDateTime): UInt32;
begin
  Result := UInt32(Trunc(Utc) - UnixEpochDate);
end;

function LicenseCodecUnixDayFromLocalDate(const LocalDate: TDateTime): UInt32;
var
  EndOfDayLocal, Utc: TDateTime;
begin
  EndOfDayLocal := DateOf(LocalDate) + EncodeTime(23, 59, 59, 0);
  Utc := TTimeZone.Local.ToUniversalTime(EndOfDayLocal);
  Result := LicenseCodecUnixDayFromUtc(Utc);
end;

function LicenseCodecExpiryToDate(ExpiryUnixDay: UInt32): TDateTime;
begin
  Result := UnixEpochDate + ExpiryUnixDay;
end;

function LicenseCodecFormatExpiry(const Payload: TLicensePayload): string;
begin
  if Payload.Lifetime then
    Result := 'Lifetime'
  else
    Result := FormatDateTime('yyyy-mm-dd', LicenseCodecExpiryToDate(Payload.ExpiryUnixDay));
end;

function HmacSha256(const Message, Key: TBytes): TBytes;
begin
  Result := THashSHA2.GetHMACAsBytes(Message, Key, THashSHA2.TSHA2Version.SHA256);
end;

function Keystream: TBytes;
var
  KeyBytes, Stream: TBytes;
begin
  KeyBytes := TEncoding.UTF8.GetBytes(LicenseXorSecret);
  Stream := HmacSha256(TEncoding.UTF8.GetBytes('stream'), KeyBytes);
  SetLength(Result, LicensePayloadBytes);
  Move(Stream[0], Result[0], LicensePayloadBytes);
end;

function LicenseCodecEncodeBase32(const Data: TBytes; Chars: Integer): string;
var
  Buffer, Bits, I, B: Integer;
begin
  Result := '';
  Buffer := 0;
  Bits := 0;
  for I := 0 to High(Data) do
  begin
    B := Data[I];
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
  // Flush remaining real bits (Bits is 0..4 here) into a final 5-bit group,
  // left-aligning them so decode recovers the last byte intact.
  if (Length(Result) < Chars) and (Bits > 0) then
  begin
    Result := Result + Base32Alphabet[((Buffer shl (5 - Bits)) and $1F) + 1];
  end;
  while Length(Result) < Chars do
    Result := Result + Base32Alphabet[1];
end;

function LicenseCodecDecodeBase32(const Encoded: string; OutBytes: Integer): TBytes;
var
  Buffer, Bits, OutLen, I, Idx: Integer;
  C: Char;
begin
  SetLength(Result, OutBytes);
  Buffer := 0;
  Bits := 0;
  OutLen := 0;
  for I := 1 to Length(Encoded) do
  begin
    C := Encoded[I];
    if C = '-' then
      Continue;
    Idx := Pos(C, Base32Alphabet) - 1;
    if Idx < 0 then
      raise EArgumentException.Create('License key contains invalid characters.');
    Buffer := (Buffer shl 5) or Idx;
    Inc(Bits, 5);
    while (Bits >= 8) and (OutLen < OutBytes) do
    begin
      Dec(Bits, 8);
      Result[OutLen] := (Buffer shr Bits) and $FF;
      Inc(OutLen);
    end;
  end;
  if OutLen <> OutBytes then
    raise EArgumentException.Create('License key length is invalid.');
end;

function BuildPlaintext(const UserUtf8: TBytes; Flags: Byte;
  ExpiryUnixDay: UInt32): TBytes;
var
  CanonStr: string;
  Canonical, HmacKey, Hmac: TBytes;
  FillStart, TailLen, I: Integer;
begin
  SetLength(Result, LicensePayloadBytes);
  Result[0] := LicenseMagic;
  Result[1] := Flags;
  Move(ExpiryUnixDay, Result[2], SizeOf(UInt32));
  Result[6] := Length(UserUtf8);
  if Length(UserUtf8) > 0 then
    Move(UserUtf8[0], Result[7], Length(UserUtf8));

  CanonStr := TEncoding.UTF8.GetString(UserUtf8) + '|' + IntToStr(ExpiryUnixDay) + '|' + IntToStr(Flags);
  Canonical := TEncoding.UTF8.GetBytes(CanonStr);
  HmacKey := TEncoding.UTF8.GetBytes(LicenseHmacSecret);
  Hmac := HmacSha256(Canonical, HmacKey);
  FillStart := 7 + Length(UserUtf8);
  TailLen := LicensePayloadBytes - FillStart;
  for I := 0 to TailLen - 1 do
    Result[FillStart + I] := Hmac[I];
end;

function XorCipher(const Plain: TBytes): TBytes;
var
  Stream: TBytes;
  I: Integer;
begin
  SetLength(Result, Length(Plain));
  Stream := Keystream;
  for I := 0 to High(Plain) do
    Result[I] := Plain[I] xor Stream[I mod Length(Stream)];
end;

function TryParsePlaintext(const Plain: TBytes; out Payload: TLicensePayload;
  out ErrorMsg: string): Boolean;
var
  Len, I, FillStart, TailLen: Integer;
  UserBytes, HmacKey, Hmac, Canonical: TBytes;
  CanonStr: string;
  Flags: Byte;
  ExpiryUnixDay: UInt32;
begin
  FillChar(Payload, SizeOf(Payload), 0);
  ErrorMsg := '';
  Result := False;

  if Length(Plain) <> LicensePayloadBytes then
  begin
    ErrorMsg := 'License payload size is invalid.';
    Exit;
  end;

  if Plain[0] <> LicenseMagic then
  begin
    ErrorMsg := 'License key format is invalid (expected v4).';
    Exit;
  end;

  Flags := Plain[1];
  Move(Plain[2], ExpiryUnixDay, SizeOf(UInt32));
  Len := Plain[6];
  if (Len < 1) or (Len > LicenseMaxUsernameLen) or ((7 + Len) > LicensePayloadBytes) then
  begin
    ErrorMsg := 'License key format is invalid.';
    Exit;
  end;

  SetLength(UserBytes, Len);
  Move(Plain[7], UserBytes[0], Len);
  Payload.ForumUsername := LicenseNormalizeUsername(TEncoding.UTF8.GetString(UserBytes));
  if Payload.ForumUsername = '' then
  begin
    ErrorMsg := 'License username is missing.';
    Exit;
  end;

  Payload.Active := (Flags and LicenseFlagActive) <> 0;
  Payload.Lifetime := (Flags and LicenseFlagLifetime) <> 0;
  Payload.ExpiryUnixDay := ExpiryUnixDay;
  Payload.IssuedUnixDay := 0;
  Payload.Version := 4;

  CanonStr := Payload.ForumUsername + '|' + IntToStr(ExpiryUnixDay) + '|' + IntToStr(Flags);
  Canonical := TEncoding.UTF8.GetBytes(CanonStr);
  HmacKey := TEncoding.UTF8.GetBytes(LicenseHmacSecret);
  Hmac := HmacSha256(Canonical, HmacKey);
  FillStart := 7 + Len;
  TailLen := LicensePayloadBytes - FillStart;
  for I := 0 to TailLen - 1 do
    if Plain[FillStart + I] <> Hmac[I] then
    begin
      ErrorMsg := 'License key is invalid.';
      Exit;
    end;

  Result := True;
end;

function LicenseCodecEncode(const ForumUsername: string; const ExpiryDate: TDateTime;
  Lifetime, Active: Boolean): string;
var
  UserNorm: string;
  UserUtf8, Plain, Cipher: TBytes;
  Flags: Byte;
  ExpiryUnixDay: UInt32;
  Raw: string;
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

  Plain := BuildPlaintext(UserUtf8, Flags, ExpiryUnixDay);
  Cipher := XorCipher(Plain);
  Raw := LicenseCodecEncodeBase32(Cipher, LicenseKeyChars);
  Result := LicenseCodecFormatKey(Raw);
end;

function LicenseCodecTryDecodePayload(const LicenseKey: string; out Payload: TLicensePayload;
  out ErrorMsg: string): Boolean;
var
  Normalized: string;
  Cipher, Plain: TBytes;
begin
  FillChar(Payload, SizeOf(Payload), 0);
  ErrorMsg := '';
  Result := False;

  if LicenseCodecIsV5Key(LicenseKey) then
    Exit(LicenseCodecTryDecodePayloadV5(LicenseKey, Payload, ErrorMsg));

  Normalized := LicenseCodecNormalizeKey(LicenseKey);
  if Length(Normalized) <> LicenseKeyChars then
  begin
    ErrorMsg := 'License key format is invalid.';
    Exit;
  end;

  try
    Cipher := LicenseCodecDecodeBase32(Normalized, LicensePayloadBytes);
    Plain := XorCipher(Cipher);
    Result := TryParsePlaintext(Plain, Payload, ErrorMsg);
  except
    on E: Exception do
    begin
      ErrorMsg := 'License key could not be read: ' + E.Message;
      Result := False;
    end;
  end;
end;

function LicenseCodecIsExpired(const Payload: TLicensePayload; const UtcNow: TDateTime): Boolean;
begin
  if not Payload.Active then
    Exit(True);
  if Payload.Lifetime then
    Exit(False);
  Result := LicenseCodecUnixDayFromUtc(UtcNow) > Payload.ExpiryUnixDay;
end;

function LicenseCodecTryValidate(const LicenseKey, ExpectedUsername: string;
  const UtcNow: TDateTime; out ErrorMsg: string): Boolean;
var
  Expected: string;
  Payload: TLicensePayload;
begin
  ErrorMsg := '';
  Result := False;

  if LicenseCodecIsV5Key(LicenseKey) then
    Exit(LicenseCodecTryValidateV5(LicenseKey, ExpectedUsername, UtcNow, ErrorMsg));

  Expected := LicenseNormalizeUsername(ExpectedUsername);
  if Expected = '' then
  begin
    ErrorMsg := 'Enter your forum username.';
    Exit;
  end;

  if not LicenseCodecTryDecodePayload(LicenseKey, Payload, ErrorMsg) then
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

  if LicenseCodecNormalizeKey(LicenseCodecEncode(Expected,
    LicenseCodecExpiryToDate(Payload.ExpiryUnixDay), Payload.Lifetime, Payload.Active)) <>
    LicenseCodecNormalizeKey(LicenseKey) then
  begin
    ErrorMsg := 'License key is invalid.';
    Exit;
  end;

  Result := True;
end;

end.
