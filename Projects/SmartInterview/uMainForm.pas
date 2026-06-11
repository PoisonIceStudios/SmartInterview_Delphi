unit uMainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Math, System.Types,
  System.Threading, System.UITypes, System.RegularExpressions, System.StrUtils, System.SyncObjs, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus, Vcl.Buttons, Vcl.Imaging.pngimage,
  uTitleIndicators, uPipeEngine, uAudioCapture, uWasapi16k, uMicCapture,
  uVoiceSegmenter, uReadAlongMatcher, uGlobalKeyboardHook, uInterviewProfile,
  uAppSettings, uRegistryStore, uMicDevices, uModelCat, uWhisperCat, uFrmSettings, uLiveTransDiag,
  uLicenseMonitor;

type
  TScrollMode = (smOff, smAuto, smVoice);

  TMainForm = class(TForm)
    pnlTitleBar: TPanel;
    pnlIndicators: TPanel;
    pbWaveform: TPaintBox;
    pbMic: TPaintBox;
    pnlTitleButtons: TPanel;
    btnPin: TSpeedButton;
    btnMenu: TSpeedButton;
    btnOpDn: TSpeedButton;
    btnOpUp: TSpeedButton;
    btnNew: TSpeedButton;
    btnAuto: TSpeedButton;
    btnSetup: TSpeedButton;
    pnlBody: TPanel;
    lblHeard: TLabel;
    txtTranscript: TMemo;
    lblAnswer: TLabel;
    rtbResponse: TRichEdit;
    pnlStatus: TPanel;
    lblInterviewTitle: TLabel;
    lblStatusBar: TLabel;
    mnuMain: TPopupMenu;
    miInterview: TMenuItem;
    miSetup: TMenuItem;
    miLang: TMenuItem;
    miLangEn: TMenuItem;
    miLangEs: TMenuItem;
    miLangFr: TMenuItem;
    miLangDe: TMenuItem;
    miLangIt: TMenuItem;
    miLangRu: TMenuItem;
    miLength: TMenuItem;
    miLenShort: TMenuItem;
    miLenMedium: TMenuItem;
    miLenLong: TMenuItem;
    miModels: TMenuItem;
    miTrans: TMenuItem;
    miTransFast: TMenuItem;
    miTransBalanced: TMenuItem;
    miTransMax: TMenuItem;
    miTransSep: TMenuItem;
    miRemoveWhisper: TMenuItem;
    miRemoveTransFast: TMenuItem;
    miRemoveTransBalanced: TMenuItem;
    miRemoveTransMax: TMenuItem;
    miIntel: TMenuItem;
    miIntelFast: TMenuItem;
    miIntelBalanced: TMenuItem;
    miIntelMax: TMenuItem;
    miIntelSep: TMenuItem;
    miRemoveModel: TMenuItem;
    miRemoveFast: TMenuItem;
    miRemoveBalanced: TMenuItem;
    miRemoveMax: TMenuItem;
    miGpuSep: TMenuItem;
    miForceCuda: TMenuItem;
    miListening: TMenuItem;
    miListenKey: TMenuItem;
    miKeyCtrl: TMenuItem;
    miKeyShift: TMenuItem;
    miKeyAlt: TMenuItem;
    miAutoCfg: TMenuItem;
    miMicCfg: TMenuItem;
    miAudio: TMenuItem;
    miMicMenu: TMenuItem;
    miMicDefault: TMenuItem;
    miMic01: TMenuItem;
    miMic02: TMenuItem;
    miMic03: TMenuItem;
    miMic04: TMenuItem;
    miMic05: TMenuItem;
    miMic06: TMenuItem;
    miMic07: TMenuItem;
    miMic08: TMenuItem;
    miMic09: TMenuItem;
    miMic10: TMenuItem;
    miMic11: TMenuItem;
    miMic12: TMenuItem;
    miMic13: TMenuItem;
    miMic14: TMenuItem;
    miMic15: TMenuItem;
    miUseMic: TMenuItem;
    miScroll: TMenuItem;
    miScrollOff: TMenuItem;
    miScrollAuto: TMenuItem;
    miScrollVoice: TMenuItem;
    miScrollSep: TMenuItem;
    miSpeed: TMenuItem;
    miSpeedVSlow: TMenuItem;
    miSpeedSlow: TMenuItem;
    miSpeedMed: TMenuItem;
    miSpeedFast: TMenuItem;
    miSpeedVFast: TMenuItem;
    miView: TMenuItem;
    miWindow: TMenuItem;
    miTopmost: TMenuItem;
    miHideCapture: TMenuItem;
    miWinSep: TMenuItem;
    miMinimize: TMenuItem;
    miRespAppear: TMenuItem;
    miTextSize: TMenuItem;
    miSize9: TMenuItem;
    miSize10: TMenuItem;
    miSize12: TMenuItem;
    miSize14: TMenuItem;
    miSize16: TMenuItem;
    miSize20: TMenuItem;
    miTextColor: TMenuItem;
    miColWhite: TMenuItem;
    miColBlue: TMenuItem;
    miColGreen: TMenuItem;
    miColYellow: TMenuItem;
    miColMagenta: TMenuItem;
    miAboutSep: TMenuItem;
    miAbout: TMenuItem;
    miExit: TMenuItem;
    trayIcon: TTrayIcon;
    mnuTray: TPopupMenu;
    miTrayShow: TMenuItem;
    miTrayExit: TMenuItem;
    tmrLive: TTimer;
    tmrRead: TTimer;
    tmrAnim: TTimer;
    tmrIcon: TTimer;
    tmrEngine: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure CreateParams(var Params: TCreateParams); override;
    procedure TitleBarMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure btnPinClick(Sender: TObject);
    procedure btnMenuClick(Sender: TObject);
    procedure btnSetupClick(Sender: TObject);
    procedure btnAutoClick(Sender: TObject);
    procedure btnNewClick(Sender: TObject);
    procedure btnOpUpClick(Sender: TObject);
    procedure btnOpDnClick(Sender: TObject);
    procedure miSetupClick(Sender: TObject);
    procedure miLangClick(Sender: TObject);
    procedure miLengthClick(Sender: TObject);
    procedure miIntelClick(Sender: TObject);
    procedure miTransClick(Sender: TObject);
    procedure miListenKeyClick(Sender: TObject);
    procedure miAutoCfgClick(Sender: TObject);
    procedure miForceCudaClick(Sender: TObject);
    procedure miMicCfgClick(Sender: TObject);
    procedure miUseMicClick(Sender: TObject);
    procedure miMicClick(Sender: TObject);
    procedure miScrollClick(Sender: TObject);
    procedure miSpeedClick(Sender: TObject);
    procedure miTopmostClick(Sender: TObject);
    procedure miHideCaptureClick(Sender: TObject);
    procedure miMinimizeClick(Sender: TObject);
    procedure miTextSizeClick(Sender: TObject);
    procedure miTextColorClick(Sender: TObject);
    procedure miAboutClick(Sender: TObject);
    procedure miExitClick(Sender: TObject);
    procedure miRemoveModelClick(Sender: TObject);
    procedure miRemoveTransClick(Sender: TObject);
    procedure trayIconDblClick(Sender: TObject);
    procedure tmrLiveTimer(Sender: TObject);
    procedure tmrReadTimer(Sender: TObject);
    procedure tmrAnimTimer(Sender: TObject);
    procedure tmrIconTimer(Sender: TObject);
    procedure tmrEngineTimer(Sender: TObject);
    procedure tmrLicenseTimer(Sender: TObject);
    procedure HandleLicensePeriodicResult(const Res: TLicensePeriodicResult; const Msg: string);
    procedure RestartEngineAfterRelicense;
    procedure pbWaveformPaint(Sender: TObject);
    procedure pbMicPaint(Sender: TObject);
  private
    FWavePhase: Double;
    FEngine: TPipeEngine;
    FAudio: TAudioCapture;
    FHook: TGlobalKeyboardHook;
    FSegmenter: TVoiceSegmenter;
    FReadMic: TMicCapture;
    FMatcher: TReadAlongMatcher;
    FMicMonitor: TWasapi16kSource;
    FProfile: TInterviewProfile;
    FIntelligence: TResponseIntelligence;
    FTranscription: TTranscriptionIntelligence;
    FAnswerLength: TAnswerLength;
    FLangCode: string;
    FLangName: string;
    FListeningKey: TListeningKey;
    FScrollMode: TScrollMode;
    FAutoSpeed: Double;
    FModelBusy: Boolean;
    FModelLock: TCriticalSection;
    FShuttingDown: Boolean;
    FReady: Boolean;
    FListening: Boolean;
    FLiveBusy: Boolean;
    FLiveReschedule: Boolean;
    FUseMic: Boolean;
    FAutoMode: Boolean;
    FAutoBusy: Boolean;
    FHiddenFromCapture: Boolean;
    FMicVoiceTicks: Int64;
    FMicMonitorIgnoreUntil: Int64;
    FMicThreshold: Single;
    FMicRmsLast: Single;
    FMicRmsDisplay: Single;
    FPcVoiceTicks: Int64;
    FRespColor: TColor;
    FReadDoneColor: TColor;
    FReadPos: Double;
    FConfirmedChar: Double;
    FPrevConfirmChar: Double;
    FPrevConfirmTicks: Int64;
    FColoredChars: Integer;
    FEstSpeed: Double;
    FReadStartTicks: Int64;
    FLastAnimTicks: Int64;
    FReadBusy: Boolean;
    FEnginePingFails: Integer;
    FEnginePingBusy: Boolean;
    FLicenseTimer: TTimer;
    FLicenseCheckBusy: Boolean;
    FLicenseOfflineBlocked: Boolean;
    FProgressLastUpdate: Int64;
    FStreamBuf: string;
    FStreamAnswer: string;
    FStreamDecided: Boolean;
    FStreamSkip: Boolean;
    FStreamShown: Integer;
    FLastAutoQuestionKey: string;
    FLastAutoQuestionTicks: Int64;
    FAutoAnswerGen: Integer;
    FStreamAnswerGen: Integer;
    FStreamForce: Boolean;
    FListenSession: Integer;
    FListenFinalSession: Integer;
    FLastLivePreview: string;
    FSettingsMonitoring: Boolean;
    function StripNoiseTokens(const Text: string): string;
    function CleanTranscriptText(const Text: string): string;
    procedure WaitLiveBusyIdle(TimeoutMs: Cardinal);
    procedure ApplyLivePreview(const Text: string; const DiagTag: string);
    procedure RunListenFinalize(const ASnap: TArray<Single>; const APreview: string; ASession: Integer);
    function NormalizeQuestionKey(const Text: string): string;
    function IsDuplicateAutoQuestion(const Text: string): Boolean;
    procedure RecordAutoQuestionAnswered(const Text: string);
    procedure HandleStreamToken(Sender: TObject; const Token: string);
    function IsWaveRecording: Boolean;
    function IsMicActive: Boolean;
    procedure StyleIndicatorPaintBoxes;
    procedure RefreshIndicators;
    procedure InitTrayIcon;
    procedure ApplyOpacity;
    procedure AdjustOpacityByStep(Down: Boolean);
    procedure UpdateContextIndicator;
    procedure RefreshContextIndicator;
    procedure UpdateTaskbarVisibility;
    procedure ApplyCaptureHiding;
    procedure SetStatus(const Text: string);
    procedure ShowGpuLoadStatus;
    procedure SetActionsEnabled(Enabled: Boolean);
    procedure UiInvoke(const Proc: TProc);
    procedure RunAsync(const Proc: TProc);
    procedure OnListeningKeyPressed;
    procedure OnListeningKeyReleased;
    procedure OnSystemSamples(const Samples: TArray<Single>);
    procedure OnMicMonitor(const Samples: TArray<Single>);
    procedure OnAutoSpeechStarted;
    procedure OnAutoProgress(const Seg: TArray<Single>);
    procedure OnAutoSegment(const Seg: TArray<Single>);
    procedure StartMicMonitor;
    procedure ToggleAutoMode;
    procedure SetAutoMode(On: Boolean);
    procedure SetGlyphActive(Btn: TSpeedButton; Active: Boolean);
    procedure UpdateAutoVisual;
    procedure UpdatePinVisual;
    procedure RefreshIntelligenceMenu;
    procedure RefreshTranscriptionMenu;
    procedure SyncMenuFromSettings;
    procedure OnEngineProgress(Sender: TObject; const Phase: string; Progress: Double);
    function TranscribeAsync(const Samples: TArray<Single>; out Text: string): Boolean;
    function WhisperTierDiagLabel: string;
    procedure ScheduleLiveTranscribe;
    function StreamAnswer(const Question: string; Force: Boolean = False): Boolean;
    function BuildManualCapturePrompt(const Transcript: string): string;
    procedure SetTranscript(const Text: string);
    procedure AppendResponse(const Text: string);
    procedure KeepScrollAppendResponse(const Value: string; StartPos: Integer);
    procedure PrepareResponseForStreaming;
    procedure StartReadAlong;
    procedure StopReadAlong;
    procedure StartSettingsMonitor;
    procedure StopSettingsMonitor;
    procedure UpdateInterviewBanner;
    function ProfileRoleSet: Boolean;
    function RequireProfileToStart: Boolean;
    procedure SetUseMicEnabled(Value: Boolean);
    procedure SetListeningKeyChoice(const Key: TListeningKey);
    procedure RebuildMicMenu;
    function HasMinimalAutoSpeech(const Text: string): Boolean;
    function ClassifyUtteranceAsync(const Text: string; out Answerable: Boolean): Boolean;
    function IsUsefulTranscript(const Text: string): Boolean;
    function CountRealWords(const Text: string): Integer;
    function IsLikelyNoiseHallucination(const Text: string): Boolean;
    function ShouldShowHearingPreview(const Text: string): Boolean;
    function ShouldCommitHearing(const Text: string): Boolean;
    function LoadMicThresholdFromRegistry: Single;
    function ManualSpeechThreshold: Single;
    function SanitizeAnswer(const S: string): string;
    function ResponsePlainText: string;
    function ResponseHasText: Boolean;
    function GetRtbScrollY: Integer;
    procedure SetRtbScrollY(Y: Integer);
    function RtbPosFromCharIndex(AIndex: Integer): TPoint;
    procedure HookListeningKeyPressed;
    procedure HookListeningKeyReleased;
    procedure HookToggleTopmost;
    procedure HookOpacityDown;
    procedure HookOpacityUp;
  public
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

