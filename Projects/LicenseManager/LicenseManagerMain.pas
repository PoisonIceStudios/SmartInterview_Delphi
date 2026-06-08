unit LicenseManagerMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.UITypes,
  System.Generics.Collections, System.DateUtils,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls,
  Vcl.ExtCtrls, Vcl.Menus,
  uLicenseRecordStore;

type
  TFrmLicenseManagerMain = class(TForm)
    pnlTop: TPanel;
    lblUsername: TLabel;
    lblExpiry: TLabel;
    lblPresets: TLabel;
    edtUsername: TEdit;
    dtpExpiry: TDateTimePicker;
    chkLifetime: TCheckBox;
    chkActive: TCheckBox;
    btnCreate: TButton;
    btn1Month: TButton;
    btn3Month: TButton;
    btn6Month: TButton;
    btn12Month: TButton;
    lvLicenses: TListView;
    pmLicenses: TPopupMenu;
    miCopyKey: TMenuItem;
    miDeleteUser: TMenuItem;
    mmMain: TMainMenu;
    miKeys: TMenuItem;
    miGenKeys: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnCreateClick(Sender: TObject);
    procedure lvLicensesSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure chkLifetimeClick(Sender: TObject);
    procedure btnPresetClick(Sender: TObject);
    procedure lvLicensesMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pmLicensesPopup(Sender: TObject);
    procedure miCopyKeyClick(Sender: TObject);
    procedure miDeleteUserClick(Sender: TObject);
    procedure miGenKeysClick(Sender: TObject);
  private
    FRecords: TObjectList<TLicenseEntry>;
    procedure RefreshList;
    procedure SetStatus(const Msg: string; Ok: Boolean);
    procedure UpdateExpiryControls;
    function FindByUsername(const Username: string): TLicenseEntry;
    procedure RemoveAllByUsername(const Username: string);
    procedure ApplyMonthPreset(Months: Integer);
  public
  end;

var
  FrmLicenseManagerMain: TFrmLicenseManagerMain;

implementation

{$R *.dfm}

uses
  Vcl.Clipbrd,
  uLicenseCodec,
  uLicenseCodecV5,
  uLicenseEcdsa,
  uLicenseEcdsaSign,
  uLicenseKeyGen;

procedure TFrmLicenseManagerMain.FormCreate(Sender: TObject);
begin
  FRecords := TObjectList<TLicenseEntry>.Create(True);
  TLicenseRecordStore.LoadInto(FRecords);
  dtpExpiry.Date := Date;
  dtpExpiry.Time := EncodeTime(23, 59, 59, 0);
  chkLifetime.Checked := False;
  chkActive.Checked := True;
  UpdateExpiryControls;
  RefreshList;
  SetStatus(Format('Loaded %d license(s). Data: %s', [FRecords.Count, TLicenseRecordStore.DataFilePath]), True);
end;

procedure TFrmLicenseManagerMain.FormDestroy(Sender: TObject);
begin
  FRecords.Free;
end;

procedure TFrmLicenseManagerMain.SetStatus(const Msg: string; Ok: Boolean);
begin
  if not Ok then
  MessageDlg(Msg, mtError, [mbOK], 0);
end;

procedure TFrmLicenseManagerMain.UpdateExpiryControls;
begin
  dtpExpiry.Enabled := not chkLifetime.Checked;
  btn1Month.Enabled := not chkLifetime.Checked;
  btn3Month.Enabled := not chkLifetime.Checked;
  btn6Month.Enabled := not chkLifetime.Checked;
  btn12Month.Enabled := not chkLifetime.Checked;
end;

procedure TFrmLicenseManagerMain.chkLifetimeClick(Sender: TObject);
begin
  UpdateExpiryControls;
end;

procedure TFrmLicenseManagerMain.ApplyMonthPreset(Months: Integer);
begin
  chkLifetime.Checked := False;
  UpdateExpiryControls;
  dtpExpiry.Date := IncMonth(Date, Months);
end;

