unit uFrmSettings;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Math,
  System.UITypes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.ComCtrls, uVoiceSegmenter, uAudioCapture, uWasapiCapture;

type
  TFrmSettings = class(TForm)
    pnlTitle: TPanel;
    lblTitle: TLabel;
    lblInfo: TLabel;
    chkAuto: TCheckBox;
    lblMeter: TLabel;
    pnlMeterWrap: TPanel;
    prgMeter: TProgressBar;
    pbMeterOverlay: TPaintBox;
    lblState: TLabel;
    lblThresh: TLabel;
    trkThresh: TTrackBar;
    lblSilence: TLabel;
    trkSilence: TTrackBar;
    lblMin: TLabel;
    trkMin: TTrackBar;
    tmrMeter: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure chkAutoClick(Sender: TObject);
    procedure trkThreshChange(Sender: TObject);
    procedure trkSilenceChange(Sender: TObject);
    procedure trkMinChange(Sender: TObject);
    procedure tmrMeterTimer(Sender: TObject);
    procedure pbMeterOverlayPaint(Sender: TObject);
  private
    FSegmenter: TVoiceSegmenter;
    FAudio: TAudioCapture;
    FIsAutoOn: TFunc<Boolean>;
    FSetAuto: TProc<Boolean>;
    FOnMonitorStart: TProc;
    FOnMonitorStop: TProc;
    FOnClosed: TProc;
    FRms: Single;
    FPrevOnSystemSamples: TWasapiSampleEvent;
    procedure ResetMeter;
    procedure UpdateLabels;
    procedure BindControls;
    procedure ApplyMeterStyle(VoiceDetected: Boolean);
    procedure InvalidateMeterOverlay;
    procedure ChainedOnSystemSamples(const Samples: TArray<Single>);
    procedure OnSettingsSamples(const Samples: TArray<Single>);
    procedure EnsureMeterOverlayOnTop;
    function ThresholdToValue(T: Single): Integer;
    function ValueToThreshold(V: Integer): Single;
  public
    procedure Configure(Seg: TVoiceSegmenter; Audio: TAudioCapture;
      const IsAutoOn: TFunc<Boolean>; const SetAuto: TProc<Boolean>;
      const OnMonitorStart: TProc = nil; const OnMonitorStop: TProc = nil;
      const OnClosed: TProc = nil);
    procedure SyncAutoMode(On: Boolean);
  end;

var
  FrmSettings: TFrmSettings;

implementation

{$R *.dfm}

uses
  uAppSettings;

const
  MeterMax = 1.0;
  PBM_SETBARCOLOR = $0409;
  PBM_SETBKCOLOR = $2001;

procedure TFrmSettings.Configure(Seg: TVoiceSegmenter; Audio: TAudioCapture;
  const IsAutoOn: TFunc<Boolean>; const SetAuto: TProc<Boolean>;
  const OnMonitorStart: TProc; const OnMonitorStop: TProc; const OnClosed: TProc);
begin
  FSegmenter := Seg;
  FAudio := Audio;
  FIsAutoOn := IsAutoOn;
  FSetAuto := SetAuto;
  FOnMonitorStart := OnMonitorStart;
  FOnMonitorStop := OnMonitorStop;
  FOnClosed := OnClosed;
  BindControls;
end;

procedure TFrmSettings.SyncAutoMode(On: Boolean);
begin
  chkAuto.Checked := On;
  if not On then
    ResetMeter;
end;

procedure TFrmSettings.ResetMeter;
begin
  FRms := 0;
  prgMeter.Position := 0;
  lblState.Caption := 'Silence';
  ApplyMeterStyle(False);
  InvalidateMeterOverlay;
end;

procedure TFrmSettings.InvalidateMeterOverlay;
begin
  if pbMeterOverlay <> nil then
    pbMeterOverlay.Invalidate;
end;

procedure TFrmSettings.BindControls;
begin
  if FSegmenter = nil then
    Exit;
  if Assigned(FIsAutoOn) then
    chkAuto.Checked := FIsAutoOn();
  trkThresh.Position := ThresholdToValue(FSegmenter.Threshold);
  trkSilence.Position := FSegmenter.SilenceMs;
  trkMin.Position := FSegmenter.MinSpeechMs;
  UpdateLabels;
end;

procedure TFrmSettings.ApplyMeterStyle(VoiceDetected: Boolean);
var
  BarColor: TColor;
begin
  if not prgMeter.HandleAllocated then
    Exit;
  if VoiceDetected then
    BarColor := clGreen
  else
    BarColor := clHighlight;
  SendMessage(prgMeter.Handle, PBM_SETBARCOLOR, 0, ColorToRGB(BarColor));
  SendMessage(prgMeter.Handle, PBM_SETBKCOLOR, 0, ColorToRGB(clBtnFace));
end;

function TFrmSettings.ThresholdToValue(T: Single): Integer;
begin
  Result := Round(T / MeterMax * 1000);
end;

function TFrmSettings.ValueToThreshold(V: Integer): Single;
begin
  Result := V / 1000.0 * MeterMax;
end;

