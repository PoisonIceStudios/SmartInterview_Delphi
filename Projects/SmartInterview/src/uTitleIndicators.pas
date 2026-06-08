unit uTitleIndicators;

interface

uses
  System.Types,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  System.Math;

procedure PaintTitleWaveform(PaintBox: TPaintBox; Recording: Boolean; Phase: Double);
procedure PaintTitleMic(PaintBox: TPaintBox; Active: Boolean);

implementation

uses
  Winapi.Windows;

const
  GlyphMic = #$E720;
  WaveBars = 5;
  WaveBarW = 2;
  WaveGap = 2;
  DT_CENTER = $00000001;
  DT_VCENTER = $00000004;
  DT_SINGLELINE = $00000020;

function WaveformWidth: Integer;
begin
  Result := WaveBars * WaveBarW + (WaveBars - 1) * WaveGap;
end;

procedure PaintTitleWaveform(PaintBox: TPaintBox; Recording: Boolean; Phase: Double);
var
  Canvas: TCanvas;
  I, Amp, H, BX, StartX, CY: Integer;
  Col: TColor;
begin
  Canvas := PaintBox.Canvas;
  if Recording then
    Col := clHighlight
  else
    Col := clGray;
  Canvas.Brush.Color := Col;
  Canvas.Brush.Style := bsSolid;
  StartX := (PaintBox.Width - WaveformWidth) div 2;
  CY := PaintBox.Height div 2;
  for I := 0 to WaveBars - 1 do
  begin
    if Recording then
      Amp := Trunc(4 + 5 * Abs(Sin(Phase + I * 0.9)))
    else
      Amp := 2;
    H := Amp * 2;
    BX := StartX + I * (WaveBarW + WaveGap);
    Canvas.FillRect(Rect(BX, CY - H div 2, BX + WaveBarW, CY + H div 2));
  end;
end;

procedure PaintTitleMic(PaintBox: TPaintBox; Active: Boolean);
var
  Col: TColor;
  R: TRect;
begin
  if Active then
    Col := clHighlight
  else
    Col := clGray;
  with PaintBox.Canvas do
  begin
    Brush.Style := bsClear;
    SetBkMode(Handle, TRANSPARENT);
    Font.Name := 'Segoe MDL2 Assets';
    Font.Size := 12;
    Font.Color := Col;
    Font.Quality := fqClearTypeNatural;
    R := PaintBox.ClientRect;
    DrawText(Handle, PChar(GlyphMic), -1, R, DT_CENTER or DT_VCENTER or DT_SINGLELINE);
  end;
end;

end.
