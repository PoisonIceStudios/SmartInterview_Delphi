unit uPipeEngine;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.JSON,
  System.Generics.Collections,
  uAppSettings;

const
  GpuLayersUnknown = -999;
  GpuLayersAll = -1;
  EngineErrMissing = 'The AI engine is missing. Reinstall the application.';
  EngineErrStartFailed = 'Could not start the AI engine. Reinstall the application.';
  EngineErrNoResponse = 'The AI engine did not respond. Restart the application.';

type
  TPipeProgressEvent = procedure(Sender: TObject; const Phase: string; Progress: Double) of object;
  TPipeTokenEvent = procedure(Sender: TObject; const Token: string) of object;
  TPipeTranscribePartEvent = procedure(Sender: TObject; const Part: string) of object;

  TPipeEngine = class
  private
    FProcessInfo: TProcessInformation;
    FStdInWrite: THandle;
    FStdOutRead: THandle;
    FReaderThread: TThread;
    FSendLock: TCriticalSection;
    FStreamCancel: TEvent;
    FNextId: Integer;
    FRunning: Boolean;
    FGpuLayers: Integer;
    FGpuLoaded: Boolean;
    FLastError: string;
    FContextUsed: Integer;
    FContextMax: Integer;
    FContextBaseline: Integer;
    FContextPct: Integer;
    FOnProgress: TPipeProgressEvent;
    FOnToken: TPipeTokenEvent;
    FOnTranscribePart: TPipeTranscribePartEvent;
    FSessionToken: string;
    FReadBuf: TBytes;
    FReadBufLen: Integer;
    procedure EnsureReadCapacity(Need: Integer);
    function FindEngineExe: string;
    function FindEngineDll: string;
    function IsProcessAlive: Boolean;
    function SendLine(const Json: string): Boolean;
    function ReadLine(out Line: string): Boolean;
    procedure ReaderLoop;
    procedure ClearAllPending;
    function WaitResult(const Id: Integer; TimeoutMs: Cardinal; CancelEvt: TEvent;
      out ResultObj: TJSONObject): Boolean;
    function SendAndWait(const BuildJson: TFunc<Integer, string>; TimeoutMs: Cardinal;
      CancelEvt: TEvent; out Obj: TJSONObject): Boolean;
    procedure ApplyContextFromObj(Obj: TJSONObject);
    // Marshal an engine event to the main thread. The values are passed BY PARAMETER (not
    // captured from ReaderLoop locals) so each queued closure owns its own copy — otherwise
    // the reader thread overwrites the shared captured variable while a still-pending closure
    // reads it, tearing the managed string's refcount and crashing with an access violation
    // (seen mid-download when progress events fire rapidly).
    procedure DispatchProgress(const Phase: string; Progress: Double);
    procedure DispatchToken(const Token: string);
    procedure DispatchTranscribePart(const Part: string);
  public
    constructor Create;
    destructor Destroy; override;
    function Start: Boolean;
    procedure Stop;
    procedure CancelGeneration;
    function Ping: Boolean;
    function Startup(const LangCode, LangName: string; Level: TResponseIntelligence;
      WhisperLevel: TTranscriptionIntelligence;
      const Role, TechStack, JobDesc, Experience: string; AnswerLen: TAnswerLength;
      OnProgress: TPipeProgressEvent; out ErrorMsg: string): Boolean;
    function StartupLegacy(const LangCode, LangName: string; Level: TResponseIntelligence;
      WhisperLevel: TTranscriptionIntelligence;
      const Role, TechStack, JobDesc, Experience: string; AnswerLen: TAnswerLength;
      OnProgress: TPipeProgressEvent; out ErrorMsg: string): Boolean;
    function EnsureWhisper(Level: TTranscriptionIntelligence;
      OnProgress: TPipeProgressEvent = nil): Boolean;
    function LoadWhisper(Level: TTranscriptionIntelligence): Boolean;
    procedure CancelTranscribe;
    procedure CancelTranscribeAsync;
    function WarmupWhisper: Boolean;
    function Transcribe(const Samples: TArray<Single>; out Text: string): Boolean;
    function TranscribeStream(const Samples: TArray<Single>; OnPart: TPipeTranscribePartEvent;
      out Text: string; ALive: Boolean = False): Boolean;
    function ClassifyUtterance(const Text: string; out Answerable: Boolean): Boolean;
    function SetLanguage(const LangCode, LangName: string): Boolean;
    function EnsureModel(Level: TResponseIntelligence; OnProgress: TPipeProgressEvent = nil): Boolean;
    function LoadLlm(Level: TResponseIntelligence): Boolean;
    function WarmupLlm: Boolean;
    function SetProfile(const Role, TechStack, JobDesc, Experience: string): Boolean;
    function SetAnswerLength(AnswerLen: TAnswerLength): Boolean;
    function ResetConversation: Boolean;
    function DropLastExchange: Boolean;
    function GenerateStream(const Question: string; OnToken: TPipeTokenEvent): Boolean;
    function RefreshGpuLayerCount: Boolean;
    function GpuLoadStatusText: string;
    function QueryChatContext(out UsedTokens, MaxTokens: Integer): Boolean;
    property OnProgress: TPipeProgressEvent read FOnProgress write FOnProgress;
    property OnToken: TPipeTokenEvent read FOnToken write FOnToken;
    property Running: Boolean read FRunning;
    property GpuLayerCount: Integer read FGpuLayers;
    property LastError: string read FLastError;
    property ChatUsedTokens: Integer read FContextUsed;
    property ChatMaxTokens: Integer read FContextMax;
    property ChatBaselineTokens: Integer read FContextBaseline;
    property ChatFillPercent: Integer read FContextPct;
  end;

