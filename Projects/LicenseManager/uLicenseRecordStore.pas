unit uLicenseRecordStore;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TLicenseEntry = class
  public
    Username: string;
    LicenseKey: string;
    Registered: TDateTime;
    ExpiryLabel: string;
    ExpiryDate: TDateTime;
    Lifetime: Boolean;
    Active: Boolean;
  end;

  TLicenseRecordStore = class
  public
    class function DataFilePath: string;
    class procedure LoadInto(List: TObjectList<TLicenseEntry>);
    class procedure SaveFrom(List: TObjectList<TLicenseEntry>);
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.DateUtils,
  uLicenseCodec;

class function TLicenseRecordStore.DataFilePath: string;
begin
  Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'licenses.json');
end;

function FindEntryIndexByUsername(List: TObjectList<TLicenseEntry>; const Username: string): Integer;
var
  I: Integer;
  Norm: string;
begin
  Result := -1;
  Norm := LicenseNormalizeUsername(Username);
  for I := 0 to List.Count - 1 do
    if LicenseNormalizeUsername(List[I].Username) = Norm then
      Exit(I);
end;

class procedure TLicenseRecordStore.LoadInto(List: TObjectList<TLicenseEntry>);
var
  Path, Text, RegStr, ExpStr: string;
  Root: TJSONValue;
  Arr: TJSONArray;
  Obj: TJSONObject;
  Entry: TLicenseEntry;
  I, Idx: Integer;
begin
  List.Clear;
  Path := DataFilePath;
  if not TFile.Exists(Path) then
    Exit;

  Text := TFile.ReadAllText(Path, TEncoding.UTF8);
  if Trim(Text) = '' then
    Exit;

  Root := TJSONObject.ParseJSONValue(Text);
  if Root = nil then
    Exit;
  try
    if not (Root is TJSONArray) then
      Exit;
    Arr := TJSONArray(Root);
    for I := 0 to Arr.Count - 1 do
    begin
      if not (Arr.Items[I] is TJSONObject) then
        Continue;
      Obj := TJSONObject(Arr.Items[I]);
      Entry := TLicenseEntry.Create;
      Entry.Username := LicenseNormalizeUsername(Obj.GetValue<string>('username', ''));
      Entry.LicenseKey := Obj.GetValue<string>('license', '');
      RegStr := Obj.GetValue<string>('registered', '');
      if (RegStr <> '') and not TryISO8601ToDate(RegStr, Entry.Registered, False) then
        Entry.Registered := Now
      else if RegStr = '' then
        Entry.Registered := Now;
      Entry.ExpiryLabel := Obj.GetValue<string>('expiry', 'Lifetime');
      Entry.Lifetime := Obj.GetValue<Boolean>('lifetime', SameText(Entry.ExpiryLabel, 'Lifetime'));
      ExpStr := Obj.GetValue<string>('expiryDate', '');
      Entry.ExpiryDate := 0;
      if ExpStr <> '' then
        TryISO8601ToDate(ExpStr, Entry.ExpiryDate, False);
      Entry.Active := Obj.GetValue<Boolean>('active', True);
      Idx := FindEntryIndexByUsername(List, Entry.Username);
      if Idx >= 0 then
      begin
        List[Idx].Free;
        List[Idx] := Entry;
      end
      else
        List.Add(Entry);
    end;
  finally
    Root.Free;
  end;
end;

class procedure TLicenseRecordStore.SaveFrom(List: TObjectList<TLicenseEntry>);
var
  Arr: TJSONArray;
  Obj: TJSONObject;
  Entry: TLicenseEntry;
  Path: string;
begin
  Arr := TJSONArray.Create;
  try
    for Entry in List do
    begin
      Obj := TJSONObject.Create;
      Obj.AddPair('username', LicenseNormalizeUsername(Entry.Username));
      Obj.AddPair('license', Entry.LicenseKey);
      Obj.AddPair('registered', DateToISO8601(Entry.Registered, False));
      Obj.AddPair('expiry', Entry.ExpiryLabel);
      Obj.AddPair('lifetime', TJSONBool.Create(Entry.Lifetime));
      if not Entry.Lifetime then
        Obj.AddPair('expiryDate', DateToISO8601(Entry.ExpiryDate, False));
      if Entry.Active then
        Obj.AddPair('active', TJSONTrue.Create)
      else
        Obj.AddPair('active', TJSONFalse.Create);
      Arr.AddElement(Obj);
    end;
    Path := DataFilePath;
    ForceDirectories(ExtractFilePath(Path));
    TFile.WriteAllText(Path, Arr.ToJSON, TEncoding.UTF8);
  finally
    Arr.Free;
  end;
end;

end.
