unit uAppPaths;

interface

function ModelsDir: string;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Winapi.ShlObj,
  Winapi.Windows;

const
  KnownModelFiles: array[0..3] of string = (
    'ggml-small.bin',
    'response-balanced.bin',
    'response-fast.bin',
    'response-max.bin'
  );

var
  GModelsDir: string;
  GModelsDirResolved: Boolean;

function GetLocalAppData: string;
var
  Path: array[0..MAX_PATH] of Char;
begin
  if SHGetFolderPath(0, CSIDL_LOCAL_APPDATA, 0, 0, Path) = S_OK then
    Result := IncludeTrailingPathDelimiter(string(Path))
  else
    Result := IncludeTrailingPathDelimiter(TPath.GetTempPath);
end;

function TryEnsureWritable(const Dir: string): Boolean;
var
  Probe: string;
begin
  Result := False;
  try
    ForceDirectories(Dir);
    Probe := TPath.Combine(Dir, '.writetest');
    TFile.WriteAllText(Probe, '');
    TFile.Delete(Probe);
    Result := True;
  except
    Result := False;
  end;
end;

function HasExistingModels(const Dir: string): Boolean;
var
  Name: string;
begin
  Result := False;
  if not DirectoryExists(Dir) then
    Exit;
  for Name in KnownModelFiles do
    if TFile.Exists(TPath.Combine(Dir, Name)) then
      Exit(True);
end;

function TryHostModelsDir: string;
var
  BaseDir, Parent, Sibling, FromEnv: string;
begin
  Result := '';
  FromEnv := GetEnvironmentVariable('SMARTINTERVIEW_MODELS_DIR');
  if (FromEnv <> '') and HasExistingModels(FromEnv) then
    Exit(TPath.GetFullPath(FromEnv));

  BaseDir := TPath.GetFullPath(ExtractFilePath(ParamStr(0)));
  if SameText(TPath.GetFileName(ExcludeTrailingPathDelimiter(BaseDir)), 'EngineDeploy') then
  begin
    Parent := TPath.GetDirectoryName(ExcludeTrailingPathDelimiter(BaseDir));
    if Parent <> '' then
    begin
      Sibling := TPath.Combine(Parent, 'models');
      if HasExistingModels(Sibling) then
        Exit(Sibling);
    end;
  end;
end;

function ResolveModelsDir: string;
var
  Host, Beside: string;
begin
  Host := TryHostModelsDir;
  if (Host <> '') and TryEnsureWritable(Host) then
    Exit(Host);

  try
    Beside := TPath.Combine(ExtractFilePath(ParamStr(0)), 'models');
    if TryEnsureWritable(Beside) then
      Exit(Beside);
  except
  end;

  Result := TPath.Combine(TPath.Combine(GetLocalAppData, 'SmartInterview'), 'models');
  ForceDirectories(Result);
end;

function ModelsDir: string;
begin
  if not GModelsDirResolved then
  begin
    GModelsDir := ResolveModelsDir;
    GModelsDirResolved := True;
  end;
  Result := GModelsDir;
end;

end.
