unit uFrmDisclaimer;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TFrmDisclaimer = class(TForm)
    memEula: TMemo;
    chkAccept: TCheckBox;
    btnDecline: TButton;
    btnAccept: TButton;
    procedure FormCreate(Sender: TObject);
    procedure chkAcceptClick(Sender: TObject);
    procedure btnAcceptClick(Sender: TObject);
    procedure btnDeclineClick(Sender: TObject);
  private
    procedure StyleForm;
  public
    class function EnsureAccepted: Boolean;
  end;

implementation

{$R *.dfm}

uses
  uRegistryStore, uTheme;

class function TFrmDisclaimer.EnsureAccepted: Boolean;
var
  F: TFrmDisclaimer;
begin
  if IsEulaAccepted then
    Exit(True);
  F := TFrmDisclaimer.Create(nil);
  try
    if F.ShowModal = mrOK then
    begin
      SetEulaAccepted;
      Exit(True);
    end;
    Result := False;
  finally
    F.Free;
  end;
end;

procedure TFrmDisclaimer.StyleForm;
begin
  Color := ThemeBase;
  Font.Name := ThemeFontFamily;
  Font.Color := ThemeText;
  StyleDialogMemo(memEula);
  StyleCheckBox(chkAccept);
  StyleDialogButton(btnAccept, True);
  StyleDialogButton(btnDecline, False);
end;

procedure TFrmDisclaimer.FormCreate(Sender: TObject);
begin
  btnAccept.Enabled := False;
  StyleForm;
end;

procedure TFrmDisclaimer.chkAcceptClick(Sender: TObject);
begin
  btnAccept.Enabled := chkAccept.Checked;
end;

procedure TFrmDisclaimer.btnAcceptClick(Sender: TObject);
begin
  ModalResult := mrOK;
end;

procedure TFrmDisclaimer.btnDeclineClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
