unit uTheme;

interface

uses
  Winapi.Windows,
  System.UITypes,
  Vcl.Forms,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.Buttons;

const
  ThemeFontFamily = 'Segoe UI';
  ThemeAccentRgbR = 54;
  ThemeAccentRgbG = 175;
  ThemeAccentRgbB = 205;

function ThemeBase: TColor;
function ThemeSurface: TColor;
function ThemeSurfaceAlt: TColor;
function ThemeTitleBar: TColor;
function ThemeAccent: TColor;
function ThemeText: TColor;
function ThemeTextDim: TColor;
function ThemeOk: TColor;
function ThemeWarn: TColor;
function ThemeReadDone: TColor;
function ThemeIndicatorIdle: TColor;
function ThemeIndicatorActive: TColor;
function ThemeResponseText: TColor;
function ThemeColor(R, G, B: Byte): TColor;

procedure StyleTitleBarButton(Button: TSpeedButton);
procedure StyleInput(Control: TWinControl);
procedure StyleDialogForm(Form: TCustomForm; TitlePanel: TPanel; TitleLabel: TLabel);
procedure StyleDialogMemo(Memo: TMemo);
procedure StyleDialogButton(Button: TButton; Primary: Boolean);

implementation

type
  TThemeCtrl = class(TControl);

function ThemeColor(R, G, B: Byte): TColor;
begin
  Result := RGB(R, G, B);
end;

function ThemeBase: TColor;
begin
  Result := ThemeColor(22, 22, 26);
end;

function ThemeSurface: TColor;
begin
  Result := ThemeColor(30, 30, 36);
end;

function ThemeSurfaceAlt: TColor;
begin
  Result := ThemeColor(38, 38, 44);
end;

function ThemeTitleBar: TColor;
begin
  Result := ThemeColor(26, 26, 30);
end;

function ThemeAccent: TColor;
begin
  Result := ThemeColor(ThemeAccentRgbR, ThemeAccentRgbG, ThemeAccentRgbB);
end;

function ThemeText: TColor;
begin
  Result := ThemeColor(230, 232, 238);
end;

function ThemeTextDim: TColor;
begin
  Result := ThemeColor(148, 152, 162);
end;

function ThemeOk: TColor;
begin
  Result := ThemeColor(110, 210, 140);
end;

function ThemeWarn: TColor;
begin
  Result := ThemeColor(240, 170, 70);
end;

function ThemeReadDone: TColor;
begin
  Result := ThemeColor(96, 160, 178);
end;

function ThemeIndicatorIdle: TColor;
begin
  Result := ThemeColor(45, 47, 59);
end;

function ThemeIndicatorActive: TColor;
begin
  Result := ThemeAccent;
end;

function ThemeResponseText: TColor;
begin
  Result := ThemeAccent;
end;

procedure StyleTitleBarButton(Button: TSpeedButton);
begin
  with TThemeCtrl(Button) do
  begin
    Font.Name := 'Segoe MDL2 Assets';
    Font.Size := 9;
    Font.Color := ThemeText;
    ParentFont := False;
    Height := 40;
    Width := 36;
    Color := ThemeTitleBar;
  end;
  Button.Flat := True;
  Button.Transparent := False;
end;

procedure StyleInput(Control: TWinControl);
begin
  with TThemeCtrl(Control) do
  begin
    Font.Name := ThemeFontFamily;
    Font.Color := ThemeText;
    Color := ThemeSurfaceAlt;
  end;
end;

procedure StyleDialogForm(Form: TCustomForm; TitlePanel: TPanel; TitleLabel: TLabel);
begin
  Form.Color := ThemeBase;
  Form.Font.Name := ThemeFontFamily;
  Form.Font.Color := ThemeText;
  TitlePanel.Color := ThemeTitleBar;
  TitleLabel.Font.Color := ThemeText;
end;

procedure StyleDialogMemo(Memo: TMemo);
begin
  Memo.Color := ThemeSurfaceAlt;
  Memo.Font.Name := ThemeFontFamily;
  Memo.Font.Color := ThemeText;
  Memo.BorderStyle := bsNone;
end;

procedure StyleDialogButton(Button: TButton; Primary: Boolean);
begin
  with TThemeCtrl(Button) do
  begin
    Font.Name := ThemeFontFamily;
    Font.Color := ThemeText;
    if Primary then
    begin
      Font.Style := [fsBold];
      Color := ThemeAccent;
    end
    else
      Color := ThemeSurface;
  end;
  Button.StyleElements := [seFont];
end;

end.