uses
  System.IOUtils,
  uFrmProfile, uFrmAbout, uFrmInterviewSetup, uFrmLicense, uFrmMicSettings,
  System.Win.Registry,
  uDialogZOrder, uAppStartup, uRichEditFmt, uDebugLog, uLicenseService;

const
  SkipMarker = '[[SKIP]]';
  OpacityStepPct = 5;
  OpacityMinPct = 30;
  DuplicateQuestionMs = 6000;
  LiveMinPreviewSamples = 8000;     // 0.5 s minimum before transcribing
  ReadAnchorRatio = 0.40;
  ReadStartDelaySec = 0.3;
  ReadLookaheadChars = 160;
  ReadLerp = 0.18;
  EM_GETSCROLLPOS = $04DD;
  EM_SETSCROLLPOS = $04DE;
  EM_POSFROMCHAR = $0206;
  WM_SETREDRAW = $000B;
  EM_GETFIRSTVISIBLELINE = $004CE;
  EM_LINESCROLL = $00B6;
  NoiseTokenPattern = '\[.*?\]|\(.*?\)|\x{266A}|\x{2026}|\.{2,}|\*+';
  SI_WDA_NONE = 0;
  SI_WDA_EXCLUDEFROMCAPTURE = $00000011;
  WM_NCLBUTTONDOWN = $00A1;
  HTCAPTION = 2;
  LWA_ALPHA = $2;
  MicMonitorWarmupMs = 2000;
  // Default mic gate (RMS, 0..1). Only audio above this is treated as speech, then normalized by
  // the engine (AGC). This is just the slider's starting point — the user sets the line on the
  // live meter for their mic/room.
  MicDefaultThreshold = 0.020;
  MicMeterMaxStep = 0.06;       // ignore single-buffer spikes on the level meter
  MicActiveHoldMs = 250;

  // Segoe MDL2 Assets - pin toggles in UpdatePinVisual
  GlyphPin = #$E840;
  GlyphPinUp = #$E718;
  GlyphNewChat = #$E8F2;  // ChatBubbles

  // Title-bar toggle buttons (pin, automatic mode) light up in this azure when active.
  ActiveGlyphColor = TColor($00FF9900); // RGB(0,153,255)

type
  TMainThreadInvoker = class
  strict private
    FProc: TProc;
  public
    constructor Create(const AProc: TProc);
    procedure Invoke;
  end;

constructor TMainThreadInvoker.Create(const AProc: TProc);
begin
  inherited Create;
  FProc := AProc;
end;

procedure TMainThreadInvoker.Invoke;
begin
  try
    if Assigned(FProc) then
      FProc();
  finally
    Free;
  end;
end;

procedure TMainForm.UiInvoke(const Proc: TProc);
var
  Invoker: TMainThreadInvoker;
begin
  if not Assigned(Proc) or FShuttingDown then
    Exit;
  if TThread.CurrentThread.ThreadID = MainThreadID then
    Proc()
  else
  begin
    Invoker := TMainThreadInvoker.Create(Proc);
    TThread.Queue(nil, Invoker.Invoke);
  end;
end;

procedure TMainForm.RunAsync(const Proc: TProc);
begin
  if FShuttingDown or not Assigned(Proc) then
    Exit;
  TTask.Run(Proc);
end;

function TMainForm.StripNoiseTokens(const Text: string): string;
begin
  Result := Trim(TRegEx.Replace(Text, NoiseTokenPattern, ' '));
end;

function TMainForm.CleanTranscriptText(const Text: string): string;
begin
  // Strip bracketed/parenthetical noise tokens and collapse whitespace. Subtitle-credit and
  // thank-you outros that Whisper invents on silence are dropped at the source by the engine's
  // multilingual hallucination filter, so no per-language phrase lists are needed here.
  Result := StripNoiseTokens(Text);
  Result := TRegEx.Replace(Result, '\s+', ' ').Trim;
end;

procedure TMainForm.WaitLiveBusyIdle(TimeoutMs: Cardinal);
var
  Start: Int64;
begin
  Start := Int64(GetTickCount64);
  while FLiveBusy and (Int64(GetTickCount64) - Start < Int64(TimeoutMs)) do
    Sleep(10);
end;

procedure TMainForm.ApplyLivePreview(const Text: string; const DiagTag: string);
var
  Show, Tag: string;
begin
  Show := CleanTranscriptText(Text);
  if Show.IsEmpty then
    Exit;
  if not ShouldShowHearingPreview(Show) then
    Exit;
  Tag := DiagTag;
  UiInvoke(procedure
  begin
    if SameText(Show, FLastLivePreview) then
      Exit;
    FLastLivePreview := Show;
    if Tag <> '' then
      LiveTransDiagWrite(Tag + '="' + LiveTransDiagSanitize(Show) + '"');
    txtTranscript.Lines.Text := Show;
    txtTranscript.SelStart := Length(txtTranscript.Text);
    SendMessage(txtTranscript.Handle, EM_SCROLLCARET, 0, 0);
    ControlHideCaret(txtTranscript);
  end);
end;

function TMainForm.NormalizeQuestionKey(const Text: string): string;
begin
  Result := Text.ToLower;
  Result := TRegEx.Replace(Result, '[^\p{L}\p{N}\s]', ' ');
  Result := TRegEx.Replace(Result, '\s+', ' ').Trim;
end;

function TMainForm.IsDuplicateAutoQuestion(const Text: string): Boolean;
var
  Key: string;
begin
  // Pure check (no mutation): a segment counts as duplicate only if we actually *answered*
  // the same text within the window. The key is recorded in RecordAutoQuestionAnswered after
  // a successful answer, so a segment that was detected but never answered (rejected by a
  // later gate, or the model returned [[SKIP]]) does not block a legitimate repeat of the
  // question — e.g. when the interviewer re-asks because the candidate stayed silent.
  Key := NormalizeQuestionKey(Text);
  if Length(Key) < 8 then Exit(False);
  Result := (Key = FLastAutoQuestionKey) and
            (Int64(GetTickCount64) - FLastAutoQuestionTicks < DuplicateQuestionMs);
end;

procedure TMainForm.RecordAutoQuestionAnswered(const Text: string);
var
  Key: string;
begin
  Key := NormalizeQuestionKey(Text);
  if Length(Key) < 8 then Exit;
  FLastAutoQuestionKey := Key;
  FLastAutoQuestionTicks := Int64(GetTickCount64);
end;

function ParamHasShowFlag: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if SameText(ParamStr(I), '--show') then
      Exit(True);
end;

// Mirrors HardwareProbe.IsBlackwellNvidiaGpu (C# engine): NVIDIA Blackwell (RTX 50xx) is the
// only family where CUDA support is incomplete and the engine defaults to Vulkan — the
// "Force CUDA" menu toggle is only meaningful (and only shown) on these GPUs.
function MainGpuIsBlackwellNvidia: Boolean;
const
  VideoClassKey = '\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}';
var
  Reg: TRegistry;
  Keys: TStringList;
  I, Dummy: Integer;
  Provider, Desc: string;
