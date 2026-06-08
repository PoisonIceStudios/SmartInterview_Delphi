program SmartInterview;

uses
  Vcl.Forms,
  Vcl.Dialogs,
  System.SysUtils,
  System.UITypes,
  Winapi.Windows,
  uFrmSplash in 'uFrmSplash.pas' {FrmSplash},
  uFrmLicense in 'uFrmLicense.pas' {FrmLicense},
  uFrmDisclaimer in 'uFrmDisclaimer.pas' {FrmDisclaimer},
  uFrmInterviewSetup in 'uFrmInterviewSetup.pas' {FrmInterviewSetup},
  uMainForm in 'uMainForm.pas' {MainForm},
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

const
  MutexName = 'Local\SmartInterview.SingleInstance';

begin
  // Single instance: second launch exits quietly.
  if CreateMutex(nil, True, MutexName) = 0 then
    Halt(0);
  if GetLastError = ERROR_ALREADY_EXISTS then
    Halt(0);

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Blue Rock SE');
  Application.Title := 'SmartInterview';

  if not TFrmLicense.EnsureLicensed then
    Halt(0);

  if not TFrmDisclaimer.EnsureAccepted then
    Halt(0);

  TFrmInterviewSetup.RunOptionalPrompt;

  try
    TFrmSplash.RunStartup;
  except
    on E: Exception do
    begin
      MessageDlg(E.Message, mtError, [mbOk], 0);
      Halt(0);
    end;
  end;

  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
