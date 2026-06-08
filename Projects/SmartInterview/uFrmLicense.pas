unit uFrmLicense;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.UITypes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TFrmLicense = class(TForm)
    pnlTitle: TPanel;
    lblTitle: TLabel;
    lblInfo: TLabel;
    lblForum: TLabel;
    edtForum: TEdit;
    lblLicense: TLabel;
    edtLicense: TEdit;
    lblStatus: TLabel;
    btnExit: TButton;
    btnActivate: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnActivateClick(Sender: TObject);
    procedure btnExitClick(Sender: TObject);
  private
    procedure SetStatus(const Msg: string; Ok: Boolean);
    procedure StyleForm;
  public
    class function EnsureLicensed: Boolean;
    class function PromptRelicense: Boolean;
  end;

implementation

{$R *.dfm}

uses
  uTheme, uLicenseService;

class function TFrmLicense.PromptRelicense: Boolean;
var
  F: TFrmLicense;
begin
  F := TFrmLicense.Create(nil);
  try
    Result := F.ShowModal = mrOK;
    if Result then
      Result := LicenseIsValid;
  finally
    F.Free;
  end;
end;

class function TFrmLicense.EnsureLicensed: Boolean;
var
  F: TFrmLicense;
begin
  if LicenseIsValid then
    Exit(True);
  F := TFrmLicense.Create(nil);
  try
    Result := F.ShowModal = mrOK;
    if Result and not LicenseIsValid then
    begin
      MessageDlg(
        'The license key was accepted but could not be verified after saving.' + sLineBreak +
        'Check that SmartInterview can write to HKCU\Software\SmartInterview, then try again.',
        mtError, [mbOK], 0);
      Result := False;
    end;
  finally
    F.Free;
  end;
end;

procedure TFrmLicense.StyleForm;
begin
  StyleDialogForm(Self, pnlTitle, lblTitle);
  lblInfo.Font.Color := ThemeTextDim;
  lblForum.Font.Color := ThemeTextDim;
  lblLicense.Font.Color := ThemeTextDim;
  StyleInput(edtForum);
  StyleInput(edtLicense);
  StyleDialogButton(btnActivate, True);
  StyleDialogButton(btnExit, False);
end;

procedure TFrmLicense.FormCreate(Sender: TObject);
var
  LastErr: string;
begin
  edtForum.Text := LicenseStoreGetForumUsername;
  StyleForm;
  LastErr := LicenseLastCheckError;
  if LastErr <> '' then
    SetStatus(LastErr, False);
end;

procedure TFrmLicense.SetStatus(const Msg: string; Ok: Boolean);
begin
  lblStatus.Caption := Msg;
  if Ok then
    lblStatus.Font.Color := ThemeOk
  else
    lblStatus.Font.Color := ThemeWarn;
end;

procedure TFrmLicense.btnActivateClick(Sender: TObject);
var
  Err: string;
begin
  if not LicenseTryActivate(edtLicense.Text, edtForum.Text, Err) then
  begin
    SetStatus(Err, False);
    Exit;
  end;
  if not LicenseIsValid then
  begin
    SetStatus('License saved but verification failed. Check registry permissions.', False);
    Exit;
  end;
  SetStatus('License activated.', True);
  ModalResult := mrOK;
end;

procedure TFrmLicense.btnExitClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
