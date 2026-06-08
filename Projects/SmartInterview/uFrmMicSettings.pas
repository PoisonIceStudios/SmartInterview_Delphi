unit uFrmMicSettings;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Math,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.ComCtrls, uMicDevices;

type
  TFrmMicSettings = class(TForm)
    pnlTitle: TPanel;
    lblTitle: TLabel;
    lblInfo: TLabel;
    chkUseMic: TCheckBox;
    lblDevice: TLabel;
    cmbDevice: TComboBox;
    lblMeter: TLabel;
    pnlMeterWrap: TPanel;
    prgMeter: TProgressBar;
    pbMeterOverlay: TPaintBox;
    lblState: TLabel;
    lblThresh: TLabel;
    trkThresh: TTrackBar;
    tmrMeter: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure chkUseMicClick(Sender: TObject);
    procedure cmbDeviceChange(Sender: TObject);
    procedure trkThreshChange(Sender: TObject);
    procedure tmrMeterTimer(Sender: TObject);
    procedure pbMeterOverlayPaint(Sender: TObject);
  private
    FDeviceIds: TStringList;
    FGetRms: TFunc<Single>;
    FGetThreshold: TFunc<Single>;
    FSetThreshold: TProc<Single>;
    FGetUseMic: TFunc<Boolean>;
    FSetUseMic: TProc<Boolean>;
    FOnMicDeviceChanged: TProc;
    FThreshold: Single;
    FUpdatingUi: Boolean;
    procedure ApplyMeterStyle(VoiceDetected: Boolean);
    procedure InvalidateMeterOverlay;
    procedure UpdateLabels;
    procedure RefreshDeviceList;
    procedure SyncFromHost;
    function ValueToThreshold(V: Integer): Single;
    function ThresholdToValue(T: Single): Integer;
    procedure EnsureMeterOverlayOnTop;
  public
    procedure Configure(const GetRms: TFunc<Single>; const GetThreshold: TFunc<Single>;
      const SetThreshold: TProc<Single>; const GetUseMic: TFunc<Boolean>;
      const SetUseMic: TProc<Boolean>; const OnMicDeviceChanged: TProc);
  end;

var
  FrmMicSettings: TFrmMicSettings;

implementation

{$R *.dfm}

const
  MeterMax = 1.0;
  PBM_SETBARCOLOR = $0409;
  PBM_SETBKCOLOR = $2001;

procedure TFrmMicSettings.Configure(const GetRms: TFunc<Single>;
  const GetThreshold: TFunc<Single>; const SetThreshold: TProc<Single>;
  const GetUseMic: TFunc<Boolean>; const SetUseMic: TProc<Boolean>;
  const OnMicDeviceChanged: TProc);
begin
  FGetRms := GetRms;
  FGetThreshold := GetThreshold;
  FSetThreshold := SetThreshold;
  FGetUseMic := GetUseMic;
  FSetUseMic := SetUseMic;
  FOnMicDeviceChanged := OnMicDeviceChanged;
  SyncFromHost;
end;

procedure TFrmMicSettings.SyncFromHost;
begin
  FUpdatingUi := True;
  try
    if Assigned(FGetThreshold) then
      FThreshold := FGetThreshold();
    trkThresh.Position := ThresholdToValue(FThreshold);
    if Assigned(FGetUseMic) then
      chkUseMic.Checked := FGetUseMic();
    RefreshDeviceList;
    UpdateLabels;
  finally
    FUpdatingUi := False;
  end;
end;

function TFrmMicSettings.ThresholdToValue(T: Single): Integer;
begin
  Result := Round(T / MeterMax * 1000);
end;

function TFrmMicSettings.ValueToThreshold(V: Integer): Single;
begin
  Result := V / 1000.0 * MeterMax;
end;

procedure TFrmMicSettings.UpdateLabels;
begin
  lblThresh.Caption := Format('Microphone threshold: %.3f', [FThreshold]);
end;

procedure TFrmMicSettings.RefreshDeviceList;
var
  Devices: TArray<TMicDevice>;
  D: TMicDevice;
  SelId: string;
  I, Pick: Integer;