implementation

uses
  System.IOUtils,
  System.Math,
  System.NetEncoding,
  uAppPaths,
  uDebugLog,
  uLicenseService,
  uSessionAuth;

const
  EngineHostExeName = 'SmartInterview.Engine.exe';
  EngineHostDllName = 'SmartInterview.Engine.dll';
  CREATE_UNICODE_ENVIRONMENT = $00000400;

type
  TPipeReaderThread = class(TThread)
  private
    FOwner: TPipeEngine;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TPipeEngine);
  end;

  TPipeThreadInvoker = class
  strict private
    FProc: TProc;
  public
    constructor Create(const AProc: TProc);
    procedure Invoke;
    class procedure QueueMain(const AProc: TProc);
  end;

var
  GPendingResults: TDictionary<Integer, TJSONObject>;
  GPendingLock: TCriticalSection;
  GPendingEvent: TEvent;

procedure EnsurePending;
begin
  if GPendingLock = nil then
  begin
    GPendingLock := TCriticalSection.Create;
    GPendingResults := TDictionary<Integer, TJSONObject>.Create;
    GPendingEvent := TEvent.Create(nil, False, False, '');
  end;
end;

procedure SignalPending;
begin
  EnsurePending;
  GPendingEvent.SetEvent;
end;

procedure FailPendingId(const Id: Integer; const ErrMsg: string);
var
  FailObj, Old: TJSONObject;
begin
  EnsurePending;
  FailObj := TJSONObject.Create;
  FailObj.AddPair('ok', TJSONBool.Create(False));
  FailObj.AddPair('error', ErrMsg);
  GPendingLock.Enter;
  try
    if GPendingResults.TryGetValue(Id, Old) then
    begin
      GPendingResults.Remove(Id);
      Old.Free;
    end;
    GPendingResults.Add(Id, FailObj);
  finally
    GPendingLock.Leave;
  end;
  SignalPending;
end;

procedure FailAllPending(const ErrMsg: string);
var
  Ids: TArray<Integer>;
  I: Integer;
  Pair: TPair<Integer, TJSONObject>;
begin
  EnsurePending;
  GPendingLock.Enter;
  try
    SetLength(Ids, GPendingResults.Count);
    I := 0;
    for Pair in GPendingResults do
    begin
      Ids[I] := Pair.Key;
      Inc(I);
    end;
  finally
    GPendingLock.Leave;
  end;
  for I := 0 to High(Ids) do
    FailPendingId(Ids[I], ErrMsg);
end;

procedure RemovePendingId(const Id: Integer);
var
  Obj: TJSONObject;
begin
  EnsurePending;
  GPendingLock.Enter;
  try
    if GPendingResults.TryGetValue(Id, Obj) then
    begin
      GPendingResults.Remove(Id);
      Obj.Free;
    end;
  finally
    GPendingLock.Leave;
  end;
end;

constructor TPipeThreadInvoker.Create(const AProc: TProc);
begin
  inherited Create;
  FProc := AProc;
end;

procedure TPipeThreadInvoker.Invoke;
begin
  try
    if Assigned(FProc) then
      FProc();
  finally
    Free;
  end;
end;

class procedure TPipeThreadInvoker.QueueMain(const AProc: TProc);
var
  Invoker: TPipeThreadInvoker;
begin
  Invoker := TPipeThreadInvoker.Create(AProc);
  TThread.Queue(nil, Invoker.Invoke);
end;

constructor TPipeReaderThread.Create(AOwner: TPipeEngine);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  Priority := tpHigher;
  FOwner := AOwner;
end;

procedure TPipeReaderThread.Execute;
begin
  FOwner.ReaderLoop;
end;

constructor TPipeEngine.Create;
begin
  inherited;
  FGpuLayers := GpuLayersUnknown;
  FGpuLoaded := False;
  FContextUsed := 0;
  FContextMax := 8192;
  FContextBaseline := 0;
  FContextPct := 0;
  FSendLock := TCriticalSection.Create;
  FStreamCancel := TEvent.Create(nil, True, False, '');
  FNextId := 1;
  FillChar(FProcessInfo, SizeOf(FProcessInfo), 0);
  FStdInWrite := 0;
  FStdOutRead := 0;
end;

destructor TPipeEngine.Destroy;
begin
  Stop;
  FStreamCancel.Free;
  FSendLock.Free;
  inherited;
end;

function TPipeEngine.IsProcessAlive: Boolean;
var
  Code: DWORD;
begin
  Result := False;
  if FProcessInfo.hProcess = 0 then
    Exit;
  if GetExitCodeProcess(FProcessInfo.hProcess, Code) and (Code = STILL_ACTIVE) then
    Result := True;
end;

function TPipeEngine.FindEngineExe: string;
begin
  Result := TPath.Combine(EngineDeployDir, EngineHostExeName);
end;

function TPipeEngine.FindEngineDll: string;
begin
  Result := TPath.Combine(EngineDeployDir, EngineHostDllName);
end;

function TPipeEngine.Start: Boolean;
var
  Exe, Dll, WorkDir, CmdLine, AppName, LicenseKey: string;
  SI: TStartupInfo;
  SecAttr: TSecurityAttributes;
  StdInRead, StdOutWrite: THandle;
  ChildEnv: PChar;
  WinErr: DWORD;
  Created: Boolean;
  CreationFlags: DWORD;
