program LicenseManager;

uses
  Vcl.Forms,
  LicenseManagerMain in 'LicenseManagerMain.pas' {FrmLicenseManagerMain},
  uLicenseRecordStore in 'uLicenseRecordStore.pas',
  uLicenseKeyGen in 'uLicenseKeyGen.pas',
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Sky');
  Application.Title := 'SmartInterview License Manager';
  Application.CreateForm(TFrmLicenseManagerMain, FrmLicenseManagerMain);
  Application.Run;
end.