procedure TFrmLicenseManagerMain.btnPresetClick(Sender: TObject);
begin
  if Sender = btn1Month then
    ApplyMonthPreset(1)
  else if Sender = btn3Month then
    ApplyMonthPreset(3)
  else if Sender = btn6Month then
    ApplyMonthPreset(6)
  else if Sender = btn12Month then
    ApplyMonthPreset(12);
end;

function TFrmLicenseManagerMain.FindByUsername(const Username: string): TLicenseEntry;
var
  Norm, EntryNorm: string;
  Entry: TLicenseEntry;
begin
  Result := nil;
  Norm := LicenseNormalizeUsername(Username);
  for Entry in FRecords do
  begin
    EntryNorm := LicenseNormalizeUsername(Entry.Username);
    if EntryNorm = Norm then
      Exit(Entry);
  end;
end;

procedure TFrmLicenseManagerMain.RemoveAllByUsername(const Username: string);
var
  Norm, EntryNorm: string;
  I: Integer;
begin
  Norm := LicenseNormalizeUsername(Username);
  for I := FRecords.Count - 1 downto 0 do
  begin
    EntryNorm := LicenseNormalizeUsername(FRecords[I].Username);
    if EntryNorm = Norm then
      FRecords.Delete(I);
  end;
end;

procedure TFrmLicenseManagerMain.RefreshList;
var
  Entry: TLicenseEntry;
  Item: TListItem;
begin
  lvLicenses.Items.BeginUpdate;
  try
    lvLicenses.Items.Clear;
    for Entry in FRecords do
    begin
      Item := lvLicenses.Items.Add;
      Item.Caption := Entry.Username;
      Item.SubItems.Add(Entry.LicenseKey);
      Item.SubItems.Add(FormatDateTime('yyyy-mm-dd hh:nn', Entry.Registered));
      Item.SubItems.Add(Entry.ExpiryLabel);
      if Entry.Active then
        Item.SubItems.Add('Yes')
      else
        Item.SubItems.Add('No');
      Item.Data := Entry;
    end;
  finally
    lvLicenses.Items.EndUpdate;
  end;
end;

procedure TFrmLicenseManagerMain.btnCreateClick(Sender: TObject);
var
  UserNorm, Key, Err: string;
  Entry: TLicenseEntry;
  HadExisting: Boolean;
  Payload: TLicensePayload;
  PayloadBytes, Hash, Sig: TBytes;
begin
  UserNorm := LicenseNormalizeUsername(edtUsername.Text);
  if UserNorm = '' then
  begin
    SetStatus('Enter a forum username.', False);
    edtUsername.SetFocus;
    Exit;
  end;

  if Length(UserNorm) > LicenseMaxUsernameLen then
  begin
    SetStatus(Format('Username too long (max %d characters).', [LicenseMaxUsernameLen]), False);
    edtUsername.SetFocus;
    Exit;
  end;


  HadExisting := FindByUsername(UserNorm) <> nil;
  RemoveAllByUsername(UserNorm);

  try
    PayloadBytes := LicenseCodecBuildPayloadV5(UserNorm, dtpExpiry.Date,
      chkLifetime.Checked, chkActive.Checked);
    Hash := LicenseEcdsaHash(PayloadBytes);
    Sig := LicenseEcdsaSignHash(Hash);
    Key := LicenseCodecFormatSignedKeyV5(PayloadBytes, Sig);
  except
    on E: Exception do
    begin
      SetStatus(E.Message, False);
      Exit;
    end;
  end;

  { Admin tool: verify signature/format only — no expiry, username, or active checks. }
  if not LicenseCodecTryDecodePayload(Key, Payload, Err) then
  begin
    SetStatus('Generated key could not be verified: ' + Err, False);
    Exit;
  end;

  Entry := TLicenseEntry.Create;
  Entry.Username := UserNorm;
  Entry.LicenseKey := Key;
  Entry.Registered := Now;
  Entry.ExpiryLabel := LicenseCodecFormatExpiry(Payload);
  Entry.Lifetime := Payload.Lifetime;
  Entry.ExpiryDate := LicenseCodecExpiryToDate(Payload.ExpiryUnixDay);
  Entry.Active := Payload.Active;
  FRecords.Add(Entry);

  try
    TLicenseRecordStore.SaveFrom(FRecords);
  except
    on E: Exception do
    begin
      FRecords.Remove(Entry);
      SetStatus('Could not save licenses.json: ' + E.Message, False);
      Exit;
    end;
  end;

  RefreshList;
  edtUsername.Text := '';
  if HadExisting then
    SetStatus(Format('Replaced license for "%s" (%s).', [UserNorm, Entry.ExpiryLabel]), True)
  else
    SetStatus(Format('Created license for "%s" (%s).', [UserNorm, Entry.ExpiryLabel]), True);