begin
  Result := False;
  FLastError := '';
  if FRunning then
    Exit(True);
  FSessionToken := LicenseBuildSessionToken;
  LicenseKey := LicenseStoreGet;
  ChildEnv := SessionBuildChildEnvironment(FSessionToken, LicenseKey, LicenseStoreGetForumUsername);
  try
    Exe := FindEngineExe;
    if FileExists(Exe) then
    begin
      AppName := Exe;
      CmdLine := '"' + Exe + '"';
      WorkDir := EngineDeployDir;
    end
    else
    begin
      Dll := FindEngineDll;
      if not FileExists(Dll) then
        raise Exception.Create(EngineErrMissing);
      AppName := '';
      CmdLine := 'dotnet "' + Dll + '"';
      WorkDir := EngineDeployDir;
    end;

    SecAttr.nLength := SizeOf(SecAttr);
    SecAttr.bInheritHandle := True;
    SecAttr.lpSecurityDescriptor := nil;

    if not CreatePipe(StdInRead, FStdInWrite, @SecAttr, 0) then
    begin
      FLastError := EngineErrStartFailed;
      Exit;
    end;
    if not CreatePipe(FStdOutRead, StdOutWrite, @SecAttr, 0) then
    begin
      CloseHandle(FStdInWrite);
      FStdInWrite := 0;
      FLastError := EngineErrStartFailed;
      Exit;
    end;

    SetHandleInformation(FStdInWrite, HANDLE_FLAG_INHERIT, 0);
    SetHandleInformation(FStdOutRead, HANDLE_FLAG_INHERIT, 0);

    FillChar(SI, SizeOf(SI), 0);
    SI.cb := SizeOf(SI);
    SI.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    SI.hStdInput := StdInRead;
    SI.hStdOutput := StdOutWrite;
    SI.hStdError := StdOutWrite;
    SI.wShowWindow := SW_HIDE;

    UniqueString(CmdLine);
    CreationFlags := CREATE_NO_WINDOW or CREATE_UNICODE_ENVIRONMENT;
    if AppName <> '' then
      Created := CreateProcess(PChar(AppName), PChar(CmdLine), nil, nil, True, CreationFlags,
        ChildEnv, PChar(WorkDir), SI, FProcessInfo)
    else
      Created := CreateProcess(nil, PChar(CmdLine), nil, nil, True, CreationFlags,
        ChildEnv, PChar(WorkDir), SI, FProcessInfo);

    if not Created then
    begin
      WinErr := GetLastError;
      DebugLogWrite(Format('[PipeEngine] CreateProcess failed Win32=%d', [WinErr]));
      CloseHandle(StdInRead);
      CloseHandle(StdOutWrite);
      CloseHandle(FStdInWrite);
      CloseHandle(FStdOutRead);
      FStdInWrite := 0;
      FStdOutRead := 0;
      FLastError := EngineErrStartFailed;
      Exit;
    end;

    CloseHandle(StdInRead);
    CloseHandle(StdOutWrite);
    FReaderThread := TPipeReaderThread.Create(Self);
    FReaderThread.Start;
    FRunning := True;
    Result := True;
  finally
    FreeMem(ChildEnv);
  end;
end;

procedure TPipeEngine.ClearAllPending;
var
  Pair: TPair<Integer, TJSONObject>;
begin
  EnsurePending;
  GPendingLock.Enter;
  try
    for Pair in GPendingResults do
      Pair.Value.Free;
    GPendingResults.Clear;
  finally
    GPendingLock.Leave;
  end;
end;

procedure TPipeEngine.Stop;
begin
  if not FRunning then
    Exit;
  try
    if FStdInWrite <> 0 then
    begin
      SendLine('{"cmd":"shutdown","id":0}');
      CloseHandle(FStdInWrite);
      FStdInWrite := 0;
    end;
  except
    on E: Exception do
      DebugLogWrite('[PipeEngine] Stop shutdown: ' + E.Message);
  end;
  if FReaderThread <> nil then
  begin
    FReaderThread.Terminate;
    FReaderThread.WaitFor;
    FreeAndNil(FReaderThread);
  end;
  if FProcessInfo.hProcess <> 0 then
  begin
    WaitForSingleObject(FProcessInfo.hProcess, 3000);
    CloseHandle(FProcessInfo.hProcess);
    CloseHandle(FProcessInfo.hThread);
    FillChar(FProcessInfo, SizeOf(FProcessInfo), 0);
  end;
  if FStdOutRead <> 0 then
  begin
    CloseHandle(FStdOutRead);
    FStdOutRead := 0;
  end;
  ClearAllPending;
  FRunning := False;
  FReadBufLen := 0;
end;

procedure TPipeEngine.CancelGeneration;
begin
  FStreamCancel.SetEvent;
  if not FRunning then
    Exit;
  FSendLock.Enter;
  try
    SendLine('{"cmd":"cancel_generation","id":0}');
  finally
    FSendLock.Leave;
  end;
end;

function TPipeEngine.SendLine(const Json: string): Boolean;
var
  Utf8: TBytes;
  Written: DWORD;
begin
  Result := False;
  if FStdInWrite = 0 then
    Exit;
  Utf8 := TEncoding.UTF8.GetBytes(Json + sLineBreak);
  if Length(Utf8) = 0 then
    Exit;
  Result := WriteFile(FStdInWrite, Utf8[0], Length(Utf8), Written, nil);
  if Result then
    FlushFileBuffers(FStdInWrite);
end;

procedure TPipeEngine.EnsureReadCapacity(Need: Integer);
var
  Cap: Integer;
