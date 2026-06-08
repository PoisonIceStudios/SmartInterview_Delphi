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
    FAcceptUiUpdates: Boolean;
    FMainThreadId: DWORD;
    procedure SetStatusText(const Text: string);
    procedure StartupFinished;
    procedure QueueStatus(const Text: string);
  public
    procedure ExecuteStartup;
    class procedure RunStartup;
  end;

var
  FrmSplash: TFrmSplash;

implementation

{$R *.dfm}

var
  GSplashForm: TFrmSplash = nil;

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
begin
  FrmSplash.ExecuteStartup;
end;

procedure TFrmSplash.ExecuteStartup;
begin
  FStartupOk := False;
  FStartupError := '';
  FAcceptUiUpdates := True;
  ShowModal;
  if FStartupOk then
    Exit;
  if FStartupError <> '' then
    raise Exception.Create(FStartupError)
  else
    raise Exception.Create('Startup cancelled.');
end;

procedure TFrmSplash.FormCreate(Sender: TObject);
var
  PngPath: string;
  Png: TPngImage;
begin
  GSplashForm := Self;
  FAcceptUiUpdates := True;
  FMainThreadId := GetCurrentThreadId;
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
  lblStatus.ParentFont := False;
end;

procedure TFrmSplash.QueueStatus(const Text: string);
var
  Msg: string;
begin
  Msg := Text;
  if GetCurrentThreadId = FMainThreadId then
  begin
    if FAcceptUiUpdates then
      SetStatusText(Msg);
    Exit;
  end;
  TThread.Queue(nil, procedure
  begin
    if (GSplashForm <> nil) and GSplashForm.FAcceptUiUpdates then
      GSplashForm.SetStatusText(Msg);
  end);
end;

procedure TFrmSplash.SetStatusText(const Text: string);
begin
  if not FAcceptUiUpdates then
    Exit;
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
  Application.ProcessMessages;
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
  FAcceptUiUpdates := False;
  if GSplashForm = Self then
    GSplashForm := nil;
  imgSplash.Picture := nil;
end;

end.
