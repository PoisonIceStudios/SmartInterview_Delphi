unit uAudioCapture;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.SyncObjs,
  uWasapiCapture,
  uWasapi16k;

type
  TAudioCapture = class
  private
    FLoop: TWasapiLoopbackCapture;
    FMic: TWasapi16kSource;
    FMicOn: Boolean;
    FLock: TCriticalSection;
    FBufLoop, FBufMic: TList<Single>;
    FOnSystemSamples: TWasapiSampleEvent;
    procedure OnLoopSamples(const Samples: TArray<Single>);
    procedure OnMicSamples(const Samples: TArray<Single>);
    function GetIsCapturing: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start(IncludeMic: Boolean);
    function Snapshot: TArray<Single>;
    function SnapshotTail(MaxSamples: Integer): TArray<Single>;
    function StopCapture: TArray<Single>;
    property IsCapturing: Boolean read GetIsCapturing;
    property OnSystemSamples: TWasapiSampleEvent read FOnSystemSamples write FOnSystemSamples;
  end;

implementation

uses
  System.Math;

const
  MaxCaptureSamples = 16000 * 60 * 10;

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

function TAudioCapture.Snapshot: TArray<Single>;
var
  N, I: Integer;
  A, B: Single;
  Both: Boolean;
begin
  FLock.Enter;
  try
    N := Max(FBufLoop.Count, FBufMic.Count);
    SetLength(Result, N);
    for I := 0 to N - 1 do
    begin
      if I < FBufLoop.Count then
        A := FBufLoop[I]
      else
        A := 0;
      if I < FBufMic.Count then
        B := FBufMic[I]
      else
        B := 0;
      Both := (I < FBufLoop.Count) and (I < FBufMic.Count) and (Abs(A) > 1E-6) and (Abs(B) > 1E-6);
      if Both then
        Result[I] := EnsureRange((A + B) * 0.7, -1.0, 1.0)
      else
        Result[I] := EnsureRange(A + B, -1.0, 1.0);
    end;
  finally
    FLock.Leave;
  end;
end;

function TAudioCapture.SnapshotTail(MaxSamples: Integer): TArray<Single>;
var
  N, Count, Start, I, Idx: Integer;
  A, B: Single;
  Both: Boolean;
begin
  if MaxSamples <= 0 then
    MaxSamples := MaxCaptureSamples;
  FLock.Enter;
  try
    N := Max(FBufLoop.Count, FBufMic.Count);
    Count := Min(N, MaxSamples);
    if Count <= 0 then
      Exit(nil);
    Start := N - Count;
    SetLength(Result, Count);
    for I := 0 to Count - 1 do
    begin
      Idx := Start + I;
      if Idx < FBufLoop.Count then
        A := FBufLoop[Idx]
      else
        A := 0;
      if Idx < FBufMic.Count then
        B := FBufMic[Idx]
      else
        B := 0;
      Both := (Idx < FBufLoop.Count) and (Idx < FBufMic.Count) and
        (Abs(A) > 1E-6) and (Abs(B) > 1E-6);
      if Both then
        Result[I] := EnsureRange((A + B) * 0.7, -1.0, 1.0)
      else
        Result[I] := EnsureRange(A + B, -1.0, 1.0);
    end;
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
