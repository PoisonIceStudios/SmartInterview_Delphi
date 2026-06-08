unit uFrmSplash;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Threading,
  System.UITypes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Dialogs,
  Vcl.Imaging.pngimage, uAppStartup;

type
  TFrmSplash = class(TForm)
    imgSplash: TImage;
    lblStatus: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FStartupOk: Boolean;
    FStartupError: string;
    procedure SetStatusText(const Text: string);
    procedure StartupFinished;
    procedure QueueStatus(const Text: string);
  public
    class procedure RunStartup;
  end;

implementation

{$R *.dfm}

uses
  uTheme;

type
  TMainThreadInvoker = class
  strict private
    FProc: TProc;
  public
    constructor Create(const AProc: TProc);
    procedure Invoke;
  end;

constructor TMainThreadInvoker.Create(const AProc: TProc);
begin
  inherited Create;
  FProc := AProc;
end;

procedure TMainThreadInvoker.Invoke;
begin
  try
    if Assigned(FProc) then
      FProc();
  finally
    Free;
  end;
end;

class procedure TFrmSplash.RunStartup;
var
  F: TFrmSplash;
begin
  F := TFrmSplash.Create(nil);
  try
    F.ShowModal;
    if F.FStartupOk then
      Exit;
    if F.FStartupError <> '' then
      raise Exception.Create(F.FStartupError)
    else
      raise Exception.Create('Startup cancelled.');
  finally
    F.Free;
  end;
end;

procedure TFrmSplash.FormCreate(Sender: TObject);
var
  PngPath: string;
  Png: TPngImage;
begin
  FStartupOk := False;
  FStartupError := '';
  PngPath := ExtractFilePath(ParamStr(0)) + 'Resources\splash.png';
  if FileExists(PngPath) then
  begin
    Png := TPngImage.Create;
    try
      Png.LoadFromFile(PngPath);
      imgSplash.Picture.Assign(Png);
    finally
      Png.Free;
    end;
  end;
  lblStatus.Caption := '';
  Color := ThemeBase;
  lblStatus.Font.Name := ThemeFontFamily;
  lblStatus.Font.Color := ThemeTextDim;
  lblStatus.ParentFont := False;
end;

procedure TFrmSplash.QueueStatus(const Text: string);
var
  Msg: string;
  Invoker: TMainThreadInvoker;
begin
  Msg := Text;
  Invoker := TMainThreadInvoker.Create(procedure
  begin
    SetStatusText(Msg);
  end);
  TThread.Queue(nil, Invoker.Invoke);
end;

procedure TFrmSplash.SetStatusText(const Text: string);
begin
  lblStatus.Caption := Text;
  lblStatus.Update;
end;

procedure TFrmSplash.FormShow(Sender: TObject);
var
  Work: TProc;
begin
  Work := procedure
  var
    Invoker: TMainThreadInvoker;
  begin
    try
      RunInitialStartup(
        procedure(const S: string)
        begin
          QueueStatus(S);
        end);
      FStartupOk := True;
    except
      on E: Exception do
      begin
        FStartupOk := False;
        FStartupError := E.Message;
        QueueStatus('Startup error');
      end;
    end;
    Invoker := TMainThreadInvoker.Create(procedure
    begin
      StartupFinished;
    end);
    TThread.Queue(nil, Invoker.Invoke);
  end;
  TTask.Run(Work);
end;

procedure TFrmSplash.StartupFinished;
begin
  if FStartupOk then
    ModalResult := mrOk
  else
  begin
    SetStatusText(FStartupError);
    MessageDlg('Startup failed:' + sLineBreak + sLineBreak + FStartupError, mtError, [mbOk], 0);
    ModalResult := mrCancel;
  end;
end;

procedure TFrmSplash.FormDestroy(Sender: TObject);
begin
  imgSplash.Picture := nil;
end;

end.
