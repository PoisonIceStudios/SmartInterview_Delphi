unit uVoiceSegmenter;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.SyncObjs;

type
  TVoiceSegmenter = class
  public
    const
      DefaultThreshold = 0.022;
      DefaultSilenceMs = 1300;
      DefaultMinSpeechMs = 500;
    type
      TFloatArrayEvent = procedure(const Samples: TArray<Single>) of object;
      TSimpleEvent = procedure of object;
  private
    const
      Rate = 16000;
    var
      FSilenceToEnd: Integer;
      FMinSpeech: Integer;
      FProgressEvery: Integer;
      FSeg: TList<Single>;
      FInSpeech: Boolean;
      FSilence: Integer;
      FSpeech: Integer;
      FSinceProgress: Integer;
      FThreshold: Single;
      FLock: TCriticalSection;
      FOnSpeechStarted: TSimpleEvent;
      FOnSpeechProgress: TFloatArrayEvent;
      FOnSegmentReady: TFloatArrayEvent;
      function GetSilenceMs: Integer;
      procedure SetSilenceMs(const Value: Integer);
      function GetMinSpeechMs: Integer;
      procedure SetMinSpeechMs(const Value: Integer);
    public
      constructor Create;
      destructor Destroy; override;
      procedure Reset;
      procedure Push(const Chunk: TArray<Single>);
      property Threshold: Single read FThreshold write FThreshold;
      property SilenceMs: Integer read GetSilenceMs write SetSilenceMs;
      property MinSpeechMs: Integer read GetMinSpeechMs write SetMinSpeechMs;
      property OnSpeechStarted: TSimpleEvent read FOnSpeechStarted write FOnSpeechStarted;
      property OnSpeechProgress: TFloatArrayEvent read FOnSpeechProgress write FOnSpeechProgress;
      property OnSegmentReady: TFloatArrayEvent read FOnSegmentReady write FOnSegmentReady;
  end;

implementation

uses
  System.Math;

constructor TVoiceSegmenter.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FSeg := TList<Single>.Create;
  FThreshold := DefaultThreshold;
  SilenceMs := DefaultSilenceMs;
  MinSpeechMs := DefaultMinSpeechMs;
  FProgressEvery := Rate div 2;
end;

destructor TVoiceSegmenter.Destroy;
begin
  FSeg.Free;
  FLock.Free;
  inherited;
end;

function TVoiceSegmenter.GetSilenceMs: Integer;
begin
  Result := FSilenceToEnd * 1000 div Rate;
end;

procedure TVoiceSegmenter.SetSilenceMs(const Value: Integer);
begin
  FSilenceToEnd := Rate * Max(100, Value) div 1000;
end;

function TVoiceSegmenter.GetMinSpeechMs: Integer;
begin
  Result := FMinSpeech * 1000 div Rate;
end;

procedure TVoiceSegmenter.SetMinSpeechMs(const Value: Integer);
begin
  FMinSpeech := Rate * Max(50, Value) div 1000;
end;

procedure TVoiceSegmenter.Reset;
begin
  FLock.Enter;
  try
    FSeg.Clear;
    FInSpeech := False;
    FSilence := 0;
    FSpeech := 0;
    FSinceProgress := 0;
  finally
    FLock.Leave;
  end;
end;

procedure TVoiceSegmenter.Push(const Chunk: TArray<Single>);
var
  I: Integer;
  Sum: Double;
  Rms: Single;
  Voiced: Boolean;
  Arr: TArray<Single>;
  Started, Progress, Ready: Boolean;
begin
  if Length(Chunk) = 0 then
    Exit;

  Started := False;
  Progress := False;
  Ready := False;
  SetLength(Arr, 0);

  FLock.Enter;
  try
  Sum := 0;
  for I := 0 to High(Chunk) do
    Sum := Sum + Chunk[I] * Chunk[I];
  Rms := Sqrt(Sum / Length(Chunk));
  Voiced := Rms > FThreshold;

  if Voiced then
  begin
    if not FInSpeech then
    begin
      FInSpeech := True;
      FSeg.Clear;
      FSpeech := 0;
      FSilence := 0;
      FSinceProgress := 0;
      Started := Assigned(FOnSpeechStarted);
    end;
    FSeg.AddRange(Chunk);
    Inc(FSpeech, Length(Chunk));
    FSilence := 0;
    Inc(FSinceProgress, Length(Chunk));
    if FSinceProgress >= FProgressEvery then
    begin
      FSinceProgress := 0;
      Arr := FSeg.ToArray;
      Progress := Assigned(FOnSpeechProgress);
    end;
  end
  else if FInSpeech then
  begin
    FSeg.AddRange(Chunk);
    Inc(FSilence, Length(Chunk));
    if FSilence >= FSilenceToEnd then
    begin
      FInSpeech := False;
      if FSpeech >= FMinSpeech then
      begin
        Arr := FSeg.ToArray;
        Ready := Assigned(FOnSegmentReady);
      end;
      FSeg.Clear;
    end;
  end;
  finally
    FLock.Leave;
  end;

  if Started and Assigned(FOnSpeechStarted) then
    FOnSpeechStarted;
  if Progress and (Length(Arr) > 0) and Assigned(FOnSpeechProgress) then
    FOnSpeechProgress(Arr);
  if Ready and (Length(Arr) > 0) and Assigned(FOnSegmentReady) then
    FOnSegmentReady(Arr);
end;

end.