begin
  SelId := MicDevicesGetSelectedId;
  Pick := 0;
  cmbDevice.Items.BeginUpdate;
  FDeviceIds.BeginUpdate;
  try
    cmbDevice.Items.Clear;
    FDeviceIds.Clear;
    Devices := MicDevicesList;
    for I := 0 to High(Devices) do
    begin
      D := Devices[I];
      cmbDevice.Items.Add(D.Name);
      FDeviceIds.Add(D.Id);
      if D.Id = SelId then
        Pick := I;
    end;
    if cmbDevice.Items.Count > 0 then
      cmbDevice.ItemIndex := Pick;
  finally
    FDeviceIds.EndUpdate;
    cmbDevice.Items.EndUpdate;
  end;
end;

procedure TFrmMicSettings.ApplyMeterStyle(VoiceDetected: Boolean);
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

procedure TFrmMicSettings.InvalidateMeterOverlay;
begin
  if pbMeterOverlay <> nil then
    pbMeterOverlay.Invalidate;
end;

procedure TFrmMicSettings.FormCreate(Sender: TObject);
begin
  FDeviceIds := TStringList.Create;
  trkThresh.Min := 0;
  trkThresh.Max := 1000;
  trkThresh.Frequency := 50;
  trkThresh.TickMarks := tmBoth;
  pbMeterOverlay.ControlStyle := pbMeterOverlay.ControlStyle + [csParentBackground];
  prgMeter.Min := 0;
  prgMeter.Max := 100;
  prgMeter.Position := 0;
  prgMeter.Smooth := True;
  ApplyMeterStyle(False);
  EnsureMeterOverlayOnTop;
end;

procedure TFrmMicSettings.EnsureMeterOverlayOnTop;
begin
  if (pnlMeterWrap <> nil) and (pbMeterOverlay <> nil) then
    pbMeterOverlay.BringToFront;
end;

procedure TFrmMicSettings.FormDestroy(Sender: TObject);
begin
  FDeviceIds.Free;
end;

procedure TFrmMicSettings.FormShow(Sender: TObject);
begin
  SyncFromHost;
  EnsureMeterOverlayOnTop;
  prgMeter.Position := 0;
  lblState.Caption := 'Silence';
  ApplyMeterStyle(False);
  InvalidateMeterOverlay;
  tmrMeter.Enabled := True;
end;

procedure TFrmMicSettings.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  tmrMeter.Enabled := False;
  Action := caHide;
end;

procedure TFrmMicSettings.chkUseMicClick(Sender: TObject);
begin
  if FUpdatingUi then
    Exit;
  if Assigned(FSetUseMic) then
    FSetUseMic(chkUseMic.Checked);
end;

procedure TFrmMicSettings.cmbDeviceChange(Sender: TObject);
var
  Idx: Integer;
begin
  if FUpdatingUi then
    Exit;
  Idx := cmbDevice.ItemIndex;
  if (Idx < 0) or (Idx >= FDeviceIds.Count) then
    Exit;
  if MicDevicesGetSelectedId = FDeviceIds[Idx] then
    Exit;
  MicDevicesSetSelectedId(FDeviceIds[Idx]);
  if Assigned(FOnMicDeviceChanged) then
    FOnMicDeviceChanged();
end;

procedure TFrmMicSettings.trkThreshChange(Sender: TObject);
begin
  FThreshold := ValueToThreshold(trkThresh.Position);
  if Assigned(FSetThreshold) then
    FSetThreshold(FThreshold);
  UpdateLabels;
  InvalidateMeterOverlay;
end;

procedure TFrmMicSettings.tmrMeterTimer(Sender: TObject);
var
  Rms: Single;
  Voice: Boolean;
  Level: Integer;
begin
  if Assigned(FGetRms) then
    Rms := FGetRms()
  else
    Rms := 0;
  Level := Round(EnsureRange(Rms / MeterMax, 0, 1) * 100);
  prgMeter.Position := Level;
  Voice := Rms > FThreshold;
  if Voice then
    lblState.Caption := 'Voice detected'
  else
    lblState.Caption := 'Silence';
  ApplyMeterStyle(Voice);
  InvalidateMeterOverlay;
end;

procedure TFrmMicSettings.pbMeterOverlayPaint(Sender: TObject);
var
  ThreshX: Integer;
begin
  ThreshX := Round(EnsureRange(FThreshold / MeterMax, 0, 1) * pbMeterOverlay.Width);
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
