unit uAudioCapture;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.SyncObjs,
  uWasapiCapture,
  uWasapi16k;

// True if the buffer contains at least a short run of speech-level energy (not just silence
// or faint noise). Used to gate Whisper, which otherwise hallucinates phrases on silence.
// When Threshold < 0 the built-in SpeechRmsThreshold is used.
function AudioHasSpeech(const Samples: TArray<Single>; Threshold: Single = -1): Boolean;

// Trims leading/trailing silence so Whisper never sees a silent prefix/suffix (a common
// trigger for boundary hallucinations like "Grazie"). Returns nil when there is no speech.
function AudioTrimSilence(const Samples: TArray<Single>; Threshold: Single = -1): TArray<Single>;

type
  TAudioCapture = class
  private
    FLoop: TWasapiLoopbackCapture;
    FMic: TWasapi16kSource;
    FMicOn: Boolean;
    FLock: TCriticalSection;
    FBufLoop, FBufMic: TList<Single>;
    FMicSpeechThreshold: Single;
    FOnSystemSamples: TWasapiSampleEvent;
    procedure OnLoopSamples(const Samples: TArray<Single>);
    procedure OnMicSamples(const Samples: TArray<Single>);
    function GetIsCapturing: Boolean;
    function BuildRange(StartIdx, Count: Integer): TArray<Single>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start(IncludeMic: Boolean);
    function Snapshot: TArray<Single>;
    function SnapshotTail(MaxSamples: Integer): TArray<Single>;
    function StopCapture: TArray<Single>;
    property IsCapturing: Boolean read GetIsCapturing;
    property OnSystemSamples: TWasapiSampleEvent read FOnSystemSamples write FOnSystemSamples;
    property MicSpeechThreshold: Single read FMicSpeechThreshold write FMicSpeechThreshold;
  end;

implementation

uses
  System.Math;

const
  MaxCaptureSamples = 16000 * 60 * 10;
  SpeechFrameSamples = 320;         // 20 ms @ 16 kHz
  // The mic slider is the user's control: only audio ABOVE the threshold is treated as speech,
  // captured and then normalized by the engine (AGC) — speaking below it is intentionally
  // ignored. These are just sensible defaults; the user sets the line on the live meter.
  SpeechRmsThreshold = 0.025;       // loopback / auto mode gate
  DefaultMicSpeechThreshold = 0.030; // default mic slider position (user-adjustable)
  SpeechMinVoicedFrames = 4;        // ~80 ms of voice to count as speech
  SpeechEdgePadSamples = 1280;      // keep 80 ms around the speech so words aren't clipped

function FrameRms(const Samples: TArray<Single>; StartIdx, Count: Integer): Single;
var
  I, Idx, N: Integer;
  Sum: Double;
begin
  Sum := 0;
  N := 0;
  for I := 0 to Count - 1 do
  begin
    Idx := StartIdx + I;
    if Idx > High(Samples) then
      Break;
    Sum := Sum + Samples[Idx] * Samples[Idx];
    Inc(N);
  end;
  if N = 0 then
    Exit(0);
  Result := Sqrt(Sum / N);
end;

function EffectiveSpeechThreshold(Threshold: Single): Single;
begin
  if Threshold < 0 then
    Result := SpeechRmsThreshold
  else
    Result := Threshold;
end;

function AudioHasSpeech(const Samples: TArray<Single>; Threshold: Single): Boolean;
var
  Pos, Run: Integer;
  Gate: Single;
begin
  Gate := EffectiveSpeechThreshold(Threshold);
  // Require a *consecutive* run of voiced frames. Real speech is continuous; background
  // noise produces only short, scattered spikes that never sustain this long.
  Run := 0;
  Pos := 0;
  while Pos < Length(Samples) do
  begin
    if FrameRms(Samples, Pos, SpeechFrameSamples) >= Gate then
    begin
      Inc(Run);
      if Run >= SpeechMinVoicedFrames then
        Exit(True);
    end
    else
      Run := 0;
    Inc(Pos, SpeechFrameSamples);
  end;
  Result := False;
end;

function AudioTrimSilence(const Samples: TArray<Single>; Threshold: Single): TArray<Single>;
var
  Pos, FirstVoiced, LastVoiced, StartIdx, EndIdx, Count: Integer;
  Gate: Single;
begin
  Gate := EffectiveSpeechThreshold(Threshold);
  FirstVoiced := -1;
  LastVoiced := -1;
  Pos := 0;
  while Pos < Length(Samples) do
  begin
    if FrameRms(Samples, Pos, SpeechFrameSamples) >= Gate then
    begin
      if FirstVoiced < 0 then
        FirstVoiced := Pos;
      LastVoiced := Pos + SpeechFrameSamples;
    end;
    Inc(Pos, SpeechFrameSamples);
  end;
  if FirstVoiced < 0 then
    Exit(nil);
  StartIdx := Max(0, FirstVoiced - SpeechEdgePadSamples);
  EndIdx := Min(Length(Samples), LastVoiced + SpeechEdgePadSamples);
  Count := EndIdx - StartIdx;
  if Count <= 0 then
    Exit(nil);
  Result := Copy(Samples, StartIdx, Count);
