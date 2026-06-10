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
  uFrmProfile in 'uFrmProfile.pas' {FrmProfile},
  uFrmAbout in 'uFrmAbout.pas' {FrmAbout},
  uFrmSettings in 'uFrmSettings.pas' {FrmSettings},
  uFrmMicSettings in 'uFrmMicSettings.pas' {FrmMicSettings},
  uDialogZOrder in 'src\uDialogZOrder.pas',
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

  // Pre-create the design-time dialog forms (still in the project, still editable in the IDE).
  // IMPORTANT: do NOT use Application.CreateForm here — the FIRST Application.CreateForm call
  // becomes the application MainForm, and ShowModal on the MainForm before Application.Run
  // does not close on ModalResult (license dialog would hang on "License activated."). The
  // engine must also start (in RunStartup) before TMainForm is created, so TMainForm must be
  // the LAST form created and the only one registered as MainForm.
  FrmLicense := TFrmLicense.Create(Application);
  FrmDisclaimer := TFrmDisclaimer.Create(Application);
  FrmInterviewSetup := TFrmInterviewSetup.Create(Application);
  FrmProfile := TFrmProfile.Create(Application);
  FrmSplash := TFrmSplash.Create(Application);
  FrmAbout := TFrmAbout.Create(Application);
  FrmSettings := TFrmSettings.Create(Application);
  FrmMicSettings := TFrmMicSettings.Create(Application);

  if not TFrmLicense.EnsureLicensed then
    Halt(0);

  if not TFrmDisclaimer.EnsureAccepted then
    Halt(0);

  TFrmInterviewSetup.RequireProfile;

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
