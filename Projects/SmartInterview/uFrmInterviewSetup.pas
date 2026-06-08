unit uFrmInterviewSetup;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TFrmInterviewSetup = class(TForm)
    lblInfo: TLabel;
    btnSetup: TButton;
    btnSkip: TButton;
    procedure btnSetupClick(Sender: TObject);
    procedure btnSkipClick(Sender: TObject);
  public
    class procedure RunOptionalPrompt;
    class function ShowSetupDialog(AOwner: TComponent): Boolean;
  end;

var
  FrmInterviewSetup: TFrmInterviewSetup;

implementation

{$R *.dfm}

uses
  uInterviewProfile, uFrmProfile, uDialogZOrder;

class procedure TFrmInterviewSetup.RunOptionalPrompt;
var
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
  if FrmInterviewSetup.ShowModal = mrOK then
    ShowSetupDialog(nil)
  else
    ProfileMarkSetupPromptSkipped;
end;

class function TFrmInterviewSetup.ShowSetupDialog(AOwner: TComponent): Boolean;
begin
  PrepareDialogAboveMain(FrmProfile);
  Result := FrmProfile.ShowModal = mrOK;
  if Result then
    ProfileMarkSetupPromptDone;
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
