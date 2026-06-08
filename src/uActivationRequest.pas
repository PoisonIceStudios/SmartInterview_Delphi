unit uActivationRequest;

interface

uses
  System.SysUtils;

type
  TActivationRequestPayload = record
    F: string;
    U: string;
  end;

function ActivationRequestBuild(const ForumUsername: string): string;

function ActivationRequestTryParse(const Code: string;
  out Payload: TActivationRequestPayload; out ErrorMsg: string): Boolean;

implementation

uses
  System.JSON,
  System.NetEncoding,
  uMachineFingerprint,
  uLicenseCodec;

const
  RequestPrefix = 'RQ1';

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

function PayloadToJson(const Payload: TActivationRequestPayload): string;
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('F', Payload.F);
    Obj.AddPair('U', Payload.U);
    Result := Obj.ToJSON;
  finally
    Obj.Free;
  end;
end;

function JsonToPayload(const Json: string; out Payload: TActivationRequestPayload): Boolean;
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
    Result := True;
  finally
    Obj.Free;
  end;
end;

function ActivationRequestBuild(const ForumUsername: string): string;
var
  Payload: TActivationRequestPayload;
  Json: string;
  UserNorm: string;
begin
  UserNorm := LicenseNormalizeUsername(ForumUsername);
  if UserNorm = '' then
    raise EArgumentException.Create('Forum username is required.');

  Payload.F := MachineNormalizedRequestCode;
  Payload.U := UserNorm;
  Json := PayloadToJson(Payload);
  Result := RequestPrefix + '.' + Base64UrlEncode(TEncoding.UTF8.GetBytes(Json));
end;

function ActivationRequestTryParse(const Code: string;
  out Payload: TActivationRequestPayload; out ErrorMsg: string): Boolean;
var
  Trimmed, B64, Json: string;
  Normalized: string;
begin
  FillChar(Payload, SizeOf(Payload), 0);
  ErrorMsg := '';
  Result := False;

  if Trim(Code) = '' then
  begin
    ErrorMsg := 'Activation request is empty.';
    Exit;
  end;

  Trimmed := Trim(Code);
  if Trimmed.StartsWith(RequestPrefix + '.') then
  begin
    try
      B64 := Copy(Trimmed, Length(RequestPrefix) + 2, MaxInt);
      Json := TEncoding.UTF8.GetString(Base64UrlDecode(B64));
      if not JsonToPayload(Json, Payload) or (Trim(Payload.F) = '') or (Trim(Payload.U) = '') then
      begin
        ErrorMsg := 'Activation request payload is invalid.';
        Exit;
      end;
      Payload.F := MachineFingerprintNormalize(Payload.F);
      Payload.U := LicenseNormalizeUsername(Payload.U);
      if Length(Payload.F) <> 16 then
      begin
        ErrorMsg := 'Machine fingerprint in request is invalid.';
        Exit;
      end;
      Result := True;
    except
      on E: Exception do
      begin
        ErrorMsg := 'Activation request could not be read: ' + E.Message;
        Result := False;
      end;
    end;
    Exit;
  end;

  Normalized := MachineFingerprintNormalize(Trimmed);
  if Length(Normalized) = 16 then
  begin
    Payload.F := Normalized;
    Payload.U := '';
    Result := True;
    Exit;
  end;

  ErrorMsg := 'Activation request format is invalid.';
end;

end.
