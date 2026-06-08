unit uAppStartup;

interface

uses
  System.SysUtils,
  uPipeEngine,
  uAppSettings,
  uInterviewProfile;

type
  TStartupStatusProc = reference to procedure(const Status: string);

function IntelligenceDisplayLabel(const Level: TResponseIntelligence): string;
function TranscriptionDisplayLabel(const Level: TTranscriptionIntelligence): string;
function LangNameForCode(const Code: string): string;
function StartupProgressText(const Phase: string; const Level: TResponseIntelligence;
  const WhisperLevel: TTranscriptionIntelligence; Progress: Double): string;

function RunInitialStartup(const OnStatus: TStartupStatusProc): TPipeEngine;
function TakeStartupEngine: TPipeEngine;

implementation

uses
  System.Classes,
  System.Math,
  System.StrUtils,
  Winapi.Windows,
  uRegistryStore,
  uDebugLog;

var
  GStartupEngine: TPipeEngine;

type
  TStartupProgressBridge = class
  private
    FOnStatus: TStartupStatusProc;
    FLevel: TResponseIntelligence;
    FWhisperLevel: TTranscriptionIntelligence;
    FLastUpdate: Int64;
    procedure HandleProgress(Sender: TObject; const Phase: string; Progress: Double);
  public
    constructor Create(const OnStatus: TStartupStatusProc;
      Level: TResponseIntelligence; WhisperLevel: TTranscriptionIntelligence);
  end;

function LangNameForCode(const Code: string): string;
begin
  if SameText(Code, 'es') then Exit('Spanish');
  if SameText(Code, 'fr') then Exit('French');
  if SameText(Code, 'de') then Exit('German');
  if SameText(Code, 'it') then Exit('Italian');
  if SameText(Code, 'ru') then Exit('Russian');
  Result := 'English';
end;

function IntelligenceDisplayLabel(const Level: TResponseIntelligence): string;
begin
  case Level of
    riFast: Result := 'Fast';
    riMax: Result := 'Maximum accuracy';
  else
    Result := 'Balanced';
  end;
end;

function TranscriptionDisplayLabel(const Level: TTranscriptionIntelligence): string;
begin
  case Level of
    tiFast: Result := 'Fast';
    tiMax: Result := 'Maximum accuracy';
  else
    Result := 'Balanced';
  end;
end;

function StartupProgressText(const Phase: string; const Level: TResponseIntelligence;
  const WhisperLevel: TTranscriptionIntelligence; Progress: Double): string;
var
  P: string;
  LevelLabel, WhisperLabel: string;
begin
  LevelLabel := IntelligenceDisplayLabel(Level);
  WhisperLabel := TranscriptionDisplayLabel(WhisperLevel);
  P := LowerCase(Trim(Phase));
  if (P = 'whisper') or (P = 'voice_download') then
  begin
    if Progress >= 1.0 then
      Result := Format('Voice model (%s) ready', [WhisperLabel])
    else if Progress >= 0.99 then
      Result := Format('Verifying voice model (%s)... %d%%', [WhisperLabel,
        Min(99, Round((Progress - 0.99) / 0.01 * 100))])
    else if Progress >= 0 then
      Result := Format('Downloading voice model (%s)... %d%%', [WhisperLabel, Round(Progress * 100)])
    else
      Result := Format('Downloading voice model (%s)...', [WhisperLabel]);
    Exit;
  end;
  if (P = 'llm') or (P = 'text_download') then
  begin
    if Progress >= 0 then
      Result := Format('Downloading text model (%s)... %d%%', [LevelLabel, Round(Progress * 100)])
    else
      Result := Format('Downloading text model (%s)...', [LevelLabel]);
    Exit;
  end;
  if (P = 'voice_init') or (P = 'voice_warmup') then
    Exit(Format('Initializing voice model (%s)...', [WhisperLabel]));
  if (P = 'text_init') or (P = 'text_warmup') then
    Exit(Format('Initializing text model (%s)...', [LevelLabel]));
  if Progress >= 0 then
    Result := Format('Preparing... %d%%', [Round(Progress * 100)])
  else
    Result := 'Preparing...';
end;

constructor TStartupProgressBridge.Create(const OnStatus: TStartupStatusProc;
  Level: TResponseIntelligence; WhisperLevel: TTranscriptionIntelligence);
begin
  inherited Create;
  FOnStatus := OnStatus;
  FLevel := Level;
  FWhisperLevel := WhisperLevel;
  FLastUpdate := 0;
end;

procedure TStartupProgressBridge.HandleProgress(Sender: TObject; const Phase: string;
  Progress: Double);
