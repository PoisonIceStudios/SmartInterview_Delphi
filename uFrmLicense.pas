unit uFrmLicense;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.UITypes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Clipbrd;

type
  TFrmLicense = class(TForm)
    pnlTitle: TPanel;
    lblTitle: TLabel;
    lblInfo: TLabel;
    lblForum: TLabel;
    edtForum: TEdit;
    lblActivation: TLabel;
    edtActivation: TEdit;
    btnGenerate: TButton;
    btnCopy: TButton;
    lblLicense: TLabel;
    edtLicense: TEdit;
    lblStatus: TLabel;
    btnExit: TButton;
    btnActivate: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnGenerateClick(Sender: TObject);
    procedure btnCopyClick(Sender: TObject);
    procedure btnActivateClick(Sender: TObject);
    procedure btnExitClick(Sender: TObject);
  private
    procedure SetStatus(const Msg: string; Ok: Boolean);
    procedure StyleForm;
  public
    class function EnsureLicensed: Boolean;
  end;

implementation

{$R *.dfm}

uses
  uTheme, uLicenseService;

const
  SupportEmail = 'licensing@smartinterview.app';

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
  lblActivation.Font.Color := ThemeTextDim;
  lblLicense.Font.Color := ThemeTextDim;
  StyleInput(edtForum);
  StyleInput(edtActivation);
  StyleInput(edtLicense);
  StyleDialogButton(btnActivate, True);
  StyleDialogButton(btnGenerate, False);
  StyleDialogButton(btnCopy, False);
  StyleDialogButton(btnExit, False);
end;

procedure TFrmLicense.FormCreate(Sender: TObject);
begin
  edtForum.Text := LicenseStoreGetForumUsername;
  StyleForm;
end;

procedure TFrmLicense.SetStatus(const Msg: string; Ok: Boolean);
begin
  lblStatus.Caption := Msg;
  if Ok then
    lblStatus.Font.Color := ThemeOk
  else
    lblStatus.Font.Color := ThemeWarn;
end;

procedure TFrmLicense.btnGenerateClick(Sender: TObject);
begin
  if Trim(edtForum.Text).IsEmpty then
  begin
    SetStatus('Enter your forum username first.', False);
    edtForum.SetFocus;
    Exit;
  end;
  try
    edtActivation.Text := LicenseBuildActivationRequest(edtForum.Text);
    edtActivation.Font.Color := clWindowText;
    SetStatus('Activation code generated. Copy it and send by email.', True);
  except
    edtActivation.Text := '';
    SetStatus('Could not generate activation code.', False);
  end;
end;

procedure TFrmLicense.btnCopyClick(Sender: TObject);
var
  Block: string;
begin
  if Trim(edtActivation.Text).IsEmpty then
  begin
    SetStatus('Generate the activation code first.', False);
    Exit;
  end;
  Block :=
    'SmartInterview license request' + sLineBreak + sLineBreak +
    'Forum username: ' + Trim(edtForum.Text) + sLineBreak +
    'Activation request code: ' + edtActivation.Text + sLineBreak + sLineBreak +
    'Send to: ' + SupportEmail;
  Clipboard.AsText := Block;
  SetStatus('Copied. Paste into your email to ' + SupportEmail, True);
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
