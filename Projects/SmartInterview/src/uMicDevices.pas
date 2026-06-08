unit uMicDevices;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TMicDevice = record
    Id: string;
    Name: string;
    IsDefault: Boolean;
  end;

function MicDevicesList: TArray<TMicDevice>;
function MicDevicesGetSelectedId: string;
procedure MicDevicesSetSelectedId(const Id: string);
function MicDevicesGetSelectedName: string;

implementation

uses
  Winapi.Windows,
  Winapi.ActiveX,
  uWasapiCapture,
  uRegistryStore;

var
  GSelectedId: string = '';

function MicDevicesList: TArray<TMicDevice>;
var
  List: TList<TMicDevice>;
  Names, Ids: TArray<string>;
  I: Integer;
  D: TMicDevice;
begin
  List := TList<TMicDevice>.Create;
  try
    D.Id := '';
    D.Name := 'System default';
    D.IsDefault := True;
    List.Add(D);
    if WasapiEnumerateCaptureDevices(Names, Ids) then
    begin
      for I := 0 to High(Names) do
      begin
        D.Id := Ids[I];
        D.Name := Names[I];
        D.IsDefault := False;
        List.Add(D);
      end;
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function MicDevicesGetSelectedId: string;
begin
  if GSelectedId = '' then
    GSelectedId := RegistryGetString('MicDeviceId');
  Result := GSelectedId;
end;

procedure MicDevicesSetSelectedId(const Id: string);
begin
  GSelectedId := Id;
  RegistrySetString('MicDeviceId', Id);
end;

function MicDevicesGetSelectedName: string;
var
  D: TMicDevice;
  SelId: string;
begin
  Result := 'System default';
  SelId := MicDevicesGetSelectedId;
  for D in MicDevicesList do
    if D.Id = SelId then
      Exit(D.Name);
end;

end.
