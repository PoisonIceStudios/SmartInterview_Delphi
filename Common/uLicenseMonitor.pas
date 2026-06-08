unit uLicenseMonitor;

{ Periodic license re-validation with online UTC anchor and offline grace. }

interface

uses
  System.SysUtils;

type
  TLicensePeriodicResult = (
    lprOk,
    lprExpired,
    lprInvalid,
    lprOfflineOk,
    lprOfflineBlocked,
    lprNoLicense
  );

const
  LicenseRecheckIntervalMs = 6 * 60 * 60 * 1000;
  LicenseOfflineGraceMs = 72 * 60 * 60 * 1000;

procedure LicenseMonitorReset;
procedure LicenseMonitorNoteOnlineSuccess(const UtcNow: TDateTime);
procedure LicenseMonitorPersistAnchor(const Utc: TDateTime; const User, Key: string);
procedure LicenseMonitorPrimeFromStore(const User, Key: string);
function LicenseMonitorPeriodicCheck(out Message: string): TLicensePeriodicResult;

implementation

uses
  Winapi.Windows,
  System.DateUtils,
  System.Hash,
  uLicenseCodec,
  uLicenseOnlineTime,
  uRegistryStore;

const
  AnchorUtcKey = 'LicenseAnchorUtc';
  AnchorHmacKey = 'LicenseAnchorHmac';
  AnchorSecret = 'SmartInterview|LicenseAnchor|v1|hmac';

var
  GAnchorUtc: TDateTime;
  GAnchorMonotonicMs: UInt64;
  GAnchorValid: Boolean;
  GLastPeriodicCheckMs: UInt64;

function MonotonicMs: UInt64;
begin
  Result := GetTickCount64;
end;

function BytesToHex(const Data: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Data) do
    Result := Result + IntToHex(Data[I], 2);
  Result := LowerCase(Result);
end;

function AnchorHmac(const Utc: TDateTime; const User, Key: string): string;
var
  Payload, Secret, Digest: TBytes;
  Canon: string;
begin
  Canon := Format('%.0f|%s|%s', [Utc, User, Key]);
  Payload := TEncoding.UTF8.GetBytes(Canon);
  Secret := TEncoding.UTF8.GetBytes(AnchorSecret);
  Digest := THashSHA2.GetHMACAsBytes(Payload, Secret, THashSHA2.TSHA2Version.SHA256);
  Result := BytesToHex(Digest);
end;

procedure LicenseMonitorPersistAnchor(const Utc: TDateTime; const User, Key: string);
begin
  RegistrySetString(AnchorUtcKey, FloatToStr(Utc, TFormatSettings.Invariant()));
  RegistrySetString(AnchorHmacKey, AnchorHmac(Utc, User, Key));
end;

procedure LicenseMonitorLoadAnchorFromRegistry(const User, Key: string);
var
  Raw, Expected: string;
  Utc: TDateTime;
  UtcValue: Double;
begin
  GAnchorValid := False;
  Raw := RegistryGetString(AnchorUtcKey);
  Expected := RegistryGetString(AnchorHmacKey);
  if (Raw = '') or (Expected = '') then
    Exit;
  if not TryStrToFloat(Raw, UtcValue, TFormatSettings.Invariant()) then
    Exit;
  Utc := UtcValue;
  if not SameText(AnchorHmac(Utc, User, Key), Expected) then
    Exit;
  GAnchorUtc := Utc;
  GAnchorMonotonicMs := MonotonicMs;
  GAnchorValid := True;
end;

procedure LicenseMonitorReset;
begin
  GAnchorValid := False;
  GLastPeriodicCheckMs := 0;
end;

procedure LicenseMonitorNoteOnlineSuccess(const UtcNow: TDateTime);
begin
  GAnchorUtc := UtcNow;
  GAnchorMonotonicMs := MonotonicMs;
  GAnchorValid := True;
end;

procedure LicenseMonitorPrimeFromStore(const User, Key: string);
begin
  if Trim(Key) = '' then
    Exit;
  LicenseMonitorLoadAnchorFromRegistry(User, Key);
end;

function EstimateUtcNow: TDateTime;
var
  ElapsedMs: UInt64;
begin
  if not GAnchorValid then
    Exit(0);
  ElapsedMs := MonotonicMs - GAnchorMonotonicMs;
  Result := GAnchorUtc + (ElapsedMs / 86400000.0);
end;

function ValidateAgainstUtc(const Key, User: string; const Utc: TDateTime;
  out Err: string): Boolean;
var
  Payload: TLicensePayload;
begin
  Result := LicenseCodecTryValidate(Key, User, Utc, Err);
  if not Result and LicenseCodecTryDecodePayload(Key, Payload, Err) and
     (LicenseCodecIsExpired(Payload, Utc) or not Payload.Active) then
    Err := 'This license has expired. Enter a new license code from the seller.';
end;

function LicenseMonitorPeriodicCheck(out Message: string): TLicensePeriodicResult;
var
  Key, User, Err: string;
  Utc: TDateTime;
  NowMono: UInt64;
  Payload: TLicensePayload;
begin
  Message := '';
  NowMono := MonotonicMs;
  if GLastPeriodicCheckMs <> 0 then
    if (NowMono - GLastPeriodicCheckMs) < LicenseRecheckIntervalMs then
      Exit(lprOk);
  GLastPeriodicCheckMs := NowMono;

  Key := RegistryGetString('LicenseKey');
  User := LicenseNormalizeUsername(RegistryGetString('LicenseForumUser'));
  if Trim(Key) = '' then
    Exit(lprNoLicense);

  // Lifetime licenses never expire → re-validate fully offline. No time server, no
  // offline-grace window, no spurious re-prompt when the network is down.
  if LicenseCodecTryDecodePayload(Key, Payload, Err) and Payload.Lifetime then
  begin
    if LicenseCodecTryValidate(Key, User, Now, Err) then
      Exit(lprOk);
    Message := Err;
    Exit(lprInvalid);
  end;

  if not GAnchorValid then
    LicenseMonitorLoadAnchorFromRegistry(User, Key);

  if TryFetchUtcNow(Utc, Err) then
  begin
    if ValidateAgainstUtc(Key, User, Utc, Err) then
    begin
      LicenseMonitorNoteOnlineSuccess(Utc);
      LicenseMonitorPersistAnchor(Utc, User, Key);
      Exit(lprOk);
    end;
    Message := Err;
    if LicenseCodecTryDecodePayload(Key, Payload, Err) and
       (LicenseCodecIsExpired(Payload, Utc) or not Payload.Active) then
      Exit(lprExpired);
    Exit(lprInvalid);
  end;

  if not GAnchorValid then
  begin
    Message := Err;
    Exit(lprOfflineBlocked);
  end;

  Utc := EstimateUtcNow;
  if Utc <= 0 then
  begin
    Message := Err;
    Exit(lprOfflineBlocked);
  end;

  if ValidateAgainstUtc(Key, User, Utc, Err) then
  begin
    if (MonotonicMs - GAnchorMonotonicMs) <= LicenseOfflineGraceMs then
      Exit(lprOfflineOk);
    Message := 'Connect to the internet to verify your license (offline grace exceeded).';
    Exit(lprOfflineBlocked);
  end;

  Message := Err;
  if LicenseCodecTryDecodePayload(Key, Payload, Err) and
     (LicenseCodecIsExpired(Payload, Utc) or not Payload.Active) then
    Exit(lprExpired);
  Result := lprInvalid;
end;

end.