begin
  Cap := Length(FReadBuf);
  if Cap >= Need then
    Exit;
  if Cap = 0 then
    Cap := 4096
  else
    Cap := Cap * 2;
  while Cap < Need do
    Cap := Cap * 2;
  SetLength(FReadBuf, Cap);
end;

function TPipeEngine.ReadLine(out Line: string): Boolean;
var
  Chunk: array[0..4095] of Byte;
  BytesRead: DWORD;
  I, LineEnd: Integer;
  Slice: TBytes;
begin
  Line := '';
  Result := False;
  if FStdOutRead = 0 then
    Exit;
  while True do
  begin
    for I := 0 to FReadBufLen - 1 do
    begin
      if FReadBuf[I] = 10 then
      begin
        LineEnd := I;
        if (LineEnd > 0) and (FReadBuf[LineEnd - 1] = 13) then
          Dec(LineEnd);
        SetLength(Slice, LineEnd);
        if LineEnd > 0 then
          Move(FReadBuf[0], Slice[0], LineEnd);
        Line := TEncoding.UTF8.GetString(Slice);
        Dec(FReadBufLen, I + 1);
        if FReadBufLen > 0 then
          Move(FReadBuf[I + 1], FReadBuf[0], FReadBufLen);
        Exit(True);
      end;
    end;
    if not ReadFile(FStdOutRead, Chunk, SizeOf(Chunk), BytesRead, nil) or (BytesRead = 0) then
      Exit;
    EnsureReadCapacity(FReadBufLen + Integer(BytesRead));
    Move(Chunk, FReadBuf[FReadBufLen], BytesRead);
    Inc(FReadBufLen, BytesRead);
  end;
end;

function JsonGetInt(Obj: TJSONObject; const Name: string; Default: Integer): Integer;
var
  Val: TJSONValue;
  I: Integer;
begin
  Result := Default;
  if Obj = nil then
    Exit;
  Val := Obj.FindValue(Name);
  if Val = nil then
    for I := 0 to Obj.Count - 1 do
      if SameText(Obj.Pairs[I].JsonString.Value, Name) then
      begin
        Val := Obj.Pairs[I].JsonValue;
        Break;
      end;
  if Val = nil then
    Exit;
  if Val is TJSONNumber then
    Result := Round(TJSONNumber(Val).AsDouble)
  else if Val is TJSONString then
    Result := StrToIntDef(Val.Value, Default);
end;

function JsonGetDouble(Obj: TJSONObject; const Name: string; Default: Double): Double;
var
  Val: TJSONValue;
  I: Integer;
begin
  Result := Default;
  if Obj = nil then
    Exit;
  Val := Obj.FindValue(Name);
  if Val = nil then
    for I := 0 to Obj.Count - 1 do
      if SameText(Obj.Pairs[I].JsonString.Value, Name) then
      begin
        Val := Obj.Pairs[I].JsonValue;
        Break;
      end;
  if (Val = nil) or (Val is TJSONNull) then
    Exit;
  if Val is TJSONNumber then
    Result := TJSONNumber(Val).AsDouble
  else if Val is TJSONString then
    Result := StrToFloatDef(Val.Value, Default);
end;

procedure TPipeEngine.ApplyContextFromObj(Obj: TJSONObject);
begin
  if Obj = nil then
    Exit;
  FContextUsed := Round(JsonGetDouble(Obj, 'context_used', FContextUsed));
  FContextMax := Round(JsonGetDouble(Obj, 'context_max', FContextMax));
  FContextBaseline := Round(JsonGetDouble(Obj, 'context_baseline', FContextBaseline));
  FContextPct := Round(JsonGetDouble(Obj, 'context_pct', FContextPct));
end;

procedure TPipeEngine.DispatchProgress(const Phase: string; Progress: Double);
begin
  TPipeThreadInvoker.QueueMain(procedure
  begin
    if Assigned(FOnProgress) then
      FOnProgress(Self, Phase, Progress);
  end);
end;

procedure TPipeEngine.DispatchToken(const Token: string);
begin
  TPipeThreadInvoker.QueueMain(procedure
  begin
    if Assigned(FOnToken) then
      FOnToken(Self, Token);
  end);
end;

procedure TPipeEngine.DispatchTranscribePart(const Part: string);
begin
  TPipeThreadInvoker.QueueMain(procedure
  begin
    if Assigned(FOnTranscribePart) then
      FOnTranscribePart(Self, Part);
  end);
end;

procedure TPipeEngine.ReaderLoop;
var
  Line: string;
  Obj: TJSONObject;
  Id: Integer;
  EvType, ErrMsg: string;
  Token: string;
  Phase: string;
  Progress: Double;
  CloneObj, Old: TJSONObject;
begin
  EnsurePending;
  while not TThread.CheckTerminated and ReadLine(Line) do
  begin
    if Line.IsEmpty then
      Continue;
    Obj := TJSONObject.ParseJSONValue(Line) as TJSONObject;
    if Obj = nil then
      Continue;
    try
      Id := Obj.GetValue<Integer>('id', -1);
      EvType := Obj.GetValue<string>('type', '');
      if EvType = 'result' then
      begin
        if Id < 0 then
          Continue;
        CloneObj := Obj.Clone as TJSONObject;
        GPendingLock.Enter;
        try
          if GPendingResults.TryGetValue(Id, Old) then
          begin
            GPendingResults.Remove(Id);
            Old.Free;
          end;
          GPendingResults.Add(Id, CloneObj);
        finally
          GPendingLock.Leave;
        end;
        SignalPending;
      end
      else if EvType = 'error' then
      begin
        ErrMsg := Obj.GetValue<string>('error', 'Engine error');
        if Id >= 0 then
          FailPendingId(Id, ErrMsg)
        else
          FailAllPending(ErrMsg);
      end
      else if EvType = 'token' then
      begin
        Token := Obj.GetValue<string>('token', '');
        if Assigned(FOnToken) then
          DispatchToken(Token);
      end
      else if EvType = 'transcribe_part' then
      begin
        Token := Obj.GetValue<string>('text', '');
        if Assigned(FOnTranscribePart) then
          DispatchTranscribePart(Token);
      end
      else if EvType = 'progress' then
      begin
        Phase := Obj.GetValue<string>('phase', '');
        Progress := JsonGetDouble(Obj, 'progress', -1);
        if Assigned(FOnProgress) then
          DispatchProgress(Phase, Progress);
      end;
    finally
      Obj.Free;
    end;
  end;
  if FRunning then
    FailAllPending('Engine process ended unexpectedly.');