end;

procedure TFrmLicenseManagerMain.lvLicensesSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
var
  Entry: TLicenseEntry;
begin
  if not Selected or (Item = nil) then
    Exit;

  edtUsername.Text := Item.Caption;
  if Item.Data = nil then
    Exit;

  Entry := TLicenseEntry(Item.Data);
  chkActive.Checked := Entry.Active;
  chkLifetime.Checked := Entry.Lifetime;
  if Entry.Lifetime then
    dtpExpiry.Date := IncMonth(Date, 12)
  else if Entry.ExpiryDate > 0 then
    dtpExpiry.Date := Entry.ExpiryDate
  else
    dtpExpiry.Date := IncMonth(Date, 12);
  UpdateExpiryControls;
end;

procedure TFrmLicenseManagerMain.lvLicensesMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Item: TListItem;
begin
  if Button = mbRight then
  begin
    Item := lvLicenses.GetItemAt(X, Y);
    if Item <> nil then
      Item.Selected := True;
  end;
end;

procedure TFrmLicenseManagerMain.pmLicensesPopup(Sender: TObject);
var
  HasSel: Boolean;
begin
  HasSel := (lvLicenses.Selected <> nil) and (lvLicenses.Selected.Data <> nil);
  miCopyKey.Enabled := HasSel;
  miDeleteUser.Enabled := HasSel;
end;

procedure TFrmLicenseManagerMain.miCopyKeyClick(Sender: TObject);
var
  Entry: TLicenseEntry;
begin
  if (lvLicenses.Selected = nil) or (lvLicenses.Selected.Data = nil) then
    Exit;
  Entry := TLicenseEntry(lvLicenses.Selected.Data);
  Clipboard.AsText := Entry.LicenseKey;
  SetStatus(Format('Key copied for "%s".', [Entry.Username]), True);
end;

procedure TFrmLicenseManagerMain.miDeleteUserClick(Sender: TObject);
var
  Entry: TLicenseEntry;
  UserName: string;
begin
  if (lvLicenses.Selected = nil) or (lvLicenses.Selected.Data = nil) then
    Exit;
  Entry := TLicenseEntry(lvLicenses.Selected.Data);
  UserName := Entry.Username;

  if MessageDlg(Format('Delete the license for "%s"?', [UserName]),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  RemoveAllByUsername(UserName);
  try
    TLicenseRecordStore.SaveFrom(FRecords);
  except
    on E: Exception do
    begin
      SetStatus('Could not save licenses.json: ' + E.Message, False);
      Exit;
    end;
  end;

  RefreshList;
  SetStatus(Format('Deleted license for "%s".', [UserName]), True);
end;

procedure TFrmLicenseManagerMain.miGenKeysClick(Sender: TObject);
var
  Hex: string;
begin
  if LicenseSigningKeyExists then
    if MessageDlg('A signing key already exists. Generating a new one will INVALIDATE all ' +
      'existing licenses and require rebuilding SmartInterview and the Engine. Continue?',
      mtWarning, [mbYes, mbNo], 0) <> mrYes then
      Exit;

  Clipboard.AsText := Hex;
  MessageDlg('New signing keys created.' + sLineBreak + sLineBreak +
    'Public key (copied to clipboard):' + sLineBreak + Hex + sLineBreak + sLineBreak +
    'Update the embedded public key in the application sources, then rebuild.',
    mtInformation, [mbOK], 0);
  SetStatus('New signing keys generated.', True);
end;

end.