procedure TFrmSettings.UpdateLabels;
begin
  if FSegmenter = nil then
    Exit;
  lblThresh.Caption := Format('Voice threshold: %.3f', [FSegmenter.Threshold]);
  lblSilence.Caption := Format('Silence duration: %d ms', [FSegmenter.SilenceMs]);
  lblMin.Caption := Format('Minimum speech: %d ms', [FSegmenter.MinSpeechMs]);
end;

procedure TFrmSettings.FormCreate(Sender: TObject);
begin
  trkThresh.Min := 0;
  trkThresh.Max := 1000;
  trkThresh.Frequency := 50;
  trkThresh.TickMarks := tmBoth;
  trkSilence.Min := 200;
  trkSilence.Max := 2500;
  trkSilence.Frequency := 100;
  trkMin.Min := 100;
  trkMin.Max := 2000;
  trkMin.Frequency := 100;
  pbMeterOverlay.ControlStyle := pbMeterOverlay.ControlStyle + [csParentBackground];
  prgMeter.Min := 0;
  prgMeter.Max := 100;
  prgMeter.Position := 0;
  prgMeter.Smooth := True;
  ApplyMeterStyle(False);
  EnsureMeterOverlayOnTop;
end;

procedure TFrmSettings.EnsureMeterOverlayOnTop;
begin
  if (pnlMeterWrap <> nil) and (pbMeterOverlay <> nil) then
    pbMeterOverlay.BringToFront;
end;

procedure TFrmSettings.OnSettingsSamples(const Samples: TArray<Single>);
var
  Sum: Double;
  I: Integer;
begin
  Sum := 0;
  for I := 0 to High(Samples) do
    Sum := Sum + Samples[I] * Samples[I];
  if Length(Samples) > 0 then
    FRms := Sqrt(Sum / Length(Samples));
end;

procedure TFrmSettings.ChainedOnSystemSamples(const Samples: TArray<Single>);
begin
  OnSettingsSamples(Samples);
  if Assigned(FPrevOnSystemSamples) then
    FPrevOnSystemSamples(Samples);
end;

procedure TFrmSettings.FormShow(Sender: TObject);
begin
  FRms := 0;
  prgMeter.Position := 0;
  if Assigned(FOnMonitorStart) then
    FOnMonitorStart();
  if FAudio <> nil then
  begin
    FPrevOnSystemSamples := FAudio.OnSystemSamples;
    FAudio.OnSystemSamples := ChainedOnSystemSamples;
  end;
  EnsureMeterOverlayOnTop;
  ApplyMeterStyle(False);
  tmrMeter.Enabled := True;
end;

procedure TFrmSettings.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  tmrMeter.Enabled := False;
  if FAudio <> nil then
    FAudio.OnSystemSamples := FPrevOnSystemSamples;
  if Assigned(FOnMonitorStop) then
    FOnMonitorStop();
  if FSegmenter <> nil then
    SaveVad(FSegmenter);
  if Assigned(FOnClosed) then
    FOnClosed();
  Action := caHide;
end;

procedure TFrmSettings.chkAutoClick(Sender: TObject);
begin
  if Assigned(FSetAuto) then
    FSetAuto(chkAuto.Checked);
  if not chkAuto.Checked then
    ResetMeter;
end;

procedure TFrmSettings.trkThreshChange(Sender: TObject);
begin
  if FSegmenter = nil then
    Exit;
  FSegmenter.Threshold := ValueToThreshold(trkThresh.Position);
  UpdateLabels;
  SaveVad(FSegmenter);
  InvalidateMeterOverlay;
end;

procedure TFrmSettings.trkSilenceChange(Sender: TObject);
begin
  if FSegmenter = nil then
    Exit;
  FSegmenter.SilenceMs := trkSilence.Position;
  UpdateLabels;
  SaveVad(FSegmenter);
end;

procedure TFrmSettings.trkMinChange(Sender: TObject);
begin
  if FSegmenter = nil then
    Exit;
  FSegmenter.MinSpeechMs := trkMin.Position;
  UpdateLabels;
  SaveVad(FSegmenter);
end;

procedure TFrmSettings.tmrMeterTimer(Sender: TObject);
var
  Voice: Boolean;
  Level: Integer;
begin
  if FSegmenter = nil then
    Exit;
  Level := Round(EnsureRange(FRms / MeterMax, 0, 1) * 100);
  prgMeter.Position := Level;
  Voice := FRms > FSegmenter.Threshold;
  if Voice then
    lblState.Caption := 'Voice detected'
  else
    lblState.Caption := 'Silence';
  ApplyMeterStyle(Voice);
  InvalidateMeterOverlay;
end;

procedure TFrmSettings.pbMeterOverlayPaint(Sender: TObject);
var
  ThreshX: Integer;
begin
  if FSegmenter = nil then
    Exit;
  ThreshX := Round(EnsureRange(FSegmenter.Threshold / MeterMax, 0, 1) * pbMeterOverlay.Width);
  with pbMeterOverlay.Canvas do
  begin
    Brush.Style := bsClear;
    SetBkMode(Handle, TRANSPARENT);
    Pen.Color := clMaroon;
    Pen.Width := 2;
    MoveTo(ThreshX, 0);
    LineTo(ThreshX, pbMeterOverlay.Height);
  end;
end;

end.