end;

function TPipeEngine.WaitResult(const Id: Integer; TimeoutMs: Cardinal; CancelEvt: TEvent;
  out ResultObj: TJSONObject): Boolean;
var
  Start, Elapsed: UInt64;
  WaitMs: Cardinal;
  Obj: TJSONObject;
begin
  Result := False;
  ResultObj := nil;
  EnsurePending;
  Start := GetTickCount64;
  while True do
  begin
    if (CancelEvt <> nil) and (CancelEvt.WaitFor(0) = wrSignaled) then
    begin
      RemovePendingId(Id);
      FLastError := 'Operation cancelled.';
      Exit;
    end;
    if not IsProcessAlive then
    begin
      RemovePendingId(Id);
      FLastError := 'Engine process exited.';
      FRunning := False;
      Exit;
    end;
    GPendingLock.Enter;
    try
      if GPendingResults.TryGetValue(Id, Obj) then
      begin
        GPendingResults.Remove(Id);
        ResultObj := Obj;
        Result := True;
        Exit;
      end;
    finally
      GPendingLock.Leave;
    end;
    Elapsed := GetTickCount64 - Start;
    if Elapsed >= TimeoutMs then
      Break;
    WaitMs := TimeoutMs - Cardinal(Elapsed);
    if WaitMs > 250 then
      WaitMs := 250;
    if GPendingEvent.WaitFor(WaitMs) = wrAbandoned then
      Break;
  end;
  RemovePendingId(Id);
  FLastError := 'Engine response timeout.';
end;

function TPipeEngine.SendAndWait(const BuildJson: TFunc<Integer, string>; TimeoutMs: Cardinal;
  CancelEvt: TEvent; out Obj: TJSONObject): Boolean;
var
  Id: Integer;
begin
  Obj := nil;
  Result := False;
  FLastError := '';
  if not FRunning then
  begin
    FLastError := 'Engine is not running.';
    Exit;
  end;
  if not IsProcessAlive then
  begin
    FLastError := 'Engine process is not running.';
    FRunning := False;
    Exit;
  end;
  FSendLock.Enter;
  try
    Id := FNextId;
    Inc(FNextId);
    if not SendLine(BuildJson(Id)) then
    begin
      FLastError := 'Could not send command to engine.';
      Exit;
    end;
  finally
    FSendLock.Leave;
  end;
  Result := WaitResult(Id, TimeoutMs, CancelEvt, Obj);
end;

function ParseResultOk(Obj: TJSONObject; out ErrorMsg: string): Boolean;
begin
  ErrorMsg := '';
  Result := False;
  if Obj = nil then
  begin
    ErrorMsg := 'Empty engine response.';
    Exit;
  end;
  Result := Obj.GetValue<Boolean>('ok', False);
  if not Result then
    ErrorMsg := Obj.GetValue<string>('error', 'Engine command failed.');
end;

function TPipeEngine.RefreshGpuLayerCount: Boolean;
var
  Obj: TJSONObject;
begin
  Result := False;
  if not FRunning then
    Exit;
  Result := SendAndWait(
    function(Id: Integer): string
    begin
      Result := Format('{"cmd":"gpu_status","id":%d}', [Id]);
    end, 10000, nil, Obj);
  if Result and (Obj <> nil) then
  begin
    if Obj.GetValue<Boolean>('ok', False) then
    begin
      FGpuLoaded := Obj.GetValue<Boolean>('loaded', FGpuLoaded);
      FGpuLayers := JsonGetInt(Obj, 'gpu_layers', FGpuLayers);
    end;
    Result := Obj.GetValue<Boolean>('ok', False);
    Obj.Free;
  end;
end;

function TPipeEngine.GpuLoadStatusText: string;
var
  L: Integer;
begin
  L := FGpuLayers;
  if (L = GpuLayersUnknown) or (not FGpuLoaded) then
    RefreshGpuLayerCount;
  L := FGpuLayers;
  if not FGpuLoaded then
    Exit('');
  if L = 0 then
    Result := 'AI loaded on CPU only - answers will be slower.'
  else if L = GpuLayersAll then
    Result := 'AI loaded on GPU (all layers).'
  else if L > 0 then
    Result := Format('AI loaded on GPU (%d layers).', [L])
  else
    Result := 'Ready.';
end;

function TPipeEngine.Ping: Boolean;
var
  Obj: TJSONObject;
begin
  Result := SendAndWait(
    function(Id: Integer): string
    begin
      Result := Format('{"cmd":"ping","id":%d}', [Id]);
    end, 5000, nil, Obj);
  if Result and (Obj <> nil) then
  begin
    Result := Obj.GetValue<Boolean>('ok', False);
    Obj.Free;
  end;
end;

