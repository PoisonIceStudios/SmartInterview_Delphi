unit uDebugLog;

interface

procedure DebugLogWrite(const Message: string);
function DebugLogFilePath: string;

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
    Result := TPath.Combine(Dir, 'debug.log');
  except
    Result := TPath.Combine(TPath.GetTempPath, 'SmartInterview-debug.log');
  end;
end;

function DebugLogFilePath: string;
begin
  if not GPathReady then
  begin
    GPath := BuildPath;
    GPathReady := True;
  end;
  Result := GPath;
end;

procedure DebugLogWrite(const Message: string);
begin
{$IFDEF DIAGNOSTIC_LOG}
  try
    GLock.Enter;
    try
      TFile.AppendAllText(DebugLogFilePath,
        FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + Message + sLineBreak);
    finally
      GLock.Leave;
    end;
  except
  end;
{$ENDIF}
end;

initialization
  GLock := TCriticalSection.Create;

finalization
  GLock.Free;

end.