end;

procedure TrimCaptureBuffer(Buf: TList<Single>);
var
  Over: Integer;
begin
  Over := Buf.Count - MaxCaptureSamples;
  if Over > 0 then
    Buf.DeleteRange(0, Over);
end;

constructor TAudioCapture.Create;
begin
  inherited;
  FLoop := TWasapiLoopbackCapture.Create;
  FMic := TWasapi16kSource.Create;
  FLock := TCriticalSection.Create;
  FBufLoop := TList<Single>.Create;
  FBufMic := TList<Single>.Create;
  FMicSpeechThreshold := DefaultMicSpeechThreshold;
  FLoop.OnSamples := OnLoopSamples;
  FMic.OnSamples16k := OnMicSamples;
end;

function TAudioCapture.GetIsCapturing: Boolean;
begin
  Result := FLoop.Active;
end;

destructor TAudioCapture.Destroy;
begin
  StopCapture;
  FLoop.Free;
  FMic.Free;
  FBufLoop.Free;
  FBufMic.Free;
  FLock.Free;
  inherited;
end;

procedure TAudioCapture.OnLoopSamples(const Samples: TArray<Single>);
var
  I: Integer;
begin
  FLock.Enter;
  try
    for I := 0 to High(Samples) do
      FBufLoop.Add(Samples[I]);
    TrimCaptureBuffer(FBufLoop);
  finally
    FLock.Leave;
  end;
  if Assigned(FOnSystemSamples) then
    FOnSystemSamples(Samples);
end;

procedure TAudioCapture.OnMicSamples(const Samples: TArray<Single>);
var
  I: Integer;
begin
  FLock.Enter;
  try
    for I := 0 to High(Samples) do
      FBufMic.Add(Samples[I]);
    TrimCaptureBuffer(FBufMic);
  finally
    FLock.Leave;
  end;
end;

procedure TAudioCapture.Start(IncludeMic: Boolean);
begin
  FLock.Enter;
  try
    FBufLoop.Clear;
    FBufMic.Clear;
  finally
    FLock.Leave;
  end;
  if not FLoop.Start then
    raise Exception.Create('Could not start system audio capture (WASAPI loopback).');
  FMicOn := IncludeMic and FMic.Start;
end;

// Builds a transcription buffer for the captured range. Loopback (system audio) and the
// microphone are two independently-clocked WASAPI streams: summing them sample-by-sample
// causes comb-filtering/echo (especially with speakers) and produces doubled words. Instead
// we pick the source that actually carries the speech for this range, by comparing energy.
function TAudioCapture.BuildRange(StartIdx, Count: Integer): TArray<Single>;
var
  I, Idx: Integer;
  LoopE, MicE: Double;
  S: Single;
  Src: TList<Single>;
begin
  if Count <= 0 then
    Exit(nil);

  LoopE := 0;
  MicE := 0;
  for I := 0 to Count - 1 do
  begin
    Idx := StartIdx + I;
    if Idx < FBufLoop.Count then
    begin
      S := FBufLoop[Idx];
      LoopE := LoopE + S * S;
    end;
    if Idx < FBufMic.Count then
    begin
      S := FBufMic[Idx];
      MicE := MicE + S * S;
    end;
  end;

  // Choose the dominant (louder) source for this snapshot. When the mic is off MicE stays 0.
  // When the mic is on but below the user threshold, ignore it — low-level mic noise is a
  // common trigger for Whisper hallucinations ("Grazie a tutti") if sent to the engine.
  if (Count > 0) and (FMicSpeechThreshold > 0) then
  begin
    if Sqrt(MicE / Count) < FMicSpeechThreshold then
      MicE := 0;
  end;
  if MicE > LoopE then
    Src := FBufMic
  else
    Src := FBufLoop;

  SetLength(Result, Count);
  for I := 0 to Count - 1 do
  begin
    Idx := StartIdx + I;
    if Idx < Src.Count then
      Result[I] := EnsureRange(Src[Idx], -1.0, 1.0)
    else
      Result[I] := 0;
  end;
end;

function TAudioCapture.Snapshot: TArray<Single>;
var
  N: Integer;
begin
  FLock.Enter;
  try
    N := Max(FBufLoop.Count, FBufMic.Count);
    Result := BuildRange(0, N);
  finally
    FLock.Leave;
  end;
end;

function TAudioCapture.SnapshotTail(MaxSamples: Integer): TArray<Single>;
var
  N, Count: Integer;
begin
  if MaxSamples <= 0 then
    MaxSamples := MaxCaptureSamples;
  FLock.Enter;
  try
    N := Max(FBufLoop.Count, FBufMic.Count);
    Count := Min(N, MaxSamples);
    Result := BuildRange(N - Count, Count);
  finally
    FLock.Leave;
  end;
end;

function TAudioCapture.StopCapture: TArray<Single>;
begin
  FLoop.Stop;
  if FMicOn then
  begin
    FMic.Stop;
    FMicOn := False;
  end;
  Result := Snapshot;
end;

end.