function TPipeEngine.Startup(const LangCode, LangName: string; Level: TResponseIntelligence;
  WhisperLevel: TTranscriptionIntelligence;
  const Role, TechStack, JobDesc, Experience: string; AnswerLen: TAnswerLength;
  OnProgress: TPipeProgressEvent; out ErrorMsg: string): Boolean;
var
  Obj: TJSONObject;
  Req: TJSONObject;
begin
  ErrorMsg := '';
  FOnProgress := OnProgress;
  Result := SendAndWait(
    function(Id: Integer): string
    begin
      Req := TJSONObject.Create;
      try
        Req.AddPair('cmd', 'startup');
        Req.AddPair('id', TJSONNumber.Create(Id));
        Req.AddPair('lang_code', LangCode);
        Req.AddPair('lang_name', LangName);
        Req.AddPair('intelligence', TJSONNumber.Create(Ord(Level)));
        Req.AddPair('whisper_intelligence', TJSONNumber.Create(Ord(WhisperLevel)));
        Req.AddPair('length', TJSONNumber.Create(Ord(AnswerLen)));
        Req.AddPair('role', Role);
        Req.AddPair('tech_stack', TechStack);
        Req.AddPair('job_description', JobDesc);
        Req.AddPair('experience', Experience);
        if FSessionToken <> '' then
          Req.AddPair('session_token', FSessionToken);
        Result := Req.ToJSON;
      finally
        Req.Free;
      end;
    end, 60 * 60 * 1000, nil, Obj);
  if not Result then
  begin
    ErrorMsg := FLastError;
    Exit(False);
  end;
  try
    Result := ParseResultOk(Obj, ErrorMsg);
    if Result then
    begin
      FGpuLoaded := True;
      FGpuLayers := JsonGetInt(Obj, 'gpu_layers', GpuLayersUnknown);
    end;
  finally
    Obj.Free;
  end;
end;

function TPipeEngine.StartupLegacy(const LangCode, LangName: string; Level: TResponseIntelligence;
  WhisperLevel: TTranscriptionIntelligence;
  const Role, TechStack, JobDesc, Experience: string; AnswerLen: TAnswerLength;
  OnProgress: TPipeProgressEvent; out ErrorMsg: string): Boolean;
begin
  ErrorMsg := '';
  FOnProgress := OnProgress;
  if not EnsureWhisper(WhisperLevel, OnProgress) then
  begin
    ErrorMsg := 'Whisper model download/load failed.';
    Exit(False);
  end;
  if not LoadWhisper(WhisperLevel) then
  begin
    ErrorMsg := 'Could not load Whisper.';
    Exit(False);
  end;
  if not SetLanguage(LangCode, LangName) then
  begin
    ErrorMsg := 'Could not set language.';
    Exit(False);
  end;
  if not WarmupWhisper then
  begin
    ErrorMsg := 'Whisper warmup failed.';
    Exit(False);
  end;
  if not EnsureModel(Level, OnProgress) then
  begin
    ErrorMsg := 'AI model download failed.';
    Exit(False);
  end;
  if not LoadLlm(Level) then
  begin
    ErrorMsg := 'Could not load AI model.';
    Exit(False);
  end;
  if not SetProfile(Role, TechStack, JobDesc, Experience) then
  begin
    ErrorMsg := 'Could not set profile.';
    Exit(False);
  end;
  if not SetAnswerLength(AnswerLen) then
  begin
    ErrorMsg := 'Could not set answer length.';
    Exit(False);
  end;
  Result := WarmupLlm;
  if Result then
    FGpuLoaded := True
  else
    ErrorMsg := 'AI model warmup failed.';
end;

function TPipeEngine.EnsureWhisper(Level: TTranscriptionIntelligence;
  OnProgress: TPipeProgressEvent): Boolean;
var
  Obj: TJSONObject;
begin
  FOnProgress := OnProgress;
  Result := SendAndWait(
    function(Id: Integer): string
    var
      Req: TJSONObject;
    begin
      Req := TJSONObject.Create;
      try
        Req.AddPair('cmd', 'ensure_whisper');
        Req.AddPair('id', TJSONNumber.Create(Id));
        Req.AddPair('whisper_intelligence', TJSONNumber.Create(Ord(Level)));
        Result := Req.ToJSON;
      finally
        Req.Free;
      end;
    end, 30 * 60 * 1000, nil, Obj);
  if Result and (Obj <> nil) then
  begin
    Result := Obj.GetValue<Boolean>('ok', False);
    Obj.Free;
  end;
end;

function TPipeEngine.LoadWhisper(Level: TTranscriptionIntelligence): Boolean;
var
  Obj: TJSONObject;
begin
  Result := SendAndWait(
    function(Id: Integer): string
    var
      Req: TJSONObject;
    begin
      Req := TJSONObject.Create;
      try
        Req.AddPair('cmd', 'load_whisper');
        Req.AddPair('id', TJSONNumber.Create(Id));
        Req.AddPair('whisper_intelligence', TJSONNumber.Create(Ord(Level)));
        Result := Req.ToJSON;
      finally
        Req.Free;
      end;
    end, 120000, nil, Obj);
  if Result and (Obj <> nil) then
  begin
    Result := Obj.GetValue<Boolean>('ok', False);
    Obj.Free;
  end;
end;

procedure TPipeEngine.CancelTranscribe;
var
  Obj: TJSONObject;
begin
  SendAndWait(
    function(Id: Integer): string
    begin
      Result := Format('{"cmd":"cancel_transcribe","id":%d}', [Id]);
    end, 2000, nil, Obj);
  if Obj <> nil then
    Obj.Free;
