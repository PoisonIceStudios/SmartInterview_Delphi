unit uFrmInterviewSetup;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TFrmInterviewSetup = class(TForm)
    pnlTitle: TPanel;
    lblTitle: TLabel;
    lblInfo: TLabel;
    btnSetup: TButton;
    btnSkip: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnSetupClick(Sender: TObject);
    procedure btnSkipClick(Sender: TObject);
  private
    procedure StyleForm;
  public
    class procedure RunOptionalPrompt;
    class function ShowSetupDialog(AOwner: TComponent): Boolean;
  end;

implementation

{$R *.dfm}

uses
  uInterviewProfile, uFrmProfile, uTheme;

class procedure TFrmInterviewSetup.RunOptionalPrompt;
var
  F: TFrmInterviewSetup;
  P: TInterviewProfile;
begin
  if not ProfileShouldOfferSetupPrompt then
    Exit;
  P := ProfileLoad;
  if P.HasContent then
  begin
    ProfileMarkSetupPromptDone;
    Exit;
  end;
  F := TFrmInterviewSetup.Create(nil);
  try
    if F.ShowModal = mrOK then
      ShowSetupDialog(nil)
    else
      ProfileMarkSetupPromptSkipped;
  finally
    F.Free;
  end;
end;

class function TFrmInterviewSetup.ShowSetupDialog(AOwner: TComponent): Boolean;
var
  F: TFrmProfile;
begin
  F := TFrmProfile.Create(AOwner);
  try
    Result := F.ShowModal = mrOK;
    if Result then
      ProfileMarkSetupPromptDone;
  finally
    F.Free;
  end;
end;

procedure TFrmInterviewSetup.StyleForm;
begin
  StyleDialogForm(Self, pnlTitle, lblTitle);
  lblInfo.Font.Color := ThemeTextDim;
  StyleDialogButton(btnSetup, True);
  StyleDialogButton(btnSkip, False);
end;

procedure TFrmInterviewSetup.FormCreate(Sender: TObject);
begin
  StyleForm;
end;

procedure TFrmInterviewSetup.btnSetupClick(Sender: TObject);
begin
  ModalResult := mrOK;
end;

procedure TFrmInterviewSetup.btnSkipClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
