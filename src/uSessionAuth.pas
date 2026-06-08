unit uSessionAuth;

interface

uses
  Winapi.Windows,
  System.SysUtils;

const
  SessionEnvVar = 'SMARTINTERVIEW_SESSION';
  LicenseEnvVar = 'SMARTINTERVIEW_LICENSE';
  UserEnvVar = 'SMARTINTERVIEW_USER';
  SessionTokenPrefix = 'SI_SESSION';
  SessionTokenVersion = 'v2';
  SessionValiditySeconds = 86400;

function SessionBuildToken(const ForumUsername, LicenseKey: string): string;
function SessionBuildChildEnvironment(const SessionToken, LicenseKey, ForumUsername: string): PChar;

implementation

uses
  System.DateUtils,
  System.Hash,
  System.NetEncoding,
  System.Classes,
  uLicenseCodec;

const
  SessionHmacSecret = 'SmartInterview|EngineSession|v2|hmac';

function Base64UrlEncode(const Data: TBytes): string;
begin
  Result := TNetEncoding.Base64.EncodeBytesToString(Data);
  Result := Result.Replace('+', '-').Replace('/', '_');
  while Result.EndsWith('=') do
    SetLength(Result, Length(Result) - 1);
end;

function HmacSha256(const Message, Key: TBytes): TBytes;
begin
  Result := THashSHA2.GetHMACAsBytes(Message, Key, THashSHA2.TSHA2Version.SHA256);
end;

function SessionBuildToken(const ForumUsername, LicenseKey: string): string;
var
  Expiry: Int64;
  Payload, UserNorm, UserB64: string;
  Sig: TBytes;
  KeyBytes, MsgBytes: TBytes;
begin
  UserNorm := LicenseNormalizeUsername(ForumUsername);
  if UserNorm = '' then
    raise EArgumentException.Create('Forum username is required for session token.');
  if Trim(LicenseKey) = '' then
    raise EArgumentException.Create('License key is required for session token.');

  Expiry := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False) + SessionValiditySeconds;
  Payload := UserNorm + '|' + LicenseKey + '|' + IntToStr(Expiry);
  KeyBytes := TEncoding.UTF8.GetBytes(SessionHmacSecret);
  MsgBytes := TEncoding.UTF8.GetBytes(Payload);
  Sig := HmacSha256(MsgBytes, KeyBytes);
  UserB64 := Base64UrlEncode(TEncoding.UTF8.GetBytes(UserNorm));
  Result := Format('%s.%s.%d.%s.%s',
    [SessionTokenPrefix, SessionTokenVersion, Expiry, UserB64, Base64UrlEncode(Sig)]);
end;

procedure AppendEnvString(var Block: TBytes; const S: string);
var
  Utf16: TBytes;
  OldLen: Integer;
begin
  Utf16 := TEncoding.Unicode.GetBytes(S + #0);
  OldLen := Length(Block);
  SetLength(Block, OldLen + Length(Utf16));
  if Length(Utf16) > 0 then
    Move(Utf16[0], Block[OldLen], Length(Utf16));
end;

function SessionBuildChildEnvironment(const SessionToken, LicenseKey, ForumUsername: string): PChar;
var
  Cur, P: PChar;
  Block: TBytes;
  Pair: string;
  UserNorm: string;
begin
  SetLength(Block, 0);
  UserNorm := LicenseNormalizeUsername(ForumUsername);
  Cur := GetEnvironmentStringsW;
  if Cur <> nil then
  try
    P := Cur;
    while P^ <> #0 do
    begin
      Pair := string(P);
      if (not Pair.StartsWith(SessionEnvVar + '=', True)) and
         (not Pair.StartsWith(LicenseEnvVar + '=', True)) and
         (not Pair.StartsWith(UserEnvVar + '=', True)) then
        AppendEnvString(Block, Pair);
      Inc(P, Length(P) + 1);
    end;
  finally
    FreeEnvironmentStringsW(Cur);
  end;

  AppendEnvString(Block, SessionEnvVar + '=' + SessionToken);
  AppendEnvString(Block, LicenseEnvVar + '=' + LicenseKey);
  AppendEnvString(Block, UserEnvVar + '=' + UserNorm);
  AppendEnvString(Block, '');

  GetMem(Result, Length(Block));
  if Length(Block) > 0 then
    Move(Block[0], Result^, Length(Block))
  else
    Result^ := #0;
end;

end.