end;

procedure TPipeEngine.CancelTranscribeAsync;
begin
  if not FRunning then
    Exit;
  SendLine('{"cmd":"cancel_transcribe","id":-1}');
end;

function TPipeEngine.WarmupWhisper: Boolean;
var
  Obj: TJSONObject;
begin
  Result := SendAndWait(
    function(Id: Integer): string
    begin
      Result := Format('{"cmd":"warmup_whisper","id":%d}', [Id]);
    end, 120000, nil, Obj);
  if Result and (Obj <> nil) then
  begin
    Result := Obj.GetValue<Boolean>('ok', False);
    Obj.Free;
  end;
end;

function TPipeEngine.Transcribe(const Samples: TArray<Single>; out Text: string): Boolean;
var
  Obj: TJSONObject;
  Bytes: TBytes;
  B64: string;
begin
  Text := '';
  Result := False;
  if Length(Samples) = 0 then
    Exit;
  SetLength(Bytes, Length(Samples) * SizeOf(Single));
  Move(Samples[0], Bytes[0], Length(Bytes));
  B64 := TNetEncoding.Base64.EncodeBytesToString(Bytes);
  Result := SendAndWait(
    function(Id: Integer): string
    var
      Req: TJSONObject;
    begin
      Req := TJSONObject.Create;
      try
        Req.AddPair('cmd', 'transcribe');
        Req.AddPair('id', TJSONNumber.Create(Id));
        Req.AddPair('samples_b64', B64);
        Result := Req.ToJSON;
      finally
        Req.Free;
      end;
    end, 120000, nil, Obj);
  if Result and (Obj <> nil) then
  begin
    Result := Obj.GetValue<Boolean>('ok', False);
    if Result then
      Text := Obj.GetValue<string>('text', '');
    Obj.Free;
  end;
end;

function TPipeEngine.TranscribeStream(const Samples: TArray<Single>;
  OnPart: TPipeTranscribePartEvent; out Text: string; ALive: Boolean): Boolean;
var
  Obj: TJSONObject;
  Bytes: TBytes;
  B64: string;
begin
  Text := '';
  Result := False;
  if Length(Samples) = 0 then
    Exit;
  SetLength(Bytes, Length(Samples) * SizeOf(Single));
  Move(Samples[0], Bytes[0], Length(Bytes));
  B64 := TNetEncoding.Base64.EncodeBytesToString(Bytes);
  FOnTranscribePart := OnPart;
  try
    Result := SendAndWait(
      function(Id: Integer): string
      var
        Req: TJSONObject;
      begin
        Req := TJSONObject.Create;
        try
          Req.AddPair('cmd', 'transcribe_stream');
          Req.AddPair('id', TJSONNumber.Create(Id));
          Req.AddPair('samples_b64', B64);
          if ALive then
            Req.AddPair('live', TJSONBool.Create(True));
          Result := Req.ToJSON;
        finally
          Req.Free;
        end;
      end, 120000, nil, Obj);
    if Result and (Obj <> nil) then
    begin
      Result := Obj.GetValue<Boolean>('ok', False);
      if Result then
        Text := Obj.GetValue<string>('text', '');
      Obj.Free;
    end;
  finally
    FOnTranscribePart := nil;
  end;
end;

function TPipeEngine.ClassifyUtterance(const Text: string; out Answerable: Boolean): Boolean;
var
  Obj: TJSONObject;
begin
  Answerable := True;
  Result := False;
  if Text.Trim.IsEmpty then
  begin
    Answerable := False;
    Exit;
  end;
  Result := SendAndWait(
    function(Id: Integer): string
    var
      Req: TJSONObject;
    begin
      Req := TJSONObject.Create;
      try
        Req.AddPair('cmd', 'classify_utterance');
        Req.AddPair('id', TJSONNumber.Create(Id));
        Req.AddPair('text', Text);
        Result := Req.ToJSON;
      finally
        Req.Free;
      end;
    end, 45000, nil, Obj);
  if Result and (Obj <> nil) then
  begin
    Result := Obj.GetValue<Boolean>('ok', False);
    if Result then
      Answerable := Obj.GetValue<Boolean>('answerable', True);
    Obj.Free;
  end;
end;

function TPipeEngine.SetLanguage(const LangCode, LangName: string): Boolean;
var
  Obj: TJSONObject;
begin
  Result := SendAndWait(
    function(Id: Integer): string
    var
      Req: TJSONObject;
    begin
      Req := TJSONObject.Create;
      try
        Req.AddPair('cmd', 'set_language');
        Req.AddPair('id', TJSONNumber.Create(Id));
        Req.AddPair('lang_code', LangCode);
        Req.AddPair('lang_name', LangName);
        Result := Req.ToJSON;
      finally
        Req.Free;
      end;
    end, 10000, nil, Obj);
  if Result and (Obj <> nil) then
  begin
    Result := Obj.GetValue<Boolean>('ok', False);
    Obj.Free;
  end;
end;

function TPipeEngine.EnsureModel(Level: TResponseIntelligence;
  OnProgress: TPipeProgressEvent): Boolean;
var
  Obj: TJSONObject;
begin
  FOnProgress := OnProgress;
  Result := SendAndWait(
    function(Id: Integer): string
    begin
      Result := Format('{"cmd":"ensure_model","id":%d,"intelligence":%d}',
        [Id, Ord(Level)]);
    end, 60 * 60 * 1000, nil, Obj);
  if Result and (Obj <> nil) then
  begin
    Result := Obj.GetValue<Boolean>('ok', False);
    Obj.Free;
  end;