var
  NowTick: Int64;
  Text: string;
begin
  NowTick := Int64(GetTickCount64);
  if (Progress >= 0) and (Progress < 1.0) and (FLastUpdate > 0) and (NowTick - FLastUpdate < 120) then
    Exit;
  FLastUpdate := NowTick;
  Text := StartupProgressText(Phase, FLevel, FWhisperLevel, Progress);
  if Assigned(FOnStatus) then
    FOnStatus(Text);
end;

function UserFacingStartupError(const Detail: string): string;
begin
  if (Pos(':\', Detail) > 0) or (Pos('\\', Detail) > 0) or
     ContainsText(Detail, 'Projects') or ContainsText(Detail, 'EngineDeploy') or
     ContainsText(Detail, 'Win64') or ContainsText(Detail, '.csproj') or
     ContainsText(Detail, 'dotnet') or ContainsText(Detail, 'net10.0') then
  begin
    DebugLogWrite('[Startup] suppressed detail: ' + Detail);
    Result := 'Startup failed. Restart the application or reinstall.';
  end
  else
    Result := Detail;
end;

function RunInitialStartup(const OnStatus: TStartupStatusProc): TPipeEngine;
var
  Engine: TPipeEngine;
  Profile: TInterviewProfile;
  LangCode, LangName, Err: string;
  Level: TResponseIntelligence;
  WhisperLevel: TTranscriptionIntelligence;
  AnswerLen: TAnswerLength;
  Bridge: TStartupProgressBridge;
begin
  if GStartupEngine <> nil then
    Exit(GStartupEngine);

  Level := GetResponseIntelligence;
  WhisperLevel := GetTranscriptionIntelligence;
  AnswerLen := GetAnswerLength;
  Profile := ProfileLoad;
  LangCode := RegistryGetString('Language');
  if LangCode.IsEmpty then
    LangCode := 'en';
  LangName := LangNameForCode(LangCode);

  Engine := TPipeEngine.Create;
  Bridge := TStartupProgressBridge.Create(OnStatus, Level, WhisperLevel);
  try
    try
      if Assigned(OnStatus) then
        OnStatus('Starting engine...');
      if not Engine.Start then
      begin
        if Engine.LastError <> '' then
          raise Exception.Create(Engine.LastError)
        else
          raise Exception.Create(EngineErrStartFailed);
      end;

      if Assigned(OnStatus) then
        OnStatus('Connecting...');
      if not Engine.Ping then
        raise Exception.Create(EngineErrNoResponse);

      if Assigned(OnStatus) then
        OnStatus('Preparing models...');
      if Engine.Startup(LangCode, LangName, Level, WhisperLevel, Profile.Role, Profile.TechStack,
        Profile.JobDescription, Profile.Experience, AnswerLen, Bridge.HandleProgress, Err) then
      begin
        DebugLogWrite(Format('[LOAD] ready=true (batch startup) gpu_layers=%d',
          [Engine.GpuLayerCount]));
        if Engine.GpuLayerCount = 0 then
          DebugLogWrite('[LOAD] WARNING: gpu_layers=0 - model running on CPU only');
      end
      else
      begin
        DebugLogWrite('[LOAD] batch startup failed: ' + Err);
        if Assigned(OnStatus) then
          OnStatus('Preparing models...');
        if not Engine.StartupLegacy(LangCode, LangName, Level, WhisperLevel, Profile.Role, Profile.TechStack,
          Profile.JobDescription, Profile.Experience, AnswerLen, Bridge.HandleProgress, Err) then
        begin
          DebugLogWrite('[LOAD] legacy startup failed: ' + Err);
          raise Exception.Create(UserFacingStartupError(Err));
        end;
        DebugLogWrite('[LOAD] ready=true (legacy startup)');
      end;

      GStartupEngine := Engine;
      Engine := nil;
      Result := GStartupEngine;
    except
      on E: Exception do
      begin
        if Assigned(Engine) then
        begin
          Engine.OnProgress := nil;
          FreeAndNil(Engine);
        end;
        raise;
      end;
    end;
  finally
    if Assigned(Engine) then
    begin
      Engine.OnProgress := nil;
      FreeAndNil(Engine);
    end;
    if GStartupEngine <> nil then
      GStartupEngine.OnProgress := nil;
    Bridge.Free;
  end;
end;

function TakeStartupEngine: TPipeEngine;
begin
  Result := GStartupEngine;
  GStartupEngine := nil;
end;

initialization

finalization
  FreeAndNil(GStartupEngine);

end.
