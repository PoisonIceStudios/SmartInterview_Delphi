unit uLicenseService;

interface

uses
  System.SysUtils,
  uLicenseMonitor;

function LicenseIsValid: Boolean;
function LicenseBuildSessionToken: string;
function LicenseTryActivate(const LicenseKey, ForumUsername: string; out ErrorMsg: string): Boolean;
function LicenseLastCheckError: string;
function LicensePeriodicRevalidate(out ErrorMsg: string): TLicensePeriodicResult;

procedure LicenseStoreSave(const LicenseKey, ForumUsername: string);
function LicenseStoreGet: string;
function LicenseStoreGetForumUsername: string;
procedure LicenseStoreClear;

implementation

uses
  uLicenseCodec,
  uLicenseOnlineTime,
  uRegistryStore,
  uSessionAuth;

const
  KeyName = 'LicenseKey';
  UserName = 'LicenseForumUser';

var
  GLastCheckError: string;

function LicenseLastCheckError: string;
begin
  Result := GLastCheckError;
end;

function LicenseStoreGet: string;
begin
  Result := RegistryGetString(KeyName);
end;

function LicenseStoreGetForumUsername: string;
var
  Raw: string;
begin
  Raw := RegistryGetString(UserName);
  Result := LicenseNormalizeUsername(Raw);
  if (Result <> '') and (Result <> Raw) then
    RegistrySetString(UserName, Result);
end;

procedure LicenseStoreSave(const LicenseKey, ForumUsername: string);
begin
  RegistrySetString(KeyName, Trim(LicenseKey));
  RegistrySetString(UserName, LicenseNormalizeUsername(ForumUsername));
end;

procedure LicenseStoreClear;
begin
  RegistrySetString(KeyName, '');
  RegistrySetString(UserName, '');
end;

function LicenseIsValid: Boolean;
var
  Key, StoredUser, Err: string;
  Utc: TDateTime;
  Payload: TLicensePayload;
begin
  GLastCheckError := '';
  Result := False;
  Key := LicenseStoreGet;
  if Trim(Key) = '' then
    Exit;

  StoredUser := LicenseStoreGetForumUsername;

  // Decode offline first. The signature is verified offline; the online clock is only
  // needed to enforce an *expiry date*. A decode failure means the key is genuinely bad.
  if not LicenseCodecTryDecodePayload(Key, Payload, Err) then
  begin
    GLastCheckError := Err;
    Exit;
  end;

  // Lifetime licenses never expire → validate fully offline (no time server, no freeze,
  // no false negative when worldtimeapi/timeapi are unreachable).
  if Payload.Lifetime then
  begin
    if not LicenseCodecTryValidate(Key, StoredUser, Now, Err) then
    begin
      GLastCheckError := Err;
      if not Payload.Active then
        LicenseStoreClear;
      Exit;
    end;
    Result := True;
    Exit;
  end;

  // Time-limited licenses need a trusted UTC to check the expiry date.
  if not TryFetchUtcNow(Utc, Err) then
  begin
    GLastCheckError := Err;
    Exit;
  end;

  if not LicenseCodecTryValidate(Key, StoredUser, Utc, Err) then
  begin
    GLastCheckError := Err;
    // Only wipe stored keys when the payload itself is expired/deactivated — not on
    // transient network/signature glitches.
    if LicenseCodecIsExpired(Payload, Utc) or not Payload.Active then
      LicenseStoreClear;
    Exit;
  end;

  LicenseMonitorNoteOnlineSuccess(Utc);
  LicenseMonitorPersistAnchor(Utc, StoredUser, Key);
  Result := True;
end;

function LicensePeriodicRevalidate(out ErrorMsg: string): TLicensePeriodicResult;
begin
  Result := LicenseMonitorPeriodicCheck(ErrorMsg);
end;

function LicenseBuildSessionToken: string;
begin
  if not LicenseIsValid then
    raise Exception.Create('License is not valid.');
  Result := SessionBuildToken(LicenseStoreGetForumUsername, LicenseStoreGet);
end;

function LicenseTryActivate(const LicenseKey, ForumUsername: string; out ErrorMsg: string): Boolean;
var
  User, Err: string;
  Utc: TDateTime;
  Payload: TLicensePayload;
  IsLifetime: Boolean;
begin
  ErrorMsg := '';
  GLastCheckError := '';

  // Decode offline to learn whether this is a lifetime key.
  if not LicenseCodecTryDecodePayload(LicenseKey, Payload, ErrorMsg) then
  begin
    if ErrorMsg = '' then
      ErrorMsg := 'License key is invalid.';
    Exit(False);
  end;
  IsLifetime := Payload.Lifetime;

  if IsLifetime then
  begin
    // Lifetime: validate offline. Activation no longer depends on a public time server,
    // so pressing Activate can never freeze on a dead HTTP endpoint.
    Utc := Now;
    if not LicenseCodecTryValidate(LicenseKey, ForumUsername, Utc, ErrorMsg) then
    begin
      if ErrorMsg = '' then
        ErrorMsg := 'License key is invalid.';
      Exit(False);
    end;
  end
  else
  begin
    if not TryFetchUtcNow(Utc, Err) then
    begin
      ErrorMsg := Err;
      Exit(False);
    end;
    if not LicenseCodecTryValidate(LicenseKey, ForumUsername, Utc, ErrorMsg) then
    begin
      if ErrorMsg = '' then
        ErrorMsg := 'License key is invalid.';
      Exit(False);
    end;
  end;

  User := LicenseNormalizeUsername(ForumUsername);

  if not RegistryTrySetString(KeyName, Trim(LicenseKey)) or
     not RegistryTrySetString(UserName, User) then
  begin
    ErrorMsg := 'Could not save the license to the registry.';
    Exit(False);
  end;

  if not SameText(LicenseStoreGet, Trim(LicenseKey)) then
  begin
    ErrorMsg := 'License was written but could not be read back.';
    Exit(False);
  end;

  // Persist the offline-grace anchor only for time-limited keys (lifetime never needs it).
  if not IsLifetime then
  begin
    LicenseMonitorNoteOnlineSuccess(Utc);
    LicenseMonitorPersistAnchor(Utc, User, Trim(LicenseKey));
  end;
  Result := True;
end;

end.
