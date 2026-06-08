unit uFrmAbout;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Imaging.pngimage;

type
  TFrmAbout = class(TForm)
    pnlTitle: TPanel;
    lblTitle: TLabel;
    lblAppName: TLabel;
    lblVersion: TLabel;
    lblDesc: TLabel;
    lblShortcuts: TLabel;
    memShortcuts: TMemo;
    btnClose: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
  private
    procedure StyleForm;
  end;

implementation

{$R *.dfm}

uses
  uGlobalKeyboardHook, uTheme;

procedure TFrmAbout.StyleForm;
begin
  StyleDialogForm(Self, pnlTitle, lblTitle);
  lblAppName.Font.Color := ThemeAccent;
  lblVersion.Font.Color := ThemeTextDim;
  lblDesc.Font.Color := ThemeTextDim;
  lblShortcuts.Font.Color := ThemeText;
  StyleDialogMemo(memShortcuts);
  StyleDialogButton(btnClose, False);
end;

procedure TFrmAbout.FormCreate(Sender: TObject);
var
  Key: TListeningKey;
begin
  Key := ListeningKeyLoadSaved;
  memShortcuts.Lines.Text :=
    ListeningKeyHoldHint(Key) + ': listen and generate an answer' + sLineBreak +
    'F3: toggle always on top' + sLineBreak +
    'F7 / F8: more / less transparent';
  memShortcuts.ReadOnly := True;
  StyleForm;
end;

procedure TFrmAbout.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
