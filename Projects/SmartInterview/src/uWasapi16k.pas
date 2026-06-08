unit uWasapi16k;

interface

uses
  System.SysUtils,
  uWasapiCapture,
  uMicDevices;

type
  TWasapi16kSource = class
  private
    FCapture: TWasapiMicCapture;
    FOnSamples16k: TWasapiSampleEvent;
    procedure OnMicSamples(const Samples: TArray<Single>);
    function GetIsCapturing: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function Start: Boolean;
    procedure Stop;
    property OnSamples16k: TWasapiSampleEvent read FOnSamples16k write FOnSamples16k;
    property IsCapturing: Boolean read GetIsCapturing;
  end;

implementation

constructor TWasapi16kSource.Create;
begin
  inherited;
  FCapture := TWasapiMicCapture.Create(MicDevicesGetSelectedId);
  FCapture.OnSamples := OnMicSamples;
end;

destructor TWasapi16kSource.Destroy;
begin
  FCapture.Free;
  inherited;
end;

procedure TWasapi16kSource.OnMicSamples(const Samples: TArray<Single>);
begin
  if Assigned(FOnSamples16k) then
    FOnSamples16k(Samples);
end;

function TWasapi16kSource.GetIsCapturing: Boolean;
begin
  Result := FCapture.Active;
end;

function TWasapi16kSource.Start: Boolean;
begin
  FCapture.Stop;
  FCapture.Free;
  FCapture := TWasapiMicCapture.Create(MicDevicesGetSelectedId);
  FCapture.OnSamples := OnMicSamples;
  Result := FCapture.Start;
end;

procedure TWasapi16kSource.Stop;
begin
  FCapture.Stop;
end;

end.