begin
  Result := False;
  Reg := TRegistry.Create(KEY_READ);
  Keys := TStringList.Create;
  try
    try
      Reg.RootKey := HKEY_LOCAL_MACHINE;
      if not Reg.OpenKeyReadOnly(VideoClassKey) then
        Exit;
      Reg.GetKeyNames(Keys);
      Reg.CloseKey;
      for I := 0 to Keys.Count - 1 do
      begin
        if not TryStrToInt(Keys[I], Dummy) then
          Continue; // adapter subkeys are numeric (0000, 0001, ...)
        if not Reg.OpenKeyReadOnly(VideoClassKey + '\' + Keys[I]) then
          Continue;
        try
          Provider := '';
          Desc := '';
          if Reg.ValueExists('ProviderName') then
            Provider := Reg.ReadString('ProviderName');
          if Reg.ValueExists('DriverDesc') then
            Desc := Reg.ReadString('DriverDesc');
          if ContainsText(Provider, 'NVIDIA') and
             (ContainsText(Desc, 'RTX 50') or ContainsText(Desc, 'RTX 60') or
              ContainsText(Desc, 'Blackwell')) then
            Exit(True);
        finally
          Reg.CloseKey;
        end;
      end;
    except
      // registry not readable: keep the toggle hidden
    end;
  finally
    Keys.Free;
    Reg.Free;
  end;
end;

procedure TMainForm.CreateParams(var Params: TCreateParams);
begin
  inherited;
  Params.ExStyle := Params.ExStyle or WS_EX_LAYERED;
end;

function TMainForm.ResponsePlainText: string;
begin
  Result := rtbResponse.Lines.Text;
end;

procedure TMainForm.ApplyOpacity;
begin
  AlphaBlend := True;
  if HandleAllocated then
    SetLayeredWindowAttributes(Handle, 0, AlphaBlendValue, LWA_ALPHA);
end;

procedure TMainForm.UpdateContextIndicator;
var
  Pct, ConvUsed, ConvBudget: Integer;
begin
  Pct := FEngine.ChatFillPercent;
  if Pct < 0 then
    Pct := 0;
  if Pct > 100 then
    Pct := 100;
  ConvUsed := FEngine.ChatUsedTokens - FEngine.ChatBaselineTokens;
  if ConvUsed < 0 then
    ConvUsed := 0;
  ConvBudget := FEngine.ChatMaxTokens - FEngine.ChatBaselineTokens;
  if ConvBudget < 1 then
    ConvBudget := 1;

  btnNew.Caption := GlyphNewChat + Format('   %d%%', [Pct]);
  btnNew.Hint := Format(
    'New session (resets chat). Conversation memory: %d / %d tokens (%d%%). ' +
    'System prompt and profile are not counted.',
    [ConvUsed, ConvBudget, Pct]);
end;

procedure TMainForm.RefreshContextIndicator;
begin
  RunAsync(procedure
  var
    U, M: Integer;
  begin
    try
      FEngine.QueryChatContext(U, M);
    except
      on E: Exception do
        DebugLogWrite('[MainForm] context status: ' + E.Message);
    end;
    UiInvoke(procedure
    begin
      UpdateContextIndicator;
    end);
  end);
end;

procedure TMainForm.AdjustOpacityByStep(Down: Boolean);
var
  Pct: Integer;
begin
  if FModelBusy then Exit;
  Pct := Round(AlphaBlendValue / 255 * 100);
  Pct := Round(Pct / OpacityStepPct) * OpacityStepPct;
  if Down then
    Pct := Max(OpacityMinPct, Pct - OpacityStepPct)
  else
    Pct := Min(100, Pct + OpacityStepPct);
  AlphaBlendValue := Round(Pct / 100 * 255);
  ApplyOpacity;
  RegistrySetInt('OpacityPct', Pct);
  SetStatus(Format('Opacity: %d%%', [Pct]));
end;

procedure TMainForm.UpdateTaskbarVisibility;
begin
  ShowInTaskbar := not FHiddenFromCapture;
end;

procedure TMainForm.InitTrayIcon;
var
  SysIcon: HICON;
begin
  if Application.Icon.Handle <> 0 then
    trayIcon.Icon.Assign(Application.Icon);
  if trayIcon.Icon.Handle = 0 then
  begin
    SysIcon := LoadIcon(0, IDI_APPLICATION);
    if SysIcon <> 0 then
      trayIcon.Icon.Handle := CopyIcon(SysIcon);
  end;
  try
    trayIcon.Visible := trayIcon.Icon.Handle <> 0;
  except
    trayIcon.Visible := False;
  end;
end;

procedure TMainForm.TitleBarMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbLeft then Exit;
  if not HandleAllocated then Exit;
  ReleaseCapture;
  SendMessage(Handle, WM_NCLBUTTONDOWN, HTCAPTION, 0);
end;

procedure TMainForm.ApplyCaptureHiding;
begin
  try
    if FHiddenFromCapture then
      SetWindowDisplayAffinity(Handle, SI_WDA_EXCLUDEFROMCAPTURE)
    else
      SetWindowDisplayAffinity(Handle, SI_WDA_NONE);
  except
  end;
  miHideCapture.Checked := FHiddenFromCapture;
end;

procedure TMainForm.SetStatus(const Text: string);
var
  Msg: string;
begin
  Msg := Text;
  UiInvoke(procedure
  begin
    lblStatusBar.Caption := Msg;
  end);
end;

procedure TMainForm.ShowGpuLoadStatus;
begin
  RunAsync(procedure
  var
    Msg: string;
  begin
    Msg := FEngine.GpuLoadStatusText;
    UiInvoke(procedure
    begin
      lblStatusBar.Caption := Msg;
    end);
  end);
end;

procedure TMainForm.SetActionsEnabled(Enabled: Boolean);
begin
  UiInvoke(procedure
  begin
    btnSetup.Enabled := Enabled;
    btnAuto.Enabled := Enabled;
    btnNew.Enabled := Enabled;
    btnOpUp.Enabled := Enabled;
    btnOpDn.Enabled := Enabled;
    btnMenu.Enabled := Enabled;
    btnPin.Enabled := Enabled;
  end);
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FEngine := TakeStartupEngine;
  if FEngine = nil then
    raise Exception.Create('Engine was not initialized during startup.');
  FAudio := TAudioCapture.Create;
  FHook := TGlobalKeyboardHook.Create;
  FSegmenter := TVoiceSegmenter.Create;
  FReadMic := TMicCapture.Create;
  FMatcher := TReadAlongMatcher.Create;
  FMicMonitor := TWasapi16kSource.Create;
  FProfile := ProfileLoad;
  FIntelligence := GetResponseIntelligence;
  FTranscription := GetTranscriptionIntelligence;
  FAnswerLength := GetAnswerLength;
  FLangCode := RegistryGetString('Language');
  if FLangCode.IsEmpty then FLangCode := 'en';
  FLangName := LangNameForCode(FLangCode);
  FListeningKey := ListeningKeyLoadSaved;
  FScrollMode := smAuto;
  FAutoSpeed := 26;
  // Manual-mode mic capture is OFF by default: by default a manual capture records PC audio
  // only. The user opts in from Microphone settings. (Read-along voice scrolling uses its own
  // microphone and is unaffected by this.)
  FUseMic := RegistryGetInt('UseMic', 0) <> 0;
  FHiddenFromCapture := not ParamHasShowFlag;
  FEnginePingFails := 0;
  FEnginePingBusy := False;
  FLicenseCheckBusy := False;
  FLicenseTimer := TTimer.Create(Self);
  FLicenseTimer.Interval := 30 * 60 * 1000;
  FLicenseTimer.OnTimer := tmrLicenseTimer;
  FLicenseTimer.Enabled := False;
  LicenseMonitorPrimeFromStore(LicenseStoreGetForumUsername, LicenseStoreGet);
  // Only Blackwell (RTX 50xx) defaults to Vulkan; on every other GPU the toggle is
  // meaningless, so it stays hidden.
  miForceCuda.Visible := MainGpuIsBlackwellNvidia;
  miGpuSep.Visible := miForceCuda.Visible;
  FReady := True;
  FModelBusy := False;
  FModelLock := TCriticalSection.Create;
  FShuttingDown := False;
  FSettingsMonitoring := False;
  ShowInTaskbar := not FHiddenFromCapture;
  pnlTitleBar.OnMouseDown := TitleBarMouseDown;
  pnlIndicators.OnMouseDown := TitleBarMouseDown;
  pnlStatus.OnMouseDown := TitleBarMouseDown;
  lblStatusBar.OnMouseDown := TitleBarMouseDown;
  AlphaBlend := True;
  // Restore the last opacity the user chose (clamped to the allowed range); 100% on first run.
  AlphaBlendValue := Round(EnsureRange(RegistryGetInt('OpacityPct', 100),
    OpacityMinPct, 100) / 100 * 255);
  FormStyle := fsStayOnTop;
  FMicVoiceTicks := 0;
  FMicMonitorIgnoreUntil := 0;
  FMicThreshold := LoadMicThresholdFromRegistry;
  FAudio.MicSpeechThreshold := FMicThreshold;
  FMicRmsLast := 0;
  FMicRmsDisplay := 0;
  ApplyVadTo(FSegmenter);
  FHook.SetListeningKey(FListeningKey);
  FHook.OnListeningKeyPressed := HookListeningKeyPressed;
  FHook.OnListeningKeyReleased := HookListeningKeyReleased;
  FHook.OnToggleTopmostPressed := HookToggleTopmost;
  FHook.OnOpacityDownPressed := HookOpacityDown;
  FHook.OnOpacityUpPressed := HookOpacityUp;
  FAudio.OnSystemSamples := OnSystemSamples;
  FMicMonitor.OnSamples16k := OnMicMonitor;
  FSegmenter.OnSpeechStarted := OnAutoSpeechStarted;
  FSegmenter.OnSpeechProgress := OnAutoProgress;
  FSegmenter.OnSegmentReady := OnAutoSegment;
  StyleIndicatorPaintBoxes;
  FRespColor := clWindowText;
  FReadDoneColor := clGrayText;
  rtbResponse.HideSelection := True;
  txtTranscript.HideSelection := True;
  InitTrayIcon;
  RefreshIntelligenceMenu;
  RefreshTranscriptionMenu;
  SyncMenuFromSettings;
  UpdateAutoVisual;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FShuttingDown := True;
  tmrLive.Enabled := False;
  tmrRead.Enabled := False;
  tmrAnim.Enabled := False;
  tmrIcon.Enabled := False;
  tmrEngine.Enabled := False;
  if FSegmenter <> nil then
  begin
    FSegmenter.OnSegmentReady := nil;
    FSegmenter.OnSpeechProgress := nil;
    FSegmenter.OnSpeechStarted := nil;
  end;
  if FHook <> nil then
  begin
    FHook.OnListeningKeyPressed := nil;
    FHook.OnListeningKeyReleased := nil;
    FHook.OnToggleTopmostPressed := nil;
    FHook.OnOpacityDownPressed := nil;
    FHook.OnOpacityUpPressed := nil;
  end;
  FEngine.CancelGeneration;
  if FAudio <> nil then
  begin
    if FAudio.IsCapturing then
      FAudio.StopCapture;
  end;
  if FReadMic <> nil then
    FReadMic.Stop;
  if FMicMonitor <> nil then
    FMicMonitor.Stop;
  FModelLock.Free;
  FHook.Free;
  FEngine.Stop;
  FEngine.Free;
  FAudio.Free;
  FSegmenter.Free;
  FReadMic.Free;
  FMatcher.Free;
  FMicMonitor.Free;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  ApplyOpacity;
  ApplyCaptureHiding;
  UpdatePinVisual;
  UpdateInterviewBanner;
  StartMicMonitor;
  tmrIcon.Enabled := True;
  tmrEngine.Enabled := True;
  if rtbResponse.HandleAllocated then
  begin
    ShowScrollBar(rtbResponse.Handle, SB_VERT, False);
    ShowScrollBar(rtbResponse.Handle, SB_HORZ, False);
    RichEditHideCaret(rtbResponse);
  end;
  if txtTranscript.HandleAllocated then
  begin
    ShowScrollBar(txtTranscript.Handle, SB_VERT, False);
    ShowScrollBar(txtTranscript.Handle, SB_HORZ, False);
    ControlHideCaret(txtTranscript);
  end;
  try
    FHook.Start;
  except
    on E: Exception do
      SetStatus('Keyboard hook unavailable: ' + E.Message);
  end;
  SetActionsEnabled(True);
  ShowGpuLoadStatus;
  RefreshContextIndicator;
  FLicenseTimer.Enabled := True;
end;

procedure TMainForm.OnEngineProgress(Sender: TObject; const Phase: string; Progress: Double);
var
  NowTick: Int64;
begin
  NowTick := Int64(GetTickCount64);
  if (Progress >= 0) and (Progress < 1.0) and (NowTick - FProgressLastUpdate < 120) then
    Exit;
  FProgressLastUpdate := NowTick;
  SetStatus(StartupProgressText(Phase, FIntelligence, FTranscription, Progress));
end;

procedure TMainForm.HookListeningKeyPressed;
begin
  UiInvoke(procedure
  begin
    OnListeningKeyPressed;
  end);
end;

procedure TMainForm.HookListeningKeyReleased;
begin
  UiInvoke(procedure
  begin
    OnListeningKeyReleased;
  end);
end;

procedure TMainForm.HookToggleTopmost;
begin
  UiInvoke(procedure
  begin
    miTopmostClick(nil);
  end);
end;

procedure TMainForm.HookOpacityDown;
begin
  UiInvoke(procedure
  begin
    btnOpDnClick(nil);
  end);
end;

procedure TMainForm.HookOpacityUp;
begin
  UiInvoke(procedure
  begin
    btnOpUpClick(nil);
  end);
end;

procedure TMainForm.OnListeningKeyPressed;
begin
  if not FReady or FListening or FAutoMode then Exit;
  if not RequireProfileToStart then Exit;
  // Barge-in: if the model is mid-answer, abandon that answer so the user can immediately ask a
  // new question instead of waiting for the generation to finish. Bumping the answer generation
  // makes any in-flight stream's tokens be ignored, and CancelGeneration tells the engine to stop
  // generating right now (it honours the cancel mid-stream), freeing it for the new question. The
  // finalize step on key release still waits for the model to be free, which now happens quickly.
  if FModelBusy then
  begin
    Inc(FAutoAnswerGen);
    FStreamSkip := True;
    FEngine.CancelGeneration;
  end;
  StopReadAlong;
  FListening := True;
  FLastLivePreview := '';
  FLiveReschedule := False;
  LiveTransDiagClear;
  LiveTransDiagWrite('log=' + LiveTransDiagPath);
  LiveTransDiagWrite('CTRL DOWN  session=' + IntToStr(FListenSession + 1) +
    '  tier=' + WhisperTierDiagLabel + '  lang=' + FLangCode + '  mode=full-buffer-replace');
  UiInvoke(procedure
  begin
    txtTranscript.Clear;
    rtbResponse.Clear;
  end);
  SetStatus('');
  try
    FAudio.Start(FUseMic);
  except
    on E: Exception do
    begin
      FListening := False;
      SetStatus('Error: Audio: ' + E.Message);
      RefreshIndicators;
      Exit;
    end;
  end;
  tmrLive.Enabled := True;
  RefreshIndicators;
end;

procedure TMainForm.RunListenFinalize(const ASnap: TArray<Single>; const APreview: string; ASession: Integer);
var
  SnapCopy: TArray<Single>;
  PreviewCopy: string;
begin
  SnapCopy := Copy(ASnap, 0, Length(ASnap));
  PreviewCopy := APreview;
  FListenFinalSession := ASession;
  RunAsync(procedure
  var
    Text: string;
    Answered: Boolean;
    LocalSnap: TArray<Single>;
    LocalPreview: string;
    LocalSession: Integer;
  begin
    LocalSnap := SnapCopy;
    LocalPreview := PreviewCopy;
    LocalSession := ASession;
    try
      try
        WaitLiveBusyIdle(5000);
        if (LocalSession <> FListenSession) or (LocalSession <> FListenFinalSession) then
        begin
          LiveTransDiagWrite('FINAL skipped stale session');
          Exit;
        end;
        FModelLock.Enter;
        try
          while FModelBusy do
          begin
            FModelLock.Leave;
            Sleep(25);
            if FShuttingDown then
              Exit;
            FModelLock.Enter;
          end;
          FModelBusy := True;
        finally
          FModelLock.Leave;
        end;
        if (LocalSession <> FListenSession) or (LocalSession <> FListenFinalSession) then
          Exit;
        if Length(LocalSnap) < LiveMinPreviewSamples then
        begin
          LiveTransDiagWrite(Format('FINAL skip short audio=%d', [Length(LocalSnap)]));
          SetStatus('Hold ' + ListeningKeyDisplayName(FListeningKey) + ' a little longer while speaking.');
          Exit;
        end;
        // Trim silent edges and bail out if there is no real speech: feeding silence to
        // Whisper is what makes it hallucinate phrases like "Grazie".
        LocalSnap := AudioTrimSilence(LocalSnap, ManualSpeechThreshold);
        if (Length(LocalSnap) < LiveMinPreviewSamples) or
           not AudioHasSpeech(LocalSnap, ManualSpeechThreshold) then
        begin
          LiveTransDiagWrite('FINAL skip no-speech');
          SetStatus('No speech detected. Try again (' + ListeningKeyHoldHint(FListeningKey) + ').');
          Exit;
        end;
        if not TranscribeAsync(LocalSnap, Text) or Text.Trim.IsEmpty then
        begin
          LiveTransDiagWrite('FINAL empty or failed');
          SetStatus('');
          Exit;
        end;
        Text := CleanTranscriptText(Text);
        LiveTransDiagWrite('FINAL text="' + LiveTransDiagSanitize(Text) + '"');
        LiveTransDiagWrite('HEARING was="' + LiveTransDiagSanitize(LocalPreview) + '"');
        LiveTransDiagWrite(Format('DIFF hearing_len=%d final_len=%d',
          [Length(LocalPreview), Length(Text)]));
        if not ShouldCommitHearing(Text) then
        begin
          LiveTransDiagWrite('FINAL skip noise/hallucination');
          SetStatus('No speech detected. Try again (' + ListeningKeyHoldHint(FListeningKey) + ').');
          Exit;
        end;
        SetTranscript(Text);
        UiInvoke(procedure
        begin
          FLastLivePreview := Text;
        end);
        SetStatus('Answering...');
        PrepareResponseForStreaming;
        // Manual capture: the user pressed the key on purpose, so a question was
        // certainly asked. Force an answer (engine never returns SKIP here).
        Answered := StreamAnswer(Text, True);
        UiInvoke(procedure
        begin
          UpdateContextIndicator;
        end);
        if Answered then
        begin
          SetStatus('');
          UiInvoke(procedure
          begin
            StartReadAlong;
          end);
        end
        else
          SetStatus('No answer generated. Try again.');
      except
        on E: Exception do
        begin
          DebugLogWrite('[MainForm] listen transcribe: ' + E.Message);
          SetStatus('Transcribe error: ' + E.Message);
        end;
      end;
    finally
      FModelLock.Enter;
      try
        FModelBusy := False;
      finally
        FModelLock.Leave;
      end;
    end;
  end);
end;

procedure TMainForm.OnListeningKeyReleased;
var
  Snap: TArray<Single>;
  Session: Integer;
  LiveBeforeFinal: string;
begin
  if not FListening or FAutoMode then Exit;
  tmrLive.Enabled := False;
  FListening := False;
  Inc(FListenSession);
  FLiveReschedule := False;
  Session := FListenSession;
  LiveBeforeFinal := FLastLivePreview;
  RefreshIndicators;
  Snap := FAudio.StopCapture;
  if Length(Snap) = 0 then
  begin
    SetStatus('No audio captured.');
    Exit;
  end;
  LiveTransDiagWrite('CTRL UP  session=' + IntToStr(Session) + '  audio_samples=' +
    IntToStr(Length(Snap)) + '  hearing="' + LiveTransDiagSanitize(LiveBeforeFinal) + '"');
  SetStatus('Transcribing...');
  RunListenFinalize(Snap, LiveBeforeFinal, Session);
end;

procedure TMainForm.tmrLiveTimer(Sender: TObject);
begin
  if not FListening then
    Exit;
  ScheduleLiveTranscribe;
end;

function TMainForm.TranscribeAsync(const Samples: TArray<Single>; out Text: string): Boolean;
begin
  Result := FEngine.Transcribe(Samples, Text);
end;

procedure TMainForm.ScheduleLiveTranscribe;
var
  Session: Integer;
begin
  if not FListening then
    Exit;
  if FLiveBusy then
  begin
    FLiveReschedule := True;
    Exit;
  end;
  FLiveBusy := True;
  FLiveReschedule := False;
  Session := FListenSession;
  RunAsync(procedure
  var
    Snap: TArray<Single>;
    Text: string;
    SnapTotal: Integer;
  begin
    try
      try
        if not FListening or (Session <> FListenSession) then
          Exit;
        Snap := FAudio.Snapshot;
        SnapTotal := Length(Snap);
        LiveTransDiagWrite(Format('LIVE snap_total=%d', [SnapTotal]));
        if SnapTotal < LiveMinPreviewSamples then
        begin
          LiveTransDiagWrite(Format('LIVE skip need>=%d samples', [LiveMinPreviewSamples]));
          Exit;
        end;
        Snap := AudioTrimSilence(Snap, ManualSpeechThreshold);
        if (Length(Snap) < LiveMinPreviewSamples) or
           not AudioHasSpeech(Snap, ManualSpeechThreshold) then
        begin
          LiveTransDiagWrite('LIVE skip no-speech');
          Exit;
        end;
        // Live preview uses the engine's live path (ALive=True): with Parakeet this suppresses
        // half-spoken audio under ~1.5s, which would otherwise auto-detect the wrong language and
        // show invented English. The FINAL transcription (RunListenFinalize) stays on the
        // non-live path, so short complete questions are still transcribed.
        if not FEngine.TranscribeStream(Snap, nil, Text, True) or
           not FListening or (Session <> FListenSession) then
          Exit;
        Text := CleanTranscriptText(Text);
        if Text.IsEmpty or not ShouldShowHearingPreview(Text) then
        begin
          LiveTransDiagWrite('LIVE skip noise/hallucination');
          Exit;
        end;
        ApplyLivePreview(Text, 'LIVE hearing');
      except
        on E: Exception do
          LiveTransDiagWrite('LIVE error: ' + E.ClassName);
      end;
    finally
      FLiveBusy := False;
      if FLiveReschedule and FListening and (Session = FListenSession) then
      begin
        FLiveReschedule := False;
        ScheduleLiveTranscribe;
      end;
    end;
  end);
end;

function TMainForm.WhisperTierDiagLabel: string;
var
  Info: TWhisperModelInfo;
begin
  Info := WhisperCatalogGet(FTranscription);
  Result := Info.LabelText + ' (' + Info.FileName + ')';
end;

procedure TMainForm.HandleStreamToken(Sender: TObject; const Token: string);
var
  Trimmed, Clean: string;
begin
  if FStreamSkip then Exit;
  if FStreamAnswerGen <> FAutoAnswerGen then
  begin
    FStreamSkip := True;
    FEngine.CancelGeneration;
    Exit;
  end;
  if not FStreamDecided then
  begin
    FStreamBuf := FStreamBuf + Token;
    Trimmed := Trim(FStreamBuf);
    if Trimmed.IsEmpty then Exit;
    // Manual capture: the user pressed the listen key on purpose — never treat [[SKIP]] as
    // "not a question"; strip the marker if the model emits it and keep the answer.
    if not FStreamForce then
    begin
      if (Length(Trimmed) < Length(SkipMarker)) and
         SameText(Copy(SkipMarker, 1, Length(Trimmed)), Trimmed) then Exit;
      if StartsText(SkipMarker, Trimmed) then
      begin
        FStreamSkip := True;
        FStreamDecided := True;
        Exit;
      end;
    end
    else if StartsText(SkipMarker, Trimmed) then
    begin
      Trimmed := Trim(Copy(Trimmed, Length(SkipMarker) + 1, MaxInt));
      FStreamBuf := Trimmed;
      if Trimmed.IsEmpty then Exit;
    end;
    FStreamDecided := True;
    PrepareResponseForStreaming;
    FStreamAnswer := Trimmed;
    Clean := SanitizeAnswer(FStreamAnswer);
    if Length(Clean) > FStreamShown then
    begin
      AppendResponse(Copy(Clean, FStreamShown + 1, MaxInt));
      FStreamShown := Length(Clean);
    end;
    Exit;
  end;
  FStreamAnswer := FStreamAnswer + Token;
  Clean := SanitizeAnswer(FStreamAnswer);
  if Length(Clean) > FStreamShown then
  begin
    AppendResponse(Copy(Clean, FStreamShown + 1, MaxInt));
    FStreamShown := Length(Clean);
  end;
end;

function TMainForm.BuildManualCapturePrompt(const Transcript: string): string;
begin
  Result :=
    'The candidate manually captured this audio because an interview question was just asked. ' +
    'There is definitely a question here: always answer directly in first person as the candidate. ' +
    'Never reply with [[SKIP]] alone. If the transcription is messy, infer the most likely question ' +
    'and answer it. Transcription: ' + Transcript;
end;

function TMainForm.StreamAnswer(const Question: string; Force: Boolean): Boolean;
var
  Prompt: string;
begin
  Result := False;
  FStreamBuf := '';
  FStreamAnswer := '';
  FStreamDecided := False;
  FStreamSkip := False;
  FStreamShown := 0;
  FStreamForce := Force;
  FStreamAnswerGen := FAutoAnswerGen;
  if Force then
    Prompt := BuildManualCapturePrompt(Question)
  else
    Prompt := Question;
  if not FEngine.GenerateStream(Prompt, HandleStreamToken) then Exit;
  if (not Force) and (FStreamSkip or not FStreamDecided or (FStreamShown = 0)) then
  begin
    FEngine.DropLastExchange;
    Exit(False);
  end;
  Result := FStreamShown > 0;
end;

procedure TMainForm.SetTranscript(const Text: string);
var
  Clean: string;
begin
  Clean := CleanTranscriptText(Text);
  if Clean.IsEmpty then Exit;
  if TThread.CurrentThread.ThreadID = MainThreadID then
  begin
    txtTranscript.Lines.Text := Clean;
    txtTranscript.SelStart := Length(txtTranscript.Text);
    SendMessage(txtTranscript.Handle, EM_SCROLLCARET, 0, 0);
    ControlHideCaret(txtTranscript);
  end
  else
    UiInvoke(procedure
    begin
      txtTranscript.Lines.Text := Clean;
      txtTranscript.SelStart := Length(txtTranscript.Text);
      SendMessage(txtTranscript.Handle, EM_SCROLLCARET, 0, 0);
      ControlHideCaret(txtTranscript);
    end);
end;

procedure TMainForm.AppendResponse(const Text: string);
var
  Value: string;
  StartPos: Integer;
begin
  Value := Text;
  if TThread.CurrentThread.ThreadID = MainThreadID then
  begin
    StartPos := Length(ResponsePlainText);
    KeepScrollAppendResponse(Value, StartPos);
  end
  else
    UiInvoke(procedure
    var
      Pos: Integer;
    begin
      Pos := Length(ResponsePlainText);
      KeepScrollAppendResponse(Value, Pos);
    end);
end;

procedure TMainForm.KeepScrollAppendResponse(const Value: string; StartPos: Integer);
var
  KeepLine, NowLine: Integer;
begin
  KeepLine := SendMessage(rtbResponse.Handle, EM_GETFIRSTVISIBLELINE, 0, 0);
  rtbResponse.SelStart := StartPos;
  rtbResponse.SelLength := 0;
  rtbResponse.SelText := Value;
  RichEditSetRangeColor(rtbResponse, StartPos, Length(Value), FRespColor);
  NowLine := SendMessage(rtbResponse.Handle, EM_GETFIRSTVISIBLELINE, 0, 0);
  SendMessage(rtbResponse.Handle, EM_LINESCROLL, 0, KeepLine - NowLine);
  RichEditHideCaret(rtbResponse);
end;

procedure TMainForm.PrepareResponseForStreaming;
begin
  UiInvoke(procedure
  begin
    StopReadAlong;
    rtbResponse.Clear;
    rtbResponse.Font.Color := FRespColor;
    rtbResponse.SelStart := 0;
    FColoredChars := 0;
  end);
end;

procedure TMainForm.OnSystemSamples(const Samples: TArray<Single>);
var
  I: Integer;
  Sum: Double;
  Rms: Single;
begin
  if FAutoMode then
    FSegmenter.Push(Samples);
  Sum := 0;
  for I := 0 to High(Samples) do
    Sum := Sum + Samples[I] * Samples[I];
  Rms := Sqrt(Sum / Max(1, Length(Samples)));
  if Rms > FSegmenter.Threshold then
    FPcVoiceTicks := GetTickCount64;
end;

procedure TMainForm.OnMicMonitor(const Samples: TArray<Single>);
var
  I, N: Integer;
  Mean, SumSq: Double;
  Rms, V, Peak, AbsV: Single;
begin
  N := Length(Samples);
  if N = 0 then
    Exit;
  Mean := 0;
  for I := 0 to N - 1 do
    Mean := Mean + Samples[I];
  Mean := Mean / N;
  SumSq := 0;
  Peak := 0;
  for I := 0 to N - 1 do
  begin
    V := Samples[I] - Single(Mean);
    AbsV := Abs(V);
    if AbsV > Peak then
      Peak := AbsV;
    SumSq := SumSq + V * V;
  end;
  Rms := Sqrt(SumSq / N);
  if (Peak > 1.05) or IsNan(Rms) or IsInfinite(Rms) then
    Exit;
  if Rms > 1.0 then
    Rms := 1.0;
  // Reject single-buffer spikes (format glitches / driver hiccups).
  if Rms > FMicRmsDisplay + MicMeterMaxStep then
    Rms := FMicRmsDisplay + MicMeterMaxStep;
  // Meter: fast rise, slow fall so the bar tracks speech naturally.
  if Rms > FMicRmsDisplay then
    FMicRmsDisplay := Rms
  else
    FMicRmsDisplay := FMicRmsDisplay * 0.90 + Rms * 0.10;
  FMicRmsLast := FMicRmsDisplay;
  if Int64(GetTickCount64) < FMicMonitorIgnoreUntil then
    Exit;
  if Rms > FMicThreshold then
    FMicVoiceTicks := Int64(GetTickCount64);
end;

function TMainForm.ManualSpeechThreshold: Single;
begin
  if FUseMic then
    Result := FMicThreshold
  else
    Result := -1;
end;

function TMainForm.LoadMicThresholdFromRegistry: Single;
var
  Raw: Integer;
begin
  Result := MicDefaultThreshold;
  Raw := RegistryGetInt('MicThreshold', -1);
  if Raw < 0 then
    Exit;
  if Raw > 100 then
    Result := Raw / 10000.0
  else
    Result := Raw / 1000.0;
  if Result > 1.0 then
    Result := 1.0;
end;

procedure TMainForm.StyleIndicatorPaintBoxes;
begin
  pbWaveform.ControlStyle := pbWaveform.ControlStyle + [csParentBackground];
  pbMic.ControlStyle := pbMic.ControlStyle + [csParentBackground];
end;

function TMainForm.IsWaveRecording: Boolean;
begin
  Result := FListening or (FAutoMode and (Int64(GetTickCount64) - FPcVoiceTicks < 300));
end;

function TMainForm.IsMicActive: Boolean;
begin
  // In automatic mode the microphone is disabled (the app listens to PC audio only),
  // so the indicator must stay off regardless of ambient noise.
  if FAutoMode then
    Exit(False);
  if FMicVoiceTicks = 0 then
    Exit(False);
  if Int64(GetTickCount64) < FMicMonitorIgnoreUntil then
    Exit(False);
  Result := Int64(GetTickCount64) - FMicVoiceTicks < MicActiveHoldMs;
end;

procedure TMainForm.RefreshIndicators;
begin
  pbWaveform.Invalidate;
  if pbMic.Visible then
    pbMic.Invalidate;
end;

procedure TMainForm.StartMicMonitor;
begin
  FMicMonitor.Stop;
  FMicVoiceTicks := 0;
  FMicRmsDisplay := 0;
  FMicRmsLast := 0;
  FMicMonitorIgnoreUntil := Int64(GetTickCount64) + MicMonitorWarmupMs;
  pbMic.Visible := FMicMonitor.Start;
  RefreshIndicators;
end;

procedure TMainForm.pbWaveformPaint(Sender: TObject);
begin
  PaintTitleWaveform(pbWaveform, IsWaveRecording, FWavePhase);
end;

procedure TMainForm.pbMicPaint(Sender: TObject);
begin
  if pbMic.Visible then
    PaintTitleMic(pbMic, IsMicActive);
end;

procedure TMainForm.tmrIconTimer(Sender: TObject);
begin
  FWavePhase := FWavePhase + 0.35;
  RefreshIndicators;
end;

procedure TMainForm.ToggleAutoMode;
begin
  if FModelBusy or not FReady then Exit;
  if not FAutoMode and not RequireProfileToStart then Exit;
  SetAutoMode(not FAutoMode);
end;

procedure TMainForm.SetAutoMode(On: Boolean);
begin
  if On = FAutoMode then Exit;
  if FModelBusy or not FReady then Exit;
  FAutoMode := On;
  UpdateAutoVisual;
  if FrmSettings.Visible then
    FrmSettings.SyncAutoMode(On);
  if On then
  begin
    if FListening then
    begin
      FListening := False;
      tmrLive.Enabled := False;
    end;
    FSegmenter.Reset;
    FLastAutoQuestionKey := '';
    FLastLivePreview := '';
    UiInvoke(procedure
    begin
      txtTranscript.Clear;
      rtbResponse.Clear;
    end);
    try
      FAudio.StopCapture;
    except
    end;
    try
      FAudio.Start(False);
    except
      on E: Exception do
      begin
        FAutoMode := False;
        UpdateAutoVisual;
        SetStatus('Audio: ' + E.Message);
        Exit;
      end;
    end;
    SetStatus('');
  end
  else
  begin
    FEngine.CancelGeneration;
    Inc(FAutoAnswerGen);
    try
      FAudio.StopCapture;
    except
    end;
    if FrmSettings.Visible then
      StartSettingsMonitor
    else if not FListening then
      StartMicMonitor;
    SetStatus('');
  end;
  RefreshIndicators;
end;

procedure TMainForm.SyncMenuFromSettings;
begin
  miLangEn.Checked := FLangCode = 'en';
  miLangEs.Checked := FLangCode = 'es';
  miLangFr.Checked := FLangCode = 'fr';
  miLangDe.Checked := FLangCode = 'de';
  miLangIt.Checked := FLangCode = 'it';
  miLangRu.Checked := FLangCode = 'ru';
  miKeyCtrl.Checked := FListeningKey = lkCtrl;
  miKeyShift.Checked := FListeningKey = lkShift;
  miKeyAlt.Checked := FListeningKey = lkAlt;
  miLenShort.Checked := FAnswerLength = alShort;
  miLenMedium.Checked := FAnswerLength = alMedium;
  miLenLong.Checked := FAnswerLength = alLong;
  miScrollOff.Checked := FScrollMode = smOff;
  miScrollAuto.Checked := FScrollMode = smAuto;
  miScrollVoice.Checked := FScrollMode = smVoice;
  miSpeed.Enabled := FScrollMode = smAuto;
  miIntelFast.Checked := FIntelligence = riFast;
  miIntelBalanced.Checked := FIntelligence = riBalanced;
  miIntelMax.Checked := FIntelligence = riMax;
  miForceCuda.Checked := RegistryGetInt('ForceCuda', 0) <> 0;
  miTransFast.Checked := FTranscription = tiFast;
  miTransBalanced.Checked := FTranscription = tiBalanced;
  miTransMax.Checked := FTranscription = tiMax;
  miTopmost.Checked := FormStyle = fsStayOnTop;
  miHideCapture.Checked := FHiddenFromCapture;
end;

procedure TMainForm.SetUseMicEnabled(Value: Boolean);
begin
  if FUseMic = Value then
    Exit;
  FUseMic := Value;
  RegistrySetInt('UseMic', Ord(FUseMic));
  if FListening and FAudio.IsCapturing then
  begin
    try
      FAudio.StopCapture;
      FAudio.Start(FUseMic);
    except
      on E: Exception do
        SetStatus('Audio: ' + E.Message);
    end;
  end;
end;

procedure TMainForm.SetListeningKeyChoice(const Key: TListeningKey);
begin
  if FListeningKey = Key then
    Exit;
  FListeningKey := Key;
  FHook.SetListeningKey(FListeningKey);
  RegistrySetInt('ListeningKey', Ord(FListeningKey));
end;

procedure TMainForm.RefreshIntelligenceMenu;
var
  Info: TLocalModelInfo;
  HasRemove: Boolean;

  procedure SetIntelCaption(Item: TMenuItem; const Level: TResponseIntelligence);
  begin
    Info := ModelCatalogGet(Level);
    Item.Checked := FIntelligence = Level;
    Item.Hint := Info.Description;
    if ModelCatalogIsInstalled(Level) then
      Item.Caption := Info.LabelText + '  |  installed'
    else
      Item.Caption := Info.LabelText + '  |  ' + ModelSizeText(Info.SizeBytes) + ' download';
  end;

  procedure SetRemoveItem(Item: TMenuItem; const Level: TResponseIntelligence);
  begin
    Info := ModelCatalogGet(Level);
    Item.Visible := ModelCatalogIsInstalled(Level) and (FIntelligence <> Level);
    if Item.Visible then
      Item.Caption := Info.LabelText + '  |  free ' + ModelSizeText(Info.SizeBytes);
  end;

begin
  SetIntelCaption(miIntelFast, riFast);
  SetIntelCaption(miIntelBalanced, riBalanced);
  SetIntelCaption(miIntelMax, riMax);
  SetRemoveItem(miRemoveFast, riFast);
  SetRemoveItem(miRemoveBalanced, riBalanced);
  SetRemoveItem(miRemoveMax, riMax);
  HasRemove := miRemoveFast.Visible or miRemoveBalanced.Visible or miRemoveMax.Visible;
  miRemoveModel.Enabled := HasRemove;
  if HasRemove then
    miRemoveModel.Caption := 'Remove a downloaded model'
  else
    miRemoveModel.Caption := 'Remove a downloaded model (none available)';
end;

procedure TMainForm.RefreshTranscriptionMenu;
var
  Info: TWhisperModelInfo;
  HasRemove: Boolean;

  procedure SetTransCaption(Item: TMenuItem; const Level: TTranscriptionIntelligence);
  begin
    Info := WhisperCatalogGet(Level);
    Item.Checked := FTranscription = Level;
    Item.Hint := Info.Description;
    if WhisperCatalogIsInstalled(Level) then
      Item.Caption := Info.LabelText + '  |  installed'
    else
      Item.Caption := Info.LabelText + '  |  ' + ModelSizeText(Info.SizeBytes) + ' download';
  end;

  procedure SetRemoveTrans(Item: TMenuItem; const Level: TTranscriptionIntelligence);
  begin
    Info := WhisperCatalogGet(Level);
    Item.Visible := WhisperCatalogIsInstalled(Level) and (FTranscription <> Level);
    if Item.Visible then
      Item.Caption := Info.LabelText + '  |  free ' + ModelSizeText(Info.SizeBytes);
  end;

begin
  SetTransCaption(miTransFast, tiFast);
  SetTransCaption(miTransBalanced, tiBalanced);
  SetTransCaption(miTransMax, tiMax);
  SetRemoveTrans(miRemoveTransFast, tiFast);
  SetRemoveTrans(miRemoveTransBalanced, tiBalanced);
  SetRemoveTrans(miRemoveTransMax, tiMax);
  HasRemove := miRemoveTransFast.Visible or miRemoveTransBalanced.Visible or miRemoveTransMax.Visible;
  miRemoveWhisper.Enabled := HasRemove;
  if HasRemove then
    miRemoveWhisper.Caption := 'Remove a downloaded model'
  else
    miRemoveWhisper.Caption := 'Remove a downloaded model (none available)';
end;

// Lights a title-bar toggle button: when active the glyph turns azure and the button shows a
// pressed state. seFont is toggled so the active azure overrides the VCL style, while the
// inactive state hands the glyph colour back to the style (correct on any theme).
procedure TMainForm.SetGlyphActive(Btn: TSpeedButton; Active: Boolean);
begin
  Btn.Down := Active;
  if Active then
  begin
    Btn.StyleElements := Btn.StyleElements - [seFont];
    Btn.Font.Color := ActiveGlyphColor;
  end
  else
    Btn.StyleElements := Btn.StyleElements + [seFont];
end;

procedure TMainForm.UpdateAutoVisual;
begin
  SetGlyphActive(btnAuto, FAutoMode);
end;

procedure TMainForm.UpdatePinVisual;
begin
  miTopmost.Checked := FormStyle = fsStayOnTop;
  if FormStyle = fsStayOnTop then
    btnPin.Caption := GlyphPin
  else
    btnPin.Caption := GlyphPinUp;
  SetGlyphActive(btnPin, FormStyle = fsStayOnTop);
end;

procedure TMainForm.OnAutoSpeechStarted;
begin
  FLastLivePreview := '';
  LiveTransDiagClear;
  LiveTransDiagWrite('log=' + LiveTransDiagPath);
  LiveTransDiagWrite('AUTO speech started  tier=' + WhisperTierDiagLabel + '  lang=' + FLangCode +
    '  mode=replace-full-segment');
end;

procedure TMainForm.OnAutoProgress(const Seg: TArray<Single>);
var
  SegCopy: TArray<Single>;
begin
  if not FAutoMode or FAutoBusy then
    Exit;
  SegCopy := Seg;
  FAutoBusy := True;
  RunAsync(procedure
  var
    Text: string;
  begin
    try
      SegCopy := AudioTrimSilence(SegCopy);
      if (Length(SegCopy) = 0) or not AudioHasSpeech(SegCopy) then
        Exit;
      if not TranscribeAsync(SegCopy, Text) or not FAutoMode or Text.Trim.IsEmpty then
        Exit;
      Text := CleanTranscriptText(Text);
      if not ShouldShowHearingPreview(Text) then
        Exit;
      ApplyLivePreview(Text, 'AUTO hearing');
    finally
      FAutoBusy := False;
    end;
  end);
end;

procedure TMainForm.OnAutoSegment(const Seg: TArray<Single>);
var
  SegCopy: TArray<Single>;
begin
  if not FAutoMode or FShuttingDown then
    Exit;
  SegCopy := Seg;
  RunAsync(procedure
  var
    Text: string;
    AnswerGen: Integer;
    Answered: Boolean;
    Answerable: Boolean;
    SegLocal: TArray<Single>;
  begin
    SegLocal := SegCopy;
    FModelBusy := True;
    try
      try
        if FShuttingDown then
          Exit;
        SegLocal := AudioTrimSilence(SegLocal);
        if (Length(SegLocal) = 0) or not AudioHasSpeech(SegLocal) then
          Exit;
        if not TranscribeAsync(SegLocal, Text) then
          Exit;
        Text := CleanTranscriptText(Text);
        LiveTransDiagWrite('AUTO SEGMENT FINAL text="' + LiveTransDiagSanitize(Text) + '"');
        if not HasMinimalAutoSpeech(Text) then
        begin
          SetStatus('');
          Exit;
        end;
        FEngine.CancelGeneration;
        SetStatus('Checking...');
        if not ClassifyUtteranceAsync(Text, Answerable) then
          Answerable := True;
        if not Answerable then
        begin
          SetStatus('');
          Exit;
        end;
        if IsDuplicateAutoQuestion(Text) then
        begin
          SetStatus('');
          Exit;
        end;
        if not ShouldCommitHearing(Text) then
        begin
          SetStatus('');
          Exit;
        end;
        SetTranscript(Text);
        SetStatus('Answering... (auto)');
        Inc(FAutoAnswerGen);
        AnswerGen := FAutoAnswerGen;
        FStreamAnswerGen := AnswerGen;
        PrepareResponseForStreaming;
        Answered := StreamAnswer(Text);
        if AnswerGen <> FAutoAnswerGen then
        begin
          FEngine.DropLastExchange;
          Exit;
        end;
        UiInvoke(procedure
        begin
          UpdateContextIndicator;
        end);
        if Answered then
        begin
          RecordAutoQuestionAnswered(Text);
          SetStatus('');
          UiInvoke(procedure
          begin
            StartReadAlong;
          end);
        end
        else
          SetStatus('Segment not answered - not recognized as a question');
      except
        on E: Exception do
          SetStatus('Auto transcribe error: ' + E.Message);
      end;
    finally
      FModelBusy := False;
    end;
  end);
end;

function TMainForm.HasMinimalAutoSpeech(const Text: string): Boolean;
begin
  Result := Length(Trim(StripNoiseTokens(Text))) >= 2;
end;

function TMainForm.ClassifyUtteranceAsync(const Text: string; out Answerable: Boolean): Boolean;
begin
  Result := FEngine.ClassifyUtterance(Text, Answerable);
end;

function TMainForm.IsUsefulTranscript(const Text: string): Boolean;
var
  Cleaned: string;
begin
  Result := CountRealWords(Text) >= 3;
  if not Result then
    Exit;
  Cleaned := StripNoiseTokens(Text);
  Result := not Cleaned.IsEmpty;
end;

function TMainForm.CountRealWords(const Text: string): Integer;
var
  Cleaned: string;
  Words: TArray<string>;
  I: Integer;
begin
  Cleaned := StripNoiseTokens(Text);
  if Cleaned.IsEmpty then
    Exit(0);
  Words := Cleaned.Split([' ', #9, #10, #13, ',', '.', '!', '?', ';', ':'],
    TStringSplitOptions.ExcludeEmpty);
  Result := 0;
  for I := 0 to High(Words) do
    if Length(Words[I]) >= 2 then
      Inc(Result);
end;

function TMainForm.IsLikelyNoiseHallucination(const Text: string): Boolean;
var
  Normalized: string;
begin
  Normalized := CleanTranscriptText(Text).ToLower;
  if Normalized.IsEmpty then
    Exit(True);
  // Thank-you / outro openers across every supported language (a single "grazie ..." style
  // alternation covers all the per-language variants without skewing the list to one locale).
  if TRegEx.IsMatch(Normalized,
    '^(grazie|thanks|thank you|merci|gracias|danke|obrigad[oa]|спасибо|谢谢|ありがとう)' +
    '(\s+.*)?\.?$',
    [roIgnoreCase]) then
    Exit(True);
  // Subtitle / credit markers in several languages.
  if TRegEx.IsMatch(Normalized,
    '^(sottotitoli|subtitles?|untertitel|sous-titres|subt[ií]tulos|legendas|субтитры|字幕|' +
    'translated|traduzione|revisione|copyright|\.\.\.)',
    [roIgnoreCase]) then
    Exit(True);
  Result := False;
end;

function TMainForm.ShouldShowHearingPreview(const Text: string): Boolean;
begin
  if IsLikelyNoiseHallucination(Text) then
    Exit(False);
  Result := CountRealWords(Text) >= 2;
end;

function TMainForm.ShouldCommitHearing(const Text: string): Boolean;
begin
  if IsLikelyNoiseHallucination(Text) then
    Exit(False);
  Result := IsUsefulTranscript(Text);
end;

function TMainForm.ResponseHasText: Boolean;
begin
  Result := Trim(ResponsePlainText) <> '';
end;

function TMainForm.SanitizeAnswer(const S: string): string;
var
  M: TMatch;
begin
  if S = '' then Exit('');
  if FLangCode = 'ru' then
    M := TRegEx.Match(S, '[\x{3000}-\x{303F}\x{3040}-\x{30FF}\x{3400}-\x{4DBF}\x{4E00}-\x{9FFF}\x{AC00}-\x{D7AF}\x{FF00}-\x{FFEF}]')
  else
    M := TRegEx.Match(S, '[\x{0400}-\x{04FF}\x{3000}-\x{303F}\x{3040}-\x{30FF}\x{3400}-\x{4DBF}\x{4E00}-\x{9FFF}\x{AC00}-\x{D7AF}\x{FF00}-\x{FFEF}]');
  if M.Success then
    Result := TrimRight(Copy(S, 1, M.Index))
  else
    Result := S;
end;

function TMainForm.GetRtbScrollY: Integer;
type
  TScrollPoint = record
    X: Integer;
    Y: Integer;
  end;
var
  P: TScrollPoint;
begin
  P.X := 0;
  P.Y := 0;
  SendMessage(rtbResponse.Handle, EM_GETSCROLLPOS, 0, LPARAM(@P));
  Result := P.Y;
end;

procedure TMainForm.SetRtbScrollY(Y: Integer);
type
  TScrollPoint = record
    X: Integer;
    Y: Integer;
  end;
var
  P: TScrollPoint;
begin
  P.X := 0;
  P.Y := Max(0, Y);
  SendMessage(rtbResponse.Handle, EM_SETSCROLLPOS, 0, LPARAM(@P));
end;

function TMainForm.RtbPosFromCharIndex(AIndex: Integer): TPoint;
var
  P: TPoint;
begin
  P.X := 0;
  P.Y := 0;
  SendMessage(rtbResponse.Handle, EM_POSFROMCHAR, WPARAM(AIndex), LPARAM(@P));
  Result := P;
end;

procedure TMainForm.StartReadAlong;
begin
  StopReadAlong;
  if FScrollMode = smOff then Exit;
  if not ResponseHasText then Exit;
  FMatcher.SetText(ResponsePlainText);
  if FMatcher.Count < 5 then Exit;
  FReadPos := 0;
  FConfirmedChar := 0;
  FPrevConfirmChar := 0;
  FPrevConfirmTicks := 0;
  FEstSpeed := FAutoSpeed;
  FReadStartTicks := Int64(GetTickCount64);
  FLastAnimTicks := FReadStartTicks;
  SetRtbScrollY(0);
  RichEditSetAllColor(rtbResponse, FRespColor);
  FColoredChars := 0;
  if FScrollMode = smVoice then
    if FReadMic.Start then tmrRead.Enabled := True;
  tmrAnim.Enabled := True;
end;

procedure TMainForm.StopReadAlong;
begin
  tmrAnim.Enabled := False;
  tmrRead.Enabled := False;
  FReadMic.Stop;
  FReadBusy := False;
end;

procedure TMainForm.tmrReadTimer(Sender: TObject);
begin
  if FReadBusy or not FReadMic.IsCapturing or FShuttingDown then
    Exit;
  FReadBusy := True;
  RunAsync(procedure
  var
    Audio: TArray<Single>;
    Spoken: string;
    M: Integer;
    NowTick: Int64;
    Secs, Sp: Double;
  begin
    try
      try
        Audio := FReadMic.Last(2.8);
        if Length(Audio) = 0 then
          Exit;
        if Length(Audio) < 8000 then
          Exit;
        if not TranscribeAsync(Audio, Spoken) or Spoken.Trim.IsEmpty then
          Exit;
        if not FMatcher.Advance(Spoken) then
          Exit;
        M := FMatcher.CurrentCharOffset(Length(ResponsePlainText));
        NowTick := Int64(GetTickCount64);
        UiInvoke(procedure
        begin
          if FShuttingDown then
            Exit;
          if (FPrevConfirmTicks > 0) and (M > Trunc(FPrevConfirmChar)) then
          begin
            Secs := (NowTick - FPrevConfirmTicks) / 1000.0;
            if Secs > 0.2 then
            begin
              Sp := EnsureRange((M - FPrevConfirmChar) / Secs, 3, 45);
              FEstSpeed := FEstSpeed * 0.5 + Sp * 0.5;
            end;
          end;
          FPrevConfirmChar := M;
          FPrevConfirmTicks := NowTick;
          FConfirmedChar := Max(FConfirmedChar, M);
          if M > FReadPos then
            FReadPos := M;
        end);
      except
        // read-along is best-effort; ignore transcribe errors here
      end;
    finally
      FReadBusy := False;
    end;
  end);
end;

procedure TMainForm.tmrAnimTimer(Sender: TObject);
var
  Dt, Elapsed: Double;
  TextLen, ColTo, Idx, TargetScroll: Integer;
  CurScroll, AnchorY, CharY, TargetY, Diff, StepVal, NextScroll: Double;
  MicActive, WillColor, RecentVoice: Boolean;
  H: HWND;
begin
  if not ResponseHasText then Exit;
  TextLen := Length(ResponsePlainText);
  if TextLen <= 0 then Exit;

  Dt := (Int64(GetTickCount64) - FLastAnimTicks) / 1000.0;
  FLastAnimTicks := Int64(GetTickCount64);
  if (Dt <= 0) or (Dt > 0.5) then
    Dt := 0.025;

  MicActive := FReadMic.IsCapturing;
  Elapsed := (Int64(GetTickCount64) - FReadStartTicks) / 1000.0;
  RecentVoice := (Int64(GetTickCount64) - FPrevConfirmTicks) < 4000;

  if (Elapsed >= ReadStartDelaySec) and (RecentVoice or not MicActive) then
    FReadPos := FReadPos + FEstSpeed * Dt;

  if MicActive then
    FReadPos := Min(FReadPos, FConfirmedChar + ReadLookaheadChars);
  FReadPos := EnsureRange(FReadPos, 0, TextLen);

  Idx := Min(Trunc(FReadPos), Max(0, TextLen - 1));
  CurScroll := GetRtbScrollY;
  CharY := RtbPosFromCharIndex(Idx).Y;
  AnchorY := rtbResponse.ClientHeight * ReadAnchorRatio;
  TargetY := Max(0, CurScroll + CharY - AnchorY);
  Diff := TargetY - CurScroll;
  if Abs(Diff) < 1.5 then
    NextScroll := TargetY
  else
  begin
    StepVal := Diff * ReadLerp;
    if Abs(StepVal) < 1 then
      StepVal := Sign(StepVal);
    NextScroll := CurScroll + StepVal;
  end;

  ColTo := Min(Trunc(FReadPos), TextLen);
  WillColor := ColTo > FColoredChars;
  TargetScroll := Round(NextScroll);

  if not WillColor and (Abs(TargetScroll - CurScroll) < 1) then
    Exit;

  H := rtbResponse.Handle;
  SendMessage(H, WM_SETREDRAW, 0, 0);
  try
    if WillColor then
    begin
      RichEditSetRangeColor(rtbResponse, FColoredChars, ColTo - FColoredChars, FReadDoneColor);
      FColoredChars := ColTo;
    end;
    SetRtbScrollY(TargetScroll);
  finally
    SendMessage(H, WM_SETREDRAW, 1, 0);
    rtbResponse.Invalidate;
  end;
  RichEditHideCaret(rtbResponse);

  if (Trunc(FReadPos) >= TextLen - 1) and (Abs(Diff) < 2) then
    StopReadAlong;
end;

procedure TMainForm.btnPinClick(Sender: TObject);
begin
  miTopmostClick(Sender);
end;

procedure TMainForm.btnMenuClick(Sender: TObject);
var
  P: TPoint;
begin
  RefreshIntelligenceMenu;
  RefreshTranscriptionMenu;
  P := Point(0, btnMenu.Height);
  P := btnMenu.ClientToScreen(P);
  mnuMain.Popup(P.X, P.Y);
end;

function TMainForm.ProfileRoleSet: Boolean;
begin
  Result := Trim(FProfile.Role) <> '';
end;

procedure TMainForm.UpdateInterviewBanner;
begin
  // The interview title (lblInterviewTitle) sits just above the status bar; it is defined at
  // design time in pnlStatus.
  if ProfileRoleSet then
    lblInterviewTitle.Caption := Trim(FProfile.Role)
  else
    lblInterviewTitle.Caption := 'No interview profile set';
  if not ProfileRoleSet then
    SetStatus(#$26A0' Set your interview profile before starting.');
end;

function TMainForm.RequireProfileToStart: Boolean;
begin
  Result := ProfileRoleSet;
  if not Result then
    SetStatus(#$26A0' Set your interview profile before starting.');
end;

procedure TMainForm.btnSetupClick(Sender: TObject);
begin
  if TFrmInterviewSetup.ShowSetupDialog(Self) then
  begin
    FProfile := ProfileLoad;
    FEngine.SetProfile(FProfile.Role, FProfile.TechStack, FProfile.JobDescription, FProfile.Experience);
    UpdateInterviewBanner;
    RefreshContextIndicator;
  end;
end;

procedure TMainForm.btnAutoClick(Sender: TObject);
begin
  ToggleAutoMode;
end;

procedure TMainForm.btnNewClick(Sender: TObject);
begin
  if FModelBusy then Exit;
  FEngine.ResetConversation;
  FLastAutoQuestionKey := '';
  txtTranscript.Clear;
  rtbResponse.Clear;
  UpdateContextIndicator;
  SetStatus('New conversation: context reset');
end;

procedure TMainForm.btnOpUpClick(Sender: TObject);
begin
  AdjustOpacityByStep(False);
end;

procedure TMainForm.btnOpDnClick(Sender: TObject);
begin
  AdjustOpacityByStep(True);
end;

procedure TMainForm.miSetupClick(Sender: TObject);
begin
  btnSetupClick(Sender);
end;

procedure TMainForm.miLangClick(Sender: TObject);
var
  PrevCode: string;
begin
  if not (Sender is TMenuItem) then Exit;
  PrevCode := FLangCode;
  miLangEn.Checked := Sender = miLangEn;
  miLangEs.Checked := Sender = miLangEs;
  miLangFr.Checked := Sender = miLangFr;
  miLangDe.Checked := Sender = miLangDe;
  miLangIt.Checked := Sender = miLangIt;
  miLangRu.Checked := Sender = miLangRu;
  if Sender = miLangEn then FLangCode := 'en'
  else if Sender = miLangEs then FLangCode := 'es'
  else if Sender = miLangFr then FLangCode := 'fr'
  else if Sender = miLangDe then FLangCode := 'de'
  else if Sender = miLangIt then FLangCode := 'it'
  else if Sender = miLangRu then FLangCode := 'ru';
  FLangName := LangNameForCode(FLangCode);
  RegistrySetString('Language', FLangCode);
  if FReady then
  begin
    FEngine.SetLanguage(FLangCode, FLangName);
    if FLangCode <> PrevCode then
    begin
      FEngine.ResetConversation;
      FLastAutoQuestionKey := '';
      txtTranscript.Clear;
      rtbResponse.Clear;
      UpdateContextIndicator;
      SetStatus('Interview language: ' + FLangName);
    end;
  end;
end;

procedure TMainForm.miLengthClick(Sender: TObject);
begin
  miLenShort.Checked := Sender = miLenShort;
  miLenMedium.Checked := Sender = miLenMedium;
  miLenLong.Checked := Sender = miLenLong;
  if Sender = miLenShort then FAnswerLength := alShort
  else if Sender = miLenLong then FAnswerLength := alLong
  else FAnswerLength := alMedium;
  SetAnswerLength(FAnswerLength);
  FEngine.SetAnswerLength(FAnswerLength);
end;

procedure TMainForm.miIntelClick(Sender: TObject);
var
  Level, Prev: TResponseIntelligence;
begin
  if Sender = miIntelFast then Level := riFast
  else if Sender = miIntelMax then Level := riMax
  else Level := riBalanced;
  if Level = FIntelligence then Exit;
  Prev := FIntelligence;
  if FAutoMode then SetAutoMode(False);
  FIntelligence := Level;
  SetResponseIntelligence(Level);
  miIntelFast.Checked := Level = riFast;
  miIntelBalanced.Checked := Level = riBalanced;
  miIntelMax.Checked := Level = riMax;
  FReady := False;
  FModelLock.Enter;
  try
    FModelBusy := True;
  finally
    FModelLock.Leave;
  end;
  SetActionsEnabled(False);
  SetStatus('Initializing the AI model...');
  RunAsync(procedure
  var
    Ok: Boolean;
    ErrMsg: string;
  begin
    Ok := False;
    ErrMsg := '';
    try
      if not FEngine.EnsureModel(Level, OnEngineProgress) then
        ErrMsg := FEngine.LastError;
      if ErrMsg.IsEmpty and not FEngine.LoadLlm(Level) then
        ErrMsg := FEngine.LastError;
      if ErrMsg.IsEmpty and not FEngine.WarmupLlm then
        ErrMsg := FEngine.LastError;
      if ErrMsg.IsEmpty then
      begin
        FEngine.ResetConversation;
        Ok := True;
        ShowGpuLoadStatus;
        UiInvoke(procedure
        begin
          UpdateContextIndicator;
        end);
      end;
    except
      on E: Exception do
        ErrMsg := E.Message;
    end;
    if not Ok then
    begin
      FIntelligence := Prev;
      SetResponseIntelligence(Prev);
      UiInvoke(procedure
      begin
        miIntelFast.Checked := Prev = riFast;
        miIntelBalanced.Checked := Prev = riBalanced;
        miIntelMax.Checked := Prev = riMax;
      end);
      SetStatus('Could not switch model: ' + ErrMsg);
      try
        FEngine.LoadLlm(Prev);
        FEngine.WarmupLlm;
      except
        on E: Exception do
          DebugLogWrite('[MainForm] revert model: ' + E.Message);
      end;
    end;
    FReady := True;
    FModelLock.Enter;
    try
      FModelBusy := False;
    finally
      FModelLock.Leave;
    end;
    SetActionsEnabled(True);
    UiInvoke(procedure
    begin
      RefreshIntelligenceMenu;
    end);
  end);
end;

procedure TMainForm.miTransClick(Sender: TObject);
var
  Level, Prev: TTranscriptionIntelligence;
begin
  if Sender = miTransFast then Level := tiFast
  else if Sender = miTransMax then Level := tiMax
  else Level := tiBalanced;
  if Level = FTranscription then Exit;
  Prev := FTranscription;
  if FAutoMode then SetAutoMode(False);
  FTranscription := Level;
  SetTranscriptionIntelligence(Level);
  miTransFast.Checked := Level = tiFast;
  miTransBalanced.Checked := Level = tiBalanced;
  miTransMax.Checked := Level = tiMax;
  FReady := False;
  FModelLock.Enter;
  try
    FModelBusy := True;
  finally
    FModelLock.Leave;
  end;
  SetActionsEnabled(False);
  SetStatus('Initializing transcription engine...');
  RunAsync(procedure
  var
    Ok: Boolean;
    ErrMsg: string;
  begin
    Ok := False;
    ErrMsg := '';
    try
      if not FEngine.EnsureWhisper(Level, OnEngineProgress) then
        ErrMsg := FEngine.LastError;
      if ErrMsg.IsEmpty then
        SetStatus(Format('Loading voice model (%s)...',
          [TranscriptionDisplayLabel(Level)]));
      if ErrMsg.IsEmpty and not FEngine.LoadWhisper(Level) then
        ErrMsg := FEngine.LastError;
      if ErrMsg.IsEmpty then
        SetStatus(Format('Initializing voice model (%s)...',
          [TranscriptionDisplayLabel(Level)]));
      if ErrMsg.IsEmpty and not FEngine.WarmupWhisper then
        ErrMsg := FEngine.LastError;
      if ErrMsg.IsEmpty then
      begin
        Ok := True;
        ShowGpuLoadStatus;
      end;
    except
      on E: Exception do
        ErrMsg := E.Message;
    end;
    if not Ok then
    begin
      FTranscription := Prev;
      SetTranscriptionIntelligence(Prev);
      UiInvoke(procedure
      begin
        miTransFast.Checked := Prev = tiFast;
        miTransBalanced.Checked := Prev = tiBalanced;
        miTransMax.Checked := Prev = tiMax;
      end);
      SetStatus('Could not switch transcription model: ' + ErrMsg);
      try
        FEngine.LoadWhisper(Prev);
        FEngine.WarmupWhisper;
      except
        on E: Exception do
          DebugLogWrite('[MainForm] revert whisper: ' + E.Message);
      end;
    end;
    FReady := True;
    FModelLock.Enter;
    try
      FModelBusy := False;
    finally
      FModelLock.Leave;
    end;
    SetActionsEnabled(True);
    UiInvoke(procedure
    begin
      RefreshTranscriptionMenu;
    end);
  end);
end;

procedure TMainForm.miListenKeyClick(Sender: TObject);
begin
  if Sender = miKeyShift then SetListeningKeyChoice(lkShift)
  else if Sender = miKeyAlt then SetListeningKeyChoice(lkAlt)
  else SetListeningKeyChoice(lkCtrl);
  miKeyCtrl.Checked := FListeningKey = lkCtrl;
  miKeyShift.Checked := FListeningKey = lkShift;
  miKeyAlt.Checked := FListeningKey = lkAlt;
end;

procedure TMainForm.StartSettingsMonitor;
begin
  if FAudio.IsCapturing then
    Exit;
  try
    FAudio.Start(False);
    FSettingsMonitoring := True;
  except
    on E: Exception do
      SetStatus('Audio: ' + E.Message);
  end;
end;

procedure TMainForm.StopSettingsMonitor;
begin
  if FSettingsMonitoring and not FAutoMode and not FListening then
  begin
    try
      FAudio.StopCapture;
    except
    end;
  end;
  FSettingsMonitoring := False;
end;

procedure TMainForm.miAutoCfgClick(Sender: TObject);
begin
  if FrmSettings.Visible then
  begin
    FrmSettings.BringToFront;
    Exit;
  end;
  FrmSettings.Configure(FSegmenter, FAudio,
    function: Boolean begin Result := FAutoMode; end,
    procedure(On: Boolean) begin SetAutoMode(On); end,
    StartSettingsMonitor,
    StopSettingsMonitor,
    nil);
  PrepareDialogAboveMain(FrmSettings);
  FrmSettings.Show;
end;

procedure TMainForm.miMicCfgClick(Sender: TObject);
begin
  if FrmMicSettings.Visible then
  begin
    FrmMicSettings.BringToFront;
    Exit;
  end;
  FrmMicSettings.Configure(
    function: Single begin Result := FMicRmsLast; end,
    function: Single begin Result := FMicThreshold; end,
    procedure(T: Single)
    begin
      FMicThreshold := T;
      FAudio.MicSpeechThreshold := T;
      RegistrySetInt('MicThreshold', Round(T * 1000));
    end,
    function: Boolean begin Result := FUseMic; end,
    procedure(Value: Boolean) begin SetUseMicEnabled(Value); end,
    StartMicMonitor);
  PrepareDialogAboveMain(FrmMicSettings);
  FrmMicSettings.Show;
end;

procedure TMainForm.miUseMicClick(Sender: TObject);
begin
  SetUseMicEnabled(not FUseMic);
end;

procedure TMainForm.miMicClick(Sender: TObject);
begin
  if Sender = miMicDefault then
    MicDevicesSetSelectedId('')
  else if Sender is TMenuItem then
    MicDevicesSetSelectedId(TMenuItem(Sender).Hint);
  StartMicMonitor;
  RebuildMicMenu;
end;

procedure TMainForm.RebuildMicMenu;
var
  MicSlots: array[0..14] of TMenuItem;
  Devices: TArray<TMicDevice>;
  D: TMicDevice;
  I, Count: Integer;
  SelId: string;
begin
  MicSlots[0] := miMic01;
  MicSlots[1] := miMic02;
  MicSlots[2] := miMic03;
  MicSlots[3] := miMic04;
  MicSlots[4] := miMic05;
  MicSlots[5] := miMic06;
  MicSlots[6] := miMic07;
  MicSlots[7] := miMic08;
  MicSlots[8] := miMic09;
  MicSlots[9] := miMic10;
  MicSlots[10] := miMic11;
  MicSlots[11] := miMic12;
  MicSlots[12] := miMic13;
  MicSlots[13] := miMic14;
  MicSlots[14] := miMic15;
  SelId := MicDevicesGetSelectedId;
  miMicDefault.Checked := SelId.IsEmpty;
  Devices := MicDevicesList;
  Count := 0;
  for D in Devices do
  begin
    if D.IsDefault then Continue;
    if Count > High(MicSlots) then Break;
    MicSlots[Count].Caption := D.Name;
    MicSlots[Count].Hint := D.Id;
    MicSlots[Count].Checked := D.Id = SelId;
    MicSlots[Count].Visible := True;
    Inc(Count);
  end;
  for I := Count to High(MicSlots) do
  begin
    MicSlots[I].Caption := '';
    MicSlots[I].Hint := '';
    MicSlots[I].Checked := False;
    MicSlots[I].Visible := False;
  end;
end;

procedure TMainForm.miScrollClick(Sender: TObject);
begin
  miScrollOff.Checked := Sender = miScrollOff;
  miScrollAuto.Checked := Sender = miScrollAuto;
  miScrollVoice.Checked := Sender = miScrollVoice;
  if Sender = miScrollOff then FScrollMode := smOff
  else if Sender = miScrollVoice then FScrollMode := smVoice
  else FScrollMode := smAuto;
  miSpeed.Enabled := FScrollMode = smAuto;
  if FScrollMode = smOff then StopReadAlong
  else if ResponseHasText then StartReadAlong;
end;

procedure TMainForm.miSpeedClick(Sender: TObject);
begin
  miSpeedVSlow.Checked := Sender = miSpeedVSlow;
  miSpeedSlow.Checked := Sender = miSpeedSlow;
  miSpeedMed.Checked := Sender = miSpeedMed;
  miSpeedFast.Checked := Sender = miSpeedFast;
  miSpeedVFast.Checked := Sender = miSpeedVFast;
  if Sender = miSpeedVSlow then FAutoSpeed := 14
  else if Sender = miSpeedSlow then FAutoSpeed := 20
  else if Sender = miSpeedFast then FAutoSpeed := 36
  else if Sender = miSpeedVFast then FAutoSpeed := 50
  else FAutoSpeed := 26;
  FEstSpeed := FAutoSpeed;
end;

procedure TMainForm.miTopmostClick(Sender: TObject);
begin
  if FormStyle = fsStayOnTop then
    FormStyle := fsNormal
  else
    FormStyle := fsStayOnTop;
  UpdatePinVisual;
end;

procedure TMainForm.miHideCaptureClick(Sender: TObject);
begin
  FHiddenFromCapture := not FHiddenFromCapture;
  ApplyCaptureHiding;
  UpdateTaskbarVisibility;
end;

procedure TMainForm.miMinimizeClick(Sender: TObject);
begin
  WindowState := wsMinimized;
end;

procedure TMainForm.miTextSizeClick(Sender: TObject);
var
  Sz, SelStart, SelLen: Integer;
  NewFont: TFont;
begin
  if Sender = miSize9 then Sz := 9
  else if Sender = miSize12 then Sz := 12
  else if Sender = miSize14 then Sz := 14
  else if Sender = miSize16 then Sz := 16
  else if Sender = miSize20 then Sz := 20
  else Sz := 10;
  SelStart := rtbResponse.SelStart;
  SelLen := rtbResponse.SelLength;
  NewFont := TFont.Create;
  try
    NewFont.Assign(rtbResponse.Font);
    NewFont.Size := Sz;
    rtbResponse.Font := NewFont;
    rtbResponse.SelectAll;
    rtbResponse.SelAttributes.Size := Sz;
    rtbResponse.SelStart := SelStart;
    rtbResponse.SelLength := SelLen;
  finally
    NewFont.Free;
  end;
end;

procedure TMainForm.miTextColorClick(Sender: TObject);
begin
  miColWhite.Checked := Sender = miColWhite;
  miColBlue.Checked := Sender = miColBlue;
  miColGreen.Checked := Sender = miColGreen;
  miColYellow.Checked := Sender = miColYellow;
  miColMagenta.Checked := Sender = miColMagenta;
  if Sender = miColBlue then FRespColor := RGB(120, 200, 255)
  else if Sender = miColGreen then FRespColor := RGB(120, 230, 150)
  else if Sender = miColYellow then FRespColor := RGB(240, 210, 90)
  else if Sender = miColMagenta then FRespColor := RGB(220, 120, 200)
  else FRespColor := clWindowText;
  rtbResponse.Font.Color := FRespColor;
  if FColoredChars > 0 then
    RichEditSetRangeColor(rtbResponse, 0, FColoredChars, FReadDoneColor);
  if FColoredChars < Length(ResponsePlainText) then
    RichEditSetRangeColor(rtbResponse, FColoredChars,
      Length(ResponsePlainText) - FColoredChars, FRespColor);
  RichEditHideCaret(rtbResponse);
end;

procedure TMainForm.miAboutClick(Sender: TObject);
begin
  TFrmAbout.ShowAbout(Self);
end;

procedure TMainForm.miExitClick(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.miRemoveTransClick(Sender: TObject);
var
  Level: TTranscriptionIntelligence;
  Info: TWhisperModelInfo;
begin
  if FModelBusy then Exit;
  if Sender = miRemoveTransFast then Level := tiFast
  else if Sender = miRemoveTransMax then Level := tiMax
  else Level := tiBalanced;
  if Level = FTranscription then
  begin
    SetStatus('Cannot remove the transcription model currently in use.');
    Exit;
  end;
  if not WhisperCatalogIsInstalled(Level) then
  begin
    Info := WhisperCatalogGet(Level);
    SetStatus('Model not installed: ' + Info.LabelText);
    Exit;
  end;
  Info := WhisperCatalogGet(Level);
  if MessageDlg(Format('Remove the "%s" transcription model?' + sLineBreak + sLineBreak +
    'You can download it again later by selecting that level.',
    [Info.LabelText]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  try
    WhisperCatalogDelete(Level);
    SetStatus('Removed: ' + Info.LabelText);
    RefreshTranscriptionMenu;
  except
    on E: Exception do
      SetStatus('Could not remove model: ' + E.Message);
  end;
end;

procedure TMainForm.miRemoveModelClick(Sender: TObject);
var
  Level: TResponseIntelligence;
  Info: TLocalModelInfo;
  Path: string;
begin
  if FModelBusy then Exit;
  if Sender = miRemoveFast then Level := riFast
  else if Sender = miRemoveMax then Level := riMax
  else Level := riBalanced;
  if Level = FIntelligence then
  begin
    SetStatus('Cannot remove the model currently in use.');
    Exit;
  end;
  Info := ModelCatalogGet(Level);
  Path := ModelCatalogPathFor(Level);
  if not TFile.Exists(Path) then
  begin
    SetStatus('Model not installed: ' + Info.LabelText);
    Exit;
  end;
  if MessageDlg(Format('Remove the "%s" response model?' + sLineBreak + sLineBreak +
    'You can download it again later by selecting that level.',
    [Info.LabelText]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  try
    TFile.Delete(Path);
    SetStatus('Removed: ' + Info.LabelText);
    RefreshIntelligenceMenu;
  except
    on E: Exception do
      SetStatus('Could not remove model: ' + E.Message);
  end;
end;

procedure TMainForm.trayIconDblClick(Sender: TObject);
begin
  Show;
  if WindowState = wsMinimized then WindowState := wsNormal;
  Application.Restore;
  BringToFront;
end;

procedure TMainForm.miForceCudaClick(Sender: TObject);
var
  Enable: Boolean;
begin
  if FModelBusy or not FReady then
  begin
    SetStatus('Wait for the current operation to finish, then try again.');
    Exit;
  end;
  Enable := not miForceCuda.Checked;
  if Enable and
     (MessageDlg('Force the CUDA backend on RTX 50xx (Blackwell) GPUs?' + sLineBreak + sLineBreak +
       'Faster than Vulkan when it works, but early CUDA builds crashed on these cards. ' +
       'If the engine fails to restart, the option is turned off again automatically.' + sLineBreak +
       sLineBreak + 'The AI engine will restart now (models are reloaded).',
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then
    Exit;

  miForceCuda.Checked := Enable;
  RegistrySetInt('ForceCuda', Ord(Enable));
  // The engine child process inherits this variable (HardwareProbe.ForceCudaOnBlackwell).
  if Enable then
    SetEnvironmentVariable('SMARTINTERVIEW_FORCE_CUDA', '1')
  else
    SetEnvironmentVariable('SMARTINTERVIEW_FORCE_CUDA', nil);

  try
    RestartEngineAfterRelicense;
    if Enable then
      SetStatus('Engine restarted with CUDA forced. Check answer speed now.')
    else
      SetStatus('Engine restarted with the default GPU backend.');
  except
    on E: Exception do
    begin
      // CUDA crashed or the engine would not come back: revert to the safe default
      // and restart once more so the app stays usable.
      miForceCuda.Checked := False;
      RegistrySetInt('ForceCuda', 0);
      SetEnvironmentVariable('SMARTINTERVIEW_FORCE_CUDA', nil);
      SetStatus('CUDA backend failed: ' + E.Message);
      if Enable then
      begin
        try
          RestartEngineAfterRelicense;
          SetStatus('CUDA failed - reverted to the default backend.');
        except
          on E2: Exception do
            SetStatus('Engine restart failed: ' + E2.Message + ' Restart the app.');
        end;
      end;
    end;
  end;
end;

procedure TMainForm.RestartEngineAfterRelicense;
var
  Err: string;
begin
  SetStatus('Restarting engine...');
  FReady := False;
  try
    FEngine.Stop;
    if not FEngine.Start then
      raise Exception.Create(FEngine.LastError);
    if not FEngine.Ping then
      raise Exception.Create('Engine not responding after license activation.');
    if not FEngine.Startup(FLangCode, FLangName, FIntelligence, FTranscription,
      FProfile.Role, FProfile.TechStack, FProfile.JobDescription, FProfile.Experience,
      FAnswerLength, OnEngineProgress, Err) then
    begin
      if not FEngine.StartupLegacy(FLangCode, FLangName, FIntelligence, FTranscription,
        FProfile.Role, FProfile.TechStack, FProfile.JobDescription, FProfile.Experience,
        FAnswerLength, OnEngineProgress, Err) then
        raise Exception.Create(Err);
    end;
    SetStatus('');
  finally
    FReady := True;
  end;
end;

procedure TMainForm.HandleLicensePeriodicResult(const Res: TLicensePeriodicResult; const Msg: string);
begin
  case Res of
    lprOk, lprOfflineOk:
      begin
        // Recovered from the offline-blocked state (internet is back and the license is
        // still valid): restart the engine and resume normal cadence.
        if FLicenseOfflineBlocked then
        begin
          FLicenseOfflineBlocked := False;
          FLicenseTimer.Interval := 30 * 60 * 1000;
          SetStatus('License verified - restarting engine...');
          try
            RestartEngineAfterRelicense;
            SetStatus('');
          except
            on E: Exception do
              SetStatus('Engine restart failed: ' + E.Message);
          end;
        end;
      end;
    lprExpired, lprInvalid, lprNoLicense:
      begin
        FLicenseOfflineBlocked := False;
        FLicenseTimer.Interval := 30 * 60 * 1000;
        FEngine.Stop;
        FReady := False;
        FrmLicense.PrepareShow;
        if not TFrmLicense.PromptRelicense(Self) then
        begin
          LicenseStoreClear;
          if Msg <> '' then
            MessageDlg(Msg, mtWarning, [mbOK], 0);
          Application.Terminate;
        end
        else
        begin
          LicenseMonitorPrimeFromStore(LicenseStoreGetForumUsername, LicenseStoreGet);
          try
            RestartEngineAfterRelicense;
          except
            on E: Exception do
            begin
              SetStatus('Engine restart failed: ' + E.Message);
              MessageDlg('License saved but the engine could not restart:' + sLineBreak +
                sLineBreak + E.Message, mtError, [mbOK], 0);
              Application.Terminate;
            end;
          end;
        end;
      end;
    lprOfflineBlocked:
      begin
        // Offline grace exceeded (or no trusted time anchor): the AI engine must actually
        // stop, not just show a message — otherwise the documented 72h offline cap is not
        // enforced. While blocked the timer polls every minute and forces a real check, so
        // the engine restarts within ~1 minute of the connection returning.
        if not FLicenseOfflineBlocked then
        begin
          FLicenseOfflineBlocked := True;
          FEngine.CancelGeneration;
          FEngine.Stop;
          FReady := False;
          FLicenseTimer.Interval := 60 * 1000;
        end;
        if Msg <> '' then
          SetStatus(Msg)
        else
          SetStatus('Connect to the internet to verify your license.');
      end;
  end;
end;

procedure TMainForm.tmrLicenseTimer(Sender: TObject);
var
  Msg: string;
  Res: TLicensePeriodicResult;
begin
  if FShuttingDown or FLicenseCheckBusy then
    Exit;
  if not (FReady or FLicenseOfflineBlocked) then
    Exit;
  FLicenseCheckBusy := True;
  try
    if FLicenseOfflineBlocked then
      LicenseMonitorForceNextCheck;
    Res := LicensePeriodicRevalidate(Msg);
    HandleLicensePeriodicResult(Res, Msg);
  finally
    FLicenseCheckBusy := False;
  end;
end;

procedure TMainForm.tmrEngineTimer(Sender: TObject);
begin
  if not FReady or FModelBusy or FEnginePingBusy then Exit;
  FEnginePingBusy := True;
  RunAsync(procedure
  begin
    try
      if FEngine.Ping then
        FEnginePingFails := 0
      else
      begin
        Inc(FEnginePingFails);
        if FEnginePingFails >= 3 then
          SetStatus('Engine not responding - restart the app if problems persist.');
      end;
    finally
      FEnginePingBusy := False;
    end;
  end);
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  FShuttingDown := True;
  Hide;
  trayIcon.Visible := False;
  tmrLive.Enabled := False;
  tmrRead.Enabled := False;
  tmrAnim.Enabled := False;
  tmrIcon.Enabled := False;
  tmrEngine.Enabled := False;
  if FLicenseTimer <> nil then
    FLicenseTimer.Enabled := False;
  FEngine.CancelGeneration;
  Action := caFree;
end;

end.
