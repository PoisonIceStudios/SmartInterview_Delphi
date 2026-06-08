unit uFrmLicense;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.UITypes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TFrmLicense = class(TForm)
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
  public
    procedure PrepareShow;
    class function EnsureLicensed: Boolean;
    class function PromptRelicense(AOwner: TComponent): Boolean;
  end;

var
  FrmLicense: TFrmLicense;

implementation

{$R *.dfm}

uses
  uLicenseService;

class function TFrmLicense.PromptRelicense(AOwner: TComponent): Boolean;
begin
  FrmLicense.PrepareShow;
  if AOwner is TCustomForm then
    FrmLicense.PopupParent := TCustomForm(AOwner)
  else
    FrmLicense.PopupParent := nil;
  Result := FrmLicense.ShowModal = mrOK;
  // btnActivate already validated and saved the key; do not call LicenseIsValid
  // here (second online UTC fetch can fail transiently and falsely reject activation).
end;

class function TFrmLicense.EnsureLicensed: Boolean;
begin
  if LicenseIsValid then
    Exit(True);
  FrmLicense.PrepareShow;
  FrmLicense.PopupParent := nil;
  Result := FrmLicense.ShowModal = mrOK;
  if Result and (Trim(LicenseStoreGet) = '') then
  begin
    MessageDlg(
      'The license key was accepted but could not be verified after saving.' + sLineBreak +
      'Check that SmartInterview can write to HKCU\Software\SmartInterview, then try again.',
      mtError, [mbOK], 0);
    Result := False;
  end;
end;

procedure TFrmLicense.PrepareShow;
var
  LastErr: string;
begin
  ModalResult := mrNone;
  edtForum.Text := LicenseStoreGetForumUsername;
  edtLicense.Text := LicenseStoreGet;
  lblStatus.Caption := '';
  LastErr := LicenseLastCheckError;
  if LastErr <> '' then
    SetStatus(LastErr, False);
end;

procedure TFrmLicense.FormCreate(Sender: TObject);
begin
  PrepareShow;
end;

procedure TFrmLicense.SetStatus(const Msg: string; Ok: Boolean);
begin
  lblStatus.Caption := Msg;
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
