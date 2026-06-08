unit uLicenseOnlineTime;

interface

uses
  System.SysUtils;

function TryFetchUtcNow(out UtcNow: TDateTime; out ErrorMsg: string): Boolean;

implementation

uses
  System.Classes,
  System.JSON,
  System.Net.HttpClient,
  System.DateUtils;

const
  OfflineMsg =
    'An internet connection is required to verify your license. ' +
    'Connect to the internet and try again.';

function TryParseWorldTimeApi(const JsonText: string; out UtcNow: TDateTime): Boolean;
var
  Root, DtVal: TJSONValue;
begin
  Result := False;
  Root := TJSONObject.ParseJSONValue(JsonText);
  if Root = nil then
    Exit;
  try
    if not (Root is TJSONObject) then
      Exit;
    DtVal := TJSONObject(Root).GetValue('datetime');
    if DtVal = nil then
      Exit;
    Result := TryISO8601ToDate(DtVal.Value, UtcNow, True);
  finally
    Root.Free;
  end;
end;

function TryParseTimeApiIo(const JsonText: string; out UtcNow: TDateTime): Boolean;
var
  Root, DtVal: TJSONValue;
  DtStr: string;
  Parts: TArray<string>;
begin
  Result := False;
  Root := TJSONObject.ParseJSONValue(JsonText);
  if Root = nil then
    Exit;
  try
    if not (Root is TJSONObject) then
      Exit;
    DtVal := TJSONObject(Root).GetValue('dateTime');
    if DtVal = nil then
      Exit;
    DtStr := DtVal.Value;
    Parts := DtStr.Split(['T']);
    if Length(Parts) < 2 then
      Exit;
    Result := TryISO8601ToDate(Parts[0] + 'T' + Copy(Parts[1], 1, 8) + 'Z', UtcNow, True);
  finally
    Root.Free;
  end;
end;

function TryGetUtcFromUrl(const Url: string; ParserKind: Integer; out UtcNow: TDateTime;
  out ErrorMsg: string): Boolean;
var
  Client: THTTPClient;
  Resp: IHTTPResponse;
  Body: string;
begin
  Result := False;
  ErrorMsg := '';
  Client := THTTPClient.Create;
  try
    Client.ConnectionTimeout := 8000;
    Client.ResponseTimeout := 8000;
    Resp := Client.Get(Url);
    if Resp.StatusCode <> 200 then
    begin
      ErrorMsg := Format('Time server returned HTTP %d.', [Resp.StatusCode]);
      Exit;
    end;
    Body := Resp.ContentAsString(TEncoding.UTF8);
    if ParserKind = 1 then
      Result := TryParseWorldTimeApi(Body, UtcNow)
    else
      Result := TryParseTimeApiIo(Body, UtcNow);
    if not Result then
      ErrorMsg := 'Could not parse time server response.';
  except
    on E: Exception do
      ErrorMsg := E.Message;
  end;
  Client.Free;
end;

function TryFetchUtcNow(out UtcNow: TDateTime; out ErrorMsg: string): Boolean;
begin
  if TryGetUtcFromUrl('https://worldtimeapi.org/api/timezone/Etc/UTC', 1, UtcNow, ErrorMsg) then
    Exit(True);

  if TryGetUtcFromUrl('https://timeapi.io/api/Time/current/zone?timeZone=UTC', 2, UtcNow, ErrorMsg) then
    Exit(True);

  ErrorMsg := OfflineMsg;
  Result := False;
end;

end.
