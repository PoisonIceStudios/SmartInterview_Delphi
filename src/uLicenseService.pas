unit uLicenseService;

interface

uses
  System.SysUtils;

function LicenseMachineCode: string;
function LicenseIsValid: Boolean;
function LicenseBuildActivationRequest(const ForumUsername: string): string;
function LicenseTryActivate(const LicenseKey, ForumUsername: string; out ErrorMsg: string): Boolean;

procedure LicenseStoreSave(const LicenseKey, ForumUsername: string);
function LicenseStoreGet: string;
function LicenseStoreGetForumUsername: string;
procedure LicenseStoreClear;

implementation

uses
  uMachineFingerprint,
  uLicenseCodec,
  uActivationRequest,
  uRegistryStore;

const
  KeyName = 'LicenseKey';
  UserName = 'LicenseForumUser';

function LicenseStoreGet: string;
begin
  Result := RegistryGetString(KeyName);
end;

function LicenseStoreGetForumUsername: string;
begin
  Result := RegistryGetString(UserName);
end;

procedure LicenseStoreSave(const LicenseKey, ForumUsername: string);
begin
  RegistrySetString(KeyName, Trim(LicenseKey));
  RegistrySetString(UserName, LowerCase(Trim(ForumUsername)));
end;

procedure LicenseStoreClear;
begin
  RegistrySetString(KeyName, '');
  RegistrySetString(UserName, '');
end;

function LicenseMachineCode: string;
begin
  Result := MachineRequestCode;
end;

function LicenseIsValid: Boolean;
var
  Key, StoredUser: string;
  Payload: TLicensePayload;
  Err: string;
begin
  Key := LicenseStoreGet;
  if Trim(Key) = '' then
    Exit(False);
  StoredUser := LicenseStoreGetForumUsername;
  Result := LicenseCodecTryValidate(Key, StoredUser, Payload, Err);
end;

function LicenseBuildActivationRequest(const ForumUsername: string): string;
begin
  Result := ActivationRequestBuild(ForumUsername);
end;

function LicenseTryActivate(const LicenseKey, ForumUsername: string; out ErrorMsg: string): Boolean;
var
  Payload: TLicensePayload;
  User: string;
begin
  ErrorMsg := '';
  if Trim(ForumUsername) = '' then
  begin
    ErrorMsg := 'Enter your forum username.';
    Exit(False);
  end;

  if not LicenseCodecTryValidate(LicenseKey, ForumUsername, Payload, ErrorMsg) then
  begin
    if ErrorMsg = '' then
      ErrorMsg := 'License key is invalid.';
    Exit(False);
  end;

  if Payload.V >= 2 then
    User := Payload.U
  else
    User := LicenseNormalizeUsername(ForumUsername);

  if not RegistryTrySetString(KeyName, Trim(LicenseKey)) or
     not RegistryTrySetString(UserName, LowerCase(Trim(User))) then
  begin
    ErrorMsg := 'Could not save the license to the registry.';
    Exit(False);
  end;

  if not SameText(LicenseStoreGet, Trim(LicenseKey)) then
  begin
    ErrorMsg := 'License was written but could not be read back.';
    Exit(False);
  end;

  Result := True;
end;

end.
