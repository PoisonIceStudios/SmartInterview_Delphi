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
  public
    class function EnsureAccepted: Boolean;
  end;

var
  FrmDisclaimer: TFrmDisclaimer;

implementation

{$R *.dfm}

uses
  uRegistryStore;

class function TFrmDisclaimer.EnsureAccepted: Boolean;
begin
  if IsEulaAccepted then
    Exit(True);
  if FrmDisclaimer.ShowModal = mrOK then
  begin
    SetEulaAccepted;
    Exit(True);
  end;
  Result := False;
end;

procedure TFrmDisclaimer.FormCreate(Sender: TObject);
begin
  btnAccept.Enabled := False;
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
