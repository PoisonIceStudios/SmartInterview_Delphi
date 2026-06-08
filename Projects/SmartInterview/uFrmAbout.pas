unit uFrmAbout;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Imaging.pngimage;

type
  TFrmAbout = class(TForm)
    lblAppName: TLabel;
    lblVersion: TLabel;
    lblRegistered: TLabel;
    lblExpiry: TLabel;
    lblShortcuts: TLabel;
    memShortcuts: TMemo;
    btnClose: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
  private
    procedure LoadLicenseInfo;
    function AppVersionText: string;
  public
    procedure PrepareShow;
    class procedure ShowAbout(AOwner: TComponent);
  end;

var
  FrmAbout: TFrmAbout;

implementation

{$R *.dfm}

uses
  uGlobalKeyboardHook, uLicenseService, uLicenseCodec, uDialogZOrder;

function TFrmAbout.AppVersionText: string;
var
  Size, Handle: DWORD;
  Buf: Pointer;
  Value: PChar;
  Len: UINT;
begin
  Result := '1.0.0';
  Size := GetFileVersionInfoSize(PChar(ParamStr(0)), Handle);
  if Size = 0 then
    Exit;
  GetMem(Buf, Size);
  try
    if GetFileVersionInfo(PChar(ParamStr(0)), 0, Size, Buf) and
       VerQueryValue(Buf, '\StringFileInfo\040904E4\FileVersion', Pointer(Value), Len) then
      Result := Trim(string(Value));
  finally
    FreeMem(Buf);
  end;
end;

procedure TFrmAbout.LoadLicenseInfo;
var
  Key, User, Err: string;
  Payload: TLicensePayload;
begin
  User := LicenseStoreGetForumUsername;
  Key := LicenseStoreGet;
  if User <> '' then
    lblRegistered.Caption := 'Registered to: ' + User
  else
    lblRegistered.Caption := 'Registered to: (not activated)';

  if (Key <> '') and LicenseCodecTryDecodePayload(Key, Payload, Err) then
    lblExpiry.Caption := 'License expires: ' + LicenseCodecFormatExpiry(Payload)
  else if Key <> '' then
    lblExpiry.Caption := 'License expires: (unknown)'
  else
    lblExpiry.Caption := 'License expires: —';
end;

class procedure TFrmAbout.ShowAbout(AOwner: TComponent);
begin
  FrmAbout.PrepareShow;
  PrepareDialogAboveMain(FrmAbout);
  FrmAbout.ShowModal;
end;

procedure TFrmAbout.PrepareShow;
var
  Key: TListeningKey;
begin
  LoadLicenseInfo;
  Key := ListeningKeyLoadSaved;
  memShortcuts.Lines.Text :=
    ListeningKeyHoldHint(Key) + ': listen and generate an answer' + sLineBreak +
    'F3: toggle always on top' + sLineBreak +
    'F7 / F8: more / less transparent';
end;

procedure TFrmAbout.FormCreate(Sender: TObject);
begin
  lblVersion.Caption := 'Version ' + AppVersionText;
  PrepareShow;
  memShortcuts.ReadOnly := True;
end;

procedure TFrmAbout.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