end;

function TPipeEngine.LoadLlm(Level: TResponseIntelligence): Boolean;
var
  Obj: TJSONObject;
begin
  Result := SendAndWait(
    function(Id: Integer): string
    begin
      Result := Format('{"cmd":"load_llm","id":%d,"intelligence":%d}',
        [Id, Ord(Level)]);
    end, 600000, nil, Obj);
  if Result and (Obj <> nil) then
  begin
    Result := Obj.GetValue<Boolean>('ok', False);
    if Result then
    begin
      FGpuLoaded := True;
      FGpuLayers := JsonGetInt(Obj, 'gpu_layers', FGpuLayers);
    end;
    Obj.Free;
  end;
end;

function TPipeEngine.WarmupLlm: Boolean;
var
  Obj: TJSONObject;
begin
  Result := SendAndWait(
    function(Id: Integer): string
    begin
      Result := Format('{"cmd":"warmup_llm","id":%d}', [Id]);
    end, 120000, nil, Obj);
  if Result and (Obj <> nil) then
  begin
    Result := Obj.GetValue<Boolean>('ok', False);
    Obj.Free;
  end;
end;

function TPipeEngine.SetProfile(const Role, TechStack, JobDesc, Experience: string): Boolean;
var
  Obj: TJSONObject;
begin
  Result := SendAndWait(
    function(Id: Integer): string
    var
      Req: TJSONObject;
    begin
      Req := TJSONObject.Create;
      try
        Req.AddPair('cmd', 'set_profile');
        Req.AddPair('id', TJSONNumber.Create(Id));
        Req.AddPair('role', Role);
        Req.AddPair('tech_stack', TechStack);
        Req.AddPair('job_description', JobDesc);
        Req.AddPair('experience', Experience);
        Result := Req.ToJSON;
      finally
        Req.Free;
      end;
    end, 10000, nil, Obj);
  if Result and (Obj <> nil) then
  begin
    Result := Obj.GetValue<Boolean>('ok', False);
    Obj.Free;
  end;
end;

function TPipeEngine.SetAnswerLength(AnswerLen: TAnswerLength): Boolean;
var
  Obj: TJSONObject;
begin
  Result := SendAndWait(
    function(Id: Integer): string
    begin
      Result := Format('{"cmd":"set_answer_length","id":%d,"length":%d}',
        [Id, Ord(AnswerLen)]);
    end, 10000, nil, Obj);
  if Result and (Obj <> nil) then
  begin
    Result := Obj.GetValue<Boolean>('ok', False);
    Obj.Free;
  end;
end;

function TPipeEngine.ResetConversation: Boolean;
var
  Obj: TJSONObject;
begin
  Result := SendAndWait(
    function(Id: Integer): string
    begin
      Result := Format('{"cmd":"reset","id":%d}', [Id]);
    end, 10000, nil, Obj);
  if Result and (Obj <> nil) then
  begin
    Result := Obj.GetValue<Boolean>('ok', False);
    ApplyContextFromObj(Obj);
    Obj.Free;
  end;
end;

function TPipeEngine.QueryChatContext(out UsedTokens, MaxTokens: Integer): Boolean;
var
  Obj: TJSONObject;
begin
  UsedTokens := FContextUsed;
  MaxTokens := FContextMax;
  Result := SendAndWait(
    function(Id: Integer): string
    begin
      Result := Format('{"cmd":"context_status","id":%d}', [Id]);
    end, 10000, nil, Obj);
  if Result and (Obj <> nil) then
  begin
    Result := Obj.GetValue<Boolean>('ok', False);
    ApplyContextFromObj(Obj);
    UsedTokens := FContextUsed;
    MaxTokens := FContextMax;
    Obj.Free;
  end;
end;

function TPipeEngine.DropLastExchange: Boolean;
var
  Obj: TJSONObject;
begin
  Result := SendAndWait(
    function(Id: Integer): string
    begin
      Result := Format('{"cmd":"drop_last_exchange","id":%d}', [Id]);
    end, 10000, nil, Obj);
  if Result and (Obj <> nil) then
  begin
    Result := Obj.GetValue<Boolean>('ok', False);
    Obj.Free;
  end;
end;

function TPipeEngine.GenerateStream(const Question: string;
  OnToken: TPipeTokenEvent): Boolean;
var
  Obj: TJSONObject;
  Cancelled: Boolean;
begin
  FOnToken := OnToken;
  FStreamCancel.ResetEvent;
  try
    Result := SendAndWait(
      function(Id: Integer): string
      var
        Req: TJSONObject;
      begin
        Req := TJSONObject.Create;
        try
          Req.AddPair('cmd', 'generate_stream');
          Req.AddPair('id', TJSONNumber.Create(Id));
          Req.AddPair('question', Question);
          Result := Req.ToJSON;
        finally
          Req.Free;
        end;
      end, 600000, FStreamCancel, Obj);
    if not Result then
      Exit;
    try
      Cancelled := Obj.GetValue<Boolean>('cancelled', False);
      Result := Obj.GetValue<Boolean>('ok', False) and not Cancelled;
      ApplyContextFromObj(Obj);
    finally
      Obj.Free;
    end;
  finally
    FOnToken := nil;
  end;
end;

initialization

finalization
  if GPendingResults <> nil then
  begin
    for var Pair in GPendingResults do
      Pair.Value.Free;
    FreeAndNil(GPendingResults);
  end;
  if GPendingEvent <> nil then
    FreeAndNil(GPendingEvent);
  if GPendingLock <> nil then
    FreeAndNil(GPendingLock);

end.
