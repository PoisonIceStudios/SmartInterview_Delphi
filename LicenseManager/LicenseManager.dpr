program LicenseManager;

uses
  Vcl.Forms,
  LicenseManagerMain in 'LicenseManagerMain.pas' {FrmLicenseManagerMain},
  uLicenseRecordStore in 'uLicenseRecordStore.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'SmartInterview License Manager';
  Application.CreateForm(TFrmLicenseManagerMain, FrmLicenseManagerMain);
  Application.Run;
end.
