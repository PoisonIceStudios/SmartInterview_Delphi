unit uLiveTransDiag;

interface

procedure LiveTransDiagClear;
procedure LiveTransDiagWrite(const Message: string);
function LiveTransDiagPath: string;
function LiveTransDiagSanitize(const Text: string; MaxLen: Integer = 600): string;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.SyncObjs,
  Winapi.ShlObj,
  Winapi.Windows;

var
  GLock: TCriticalSection;
  GPath: string;
  GPathReady: Boolean;

function BuildPath: string;
var
  Dir: string;
  PathBuf: array[0..MAX_PATH] of Char;
begin
  try
    if SHGetFolderPath(0, CSIDL_LOCAL_APPDATA, 0, 0, PathBuf) = S_OK then
      Dir := IncludeTrailingPathDelimiter(string(PathBuf)) + 'SmartInterview'
    else
      Dir := TPath.Combine(TPath.GetTempPath, 'SmartInterview');
    ForceDirectories(Dir);
    Result := TPath.Combine(Dir, 'live-transcribe-diag.log');
  except
    Result := TPath.Combine(TPath.GetTempPath, 'SmartInterview-live-transcribe-diag.log');
  end;
end;

function LiveTransDiagPath: string;
begin
  if not GPathReady then
  begin
    GPath := BuildPath;
    GPathReady := True;
  end;
  Result := GPath;
end;

function LiveTransDiagSanitize(const Text: string; MaxLen: Integer): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Text.Length do
  begin
    C := Text[I];
    if (C >= ' ') or (C = #9) then
      Result := Result + C
    else if (C = #13) or (C = #10) then
      Result := Result + ' ';
  end;
  Result := Result.Trim;
  if (MaxLen > 0) and (Result.Length > MaxLen) then
    Result := Copy(Result, 1, MaxLen) + '...';
end;

procedure LiveTransDiagClear;
var
  Header: string;
begin
  try
    GLock.Enter;
    try
      Header := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) +
        '  --- live transcription diag ---' + sLineBreak + sLineBreak;
      TFile.WriteAllText(LiveTransDiagPath, Header, TEncoding.UTF8);
    finally
      GLock.Leave;
    end;
  except
  end;
end;

procedure LiveTransDiagWrite(const Message: string);
var
  Line: string;
begin
  try
    GLock.Enter;
    try
      Line := FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + Message + sLineBreak;
      TFile.AppendAllText(LiveTransDiagPath, Line, TEncoding.UTF8);
    finally
      GLock.Leave;
    end;
  except
  end;
end;

initialization
  GLock := TCriticalSection.Create;

finalization
  GLock.Free;

end.
