unit LicenseManagerMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.UITypes,
  System.Generics.Collections, System.DateUtils,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls,
  Vcl.ExtCtrls,
  uLicenseRecordStore;

type
  TFrmLicenseManagerMain = class(TForm)
    pnlTop: TPanel;
    lblTitle: TLabel;
    lblHint: TLabel;
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
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnCreateClick(Sender: TObject);
    procedure lvLicensesSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure chkLifetimeClick(Sender: TObject);
    procedure btnPresetClick(Sender: TObject);
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
  uLicenseCodec,
  uLicenseCodecV5,
  uLicenseOnlineTime,
  uLicenseEcdsa,
  uLicenseEcdsaSign;

procedure TFrmLicenseManagerMain.FormCreate(Sender: TObject);
begin
  FRecords := TObjectList<TLicenseEntry>.Create(True);
  TLicenseRecordStore.LoadInto(FRecords);
  dtpExpiry.Date := IncMonth(Date, 12);
  dtpExpiry.Time := EncodeTime(23, 59, 59, 0);
  chkLifetime.Checked := False;
  chkActive.Checked := True;
  UpdateExpiryControls;
  RefreshList;
  lblHint.Caption := Format(
    'Max username %d chars. Keys are %d chars (8x4). Internet required to create keys (online UTC). App verifies online too.',
    [LicenseMaxUsernameLen, LicenseKeyChars]);
  SetStatus(Format('Loaded %d license(s). Data: %s', [FRecords.Count, TLicenseRecordStore.DataFilePath]), True);
end;

procedure TFrmLicenseManagerMain.FormDestroy(Sender: TObject);
begin
  FRecords.Free;
end;

procedure TFrmLicenseManagerMain.SetStatus(const Msg: string; Ok: Boolean);
begin
  if Ok then
    lblTitle.Caption := 'License Manager — ' + Msg
  else
    lblTitle.Caption := 'License Manager — Error: ' + Msg;
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
var
  Utc, LocalNow: TDateTime;
  Err: string;
begin
  if not TryFetchUtcNow(Utc, Err) then
  begin
    SetStatus(Err, False);
    Exit;
  end;
  LocalNow := TTimeZone.Local.ToLocalTime(Utc);
  chkLifetime.Checked := False;
  UpdateExpiryControls;
  dtpExpiry.Date := IncMonth(DateOf(LocalNow), Months);
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
  Utc: TDateTime;
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

  if not TryFetchUtcNow(Utc, Err) then
  begin
    SetStatus(Err, False);
    Exit;
  end;

  HadExisting := FindByUsername(UserNorm) <> nil;
  RemoveAllByUsername(UserNorm);

  try
    PayloadBytes := LicenseCodecBuildPayloadV5(UserNorm, dtpExpiry.Date, Utc,
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

  if not LicenseCodecTryValidate(Key, UserNorm, Utc, Err) then
  begin
    SetStatus('Generated key failed validation: ' + Err, False);
    Exit;
  end;

  if not LicenseCodecTryDecodePayload(Key, Payload, Err) then
  begin
    SetStatus('Could not decode generated key: ' + Err, False);
    Exit;
  end;

  Entry := TLicenseEntry.Create;
  Entry.Username := UserNorm;
  Entry.LicenseKey := Key;
  Entry.Registered := TTimeZone.Local.ToLocalTime(Utc);
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

end.
