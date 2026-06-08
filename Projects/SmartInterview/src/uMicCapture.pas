unit uMicCapture;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.SyncObjs,
  uWasapi16k;

const
  MIC_CAPTURE_RATE = 16000;
  MIC_CAPTURE_MAX_SECONDS = 6;

type
  TMicCapture = class
  private
    FSource: TWasapi16kSource;
    FLock: TCriticalSection;
    FBuf: TList<Single>;
    FMaxSamples: Integer;
    procedure OnSamples(const Samples: TArray<Single>);
    function GetIsCapturing: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function Start: Boolean;
    procedure Stop;
    function Last(Seconds: Double): TArray<Single>;
    property IsCapturing: Boolean read GetIsCapturing;
  end;

implementation

uses
  System.Math;

constructor TMicCapture.Create;
begin
  inherited;
  FSource := TWasapi16kSource.Create;
  FSource.OnSamples16k := OnSamples;
  FLock := TCriticalSection.Create;
  FBuf := TList<Single>.Create;
  FMaxSamples := MIC_CAPTURE_RATE * MIC_CAPTURE_MAX_SECONDS;
end;

destructor TMicCapture.Destroy;
begin
  Stop;
  FSource.Free;
  FBuf.Free;
  FLock.Free;
  inherited;
end;

function TMicCapture.GetIsCapturing: Boolean;
begin
  Result := FSource.IsCapturing;
end;

procedure TMicCapture.OnSamples(const Samples: TArray<Single>);
var
  I: Integer;
  Extra: Integer;
begin
  FLock.Enter;
  try
    for I := 0 to High(Samples) do
      FBuf.Add(Samples[I]);
    Extra := FBuf.Count - FMaxSamples;
    if Extra > 0 then
      FBuf.DeleteRange(0, Extra);
  finally
    FLock.Leave;
  end;
end;

function TMicCapture.Start: Boolean;
begin
  FLock.Enter;
  try
    FBuf.Clear;
  finally
    FLock.Leave;
  end;
  Result := FSource.Start;
end;

procedure TMicCapture.Stop;
begin
  FSource.Stop;
end;

function TMicCapture.Last(Seconds: Double): TArray<Single>;
var
  Want, Start: Integer;
  I: Integer;
begin
  Want := Trunc(MIC_CAPTURE_RATE * Seconds);
  FLock.Enter;
  try
    Start := Max(0, FBuf.Count - Want);
    SetLength(Result, FBuf.Count - Start);
    for I := Start to FBuf.Count - 1 do
      Result[I - Start] := FBuf[I];
  finally
    FLock.Leave;
  end;
end;

end.
