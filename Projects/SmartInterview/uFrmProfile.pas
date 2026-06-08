unit uFrmProfile;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  uInterviewProfile;

type
  TFrmProfile = class(TForm)
    pnlTitle: TPanel;
    lblTitle: TLabel;
    lblInfo: TLabel;
    lblRole: TLabel;
    edtRole: TEdit;
    lblStack: TLabel;
    edtStack: TEdit;
    lblJob: TLabel;
    memJob: TMemo;
    lblExp: TLabel;
    memExp: TMemo;
    btnLater: TButton;
    btnClear: TButton;
    btnSave: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure btnLaterClick(Sender: TObject);
  private
    FResult: TInterviewProfile;
    procedure StyleForm;
    procedure LoadProfile(const P: TInterviewProfile);
  public
    property ProfileResult: TInterviewProfile read FResult;
  end;

implementation

{$R *.dfm}

uses
  uTheme;

procedure TFrmProfile.StyleForm;
begin
  StyleDialogForm(Self, pnlTitle, lblTitle);
  lblInfo.Font.Color := ThemeTextDim;
  lblRole.Font.Color := ThemeText;
  lblStack.Font.Color := ThemeText;
  lblJob.Font.Color := ThemeText;
  lblExp.Font.Color := ThemeText;
  StyleInput(edtRole);
  StyleInput(edtStack);
  StyleDialogMemo(memJob);
  StyleDialogMemo(memExp);
  StyleDialogButton(btnSave, True);
  StyleDialogButton(btnClear, False);
  StyleDialogButton(btnLater, False);
end;

procedure TFrmProfile.LoadProfile(const P: TInterviewProfile);
begin
  edtRole.Text := P.Role;
  edtStack.Text := P.TechStack;
  memJob.Lines.Text := P.JobDescription;
  memExp.Lines.Text := P.Experience;
end;

procedure TFrmProfile.FormCreate(Sender: TObject);
begin
  LoadProfile(ProfileLoad);
  StyleForm;
end;

procedure TFrmProfile.btnSaveClick(Sender: TObject);
begin
  FResult.Role := Trim(edtRole.Text);
  FResult.TechStack := Trim(edtStack.Text);
  FResult.JobDescription := Trim(memJob.Text);
  FResult.Experience := Trim(memExp.Text);
  ProfileSave(FResult);
  ModalResult := mrOK;
end;

procedure TFrmProfile.btnClearClick(Sender: TObject);
begin
  edtRole.Clear;
  edtStack.Clear;
  memJob.Clear;
  memExp.Clear;
end;

procedure TFrmProfile.btnLaterClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
