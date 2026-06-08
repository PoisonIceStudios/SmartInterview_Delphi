unit uDialogZOrder;

interface

uses
  Vcl.Forms;

{ Makes a dialog appear above the application main form. The main window is an
  always-on-top overlay (fsStayOnTop); a plain modal/modeless child would render
  *behind* it. Setting PopupParent keeps the dialog owned by (and above) the main
  form, and matching fsStayOnTop guarantees it stays above even when the main form
  is topmost. Call this right before Show / ShowModal. }
procedure PrepareDialogAboveMain(F: TCustomForm);

implementation

procedure PrepareDialogAboveMain(F: TCustomForm);
var
  Main: TForm;
  Dlg: TForm;
begin
  if F = nil then
    Exit;
  if not (F is TForm) then
    Exit;
  Dlg := TForm(F);
  Main := Application.MainForm;
  if (Main = nil) or (Main = Dlg) then
    Exit;

  Dlg.PopupMode := pmExplicit;
  Dlg.PopupParent := Main;
  // FormStyle is published on TForm only (protected on TCustomForm).
  if Main.FormStyle = fsStayOnTop then
    Dlg.FormStyle := fsStayOnTop
  else
    Dlg.FormStyle := fsNormal;
end;

end.
