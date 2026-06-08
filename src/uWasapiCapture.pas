unit uWasapiCapture;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs;

const
  WASAPI_TARGET_RATE = 16000;

function WasapiEnumerateCaptureDevices(out Names, Ids: TArray<string>): Boolean;
function WasapiGetDefaultCaptureId: string;
function WasapiGetDeviceId(const DeviceId: string): string;

type
  TWasapiSampleEvent = procedure(const Samples: TArray<Single>) of object;

  TWasapiLoopbackCapture = class
  private
    FActive: Boolean;
    FCaptureThread: TThread;
    FOnSamples: TWasapiSampleEvent;
    FSampleRate: Integer;
    FChannels: Integer;
    FReadyEvent: TEvent;
    FCaptureOk: Boolean;
    procedure CaptureLoop;
  public
    constructor Create;
    destructor Destroy; override;
    function Start: Boolean;
    procedure Stop;
    property OnSamples: TWasapiSampleEvent read FOnSamples write FOnSamples;
    property Active: Boolean read FActive;
    property SampleRate: Integer read FSampleRate;
    property Channels: Integer read FChannels;
  end;

  TWasapiMicCapture = class
  private
    FDeviceId: string;
    FActive: Boolean;
    FCaptureThread: TThread;
    FOnSamples: TWasapiSampleEvent;
    FSampleRate: Integer;
    FChannels: Integer;
    FBytesPerSample: Integer;
    FIsFloat: Boolean;
    FReadyEvent: TEvent;
    FCaptureOk: Boolean;
    procedure CaptureLoop;
  public
    constructor Create(const ADeviceId: string = '');
    destructor Destroy; override;
    function Start: Boolean;
    procedure Stop;
    property OnSamples: TWasapiSampleEvent read FOnSamples write FOnSamples;
    property Active: Boolean read FActive;
  end;

implementation

uses
  Winapi.Windows,
  Winapi.ActiveX,
  Winapi.MMSystem,
  System.Generics.Collections,
  System.Math;

const
  CLSCTX_ALL = 23;
  eRender = 0;
  eCapture = 1;
  eConsole = 0;
  eCommunications = 2;
  AUDCLNT_SHAREMODE_SHARED = 0;
  AUDCLNT_STREAMFLAGS_LOOPBACK = $00020000;
  AUDCLNT_STREAMFLAGS_EVENTCALLBACK = $00040000;
  REFTIMES_PER_SEC = 10000000;
  WASAPI_BUFFER_DURATION = REFTIMES_PER_SEC div 5; // 200 ms — lower capture latency

type
  TPropertyKey = record
    fmtid: TGUID;
    pid: DWORD;
  end;

  IMMDevice = interface(IUnknown)
    ['{D666063F-1587-4E43-81F1-B5484F9924F1}']
    function Activate(const iid: TGUID; dwClsCtx: DWORD; pActivationParams: Pointer;
      out ppInterface): HResult; stdcall;
    function OpenPropertyStore(stgmAccess: DWORD; out ppProperties): HResult; stdcall;
    function GetId(out ppstrId: PWideChar): HResult; stdcall;
    function GetState(out pdwState: DWORD): HResult; stdcall;
  end;

  IMMDeviceEnumerator = interface(IUnknown)
    ['{A95664D2-9614-4F35-A746-DE8DB63617E6}']
    function EnumAudioEndpoints(dataFlow, dwStateMask: DWORD; out ppDevices): HResult; stdcall;
    function GetDefaultAudioEndpoint(dataFlow, role: DWORD; out ppEndpoint): HResult; stdcall;
    function GetDevice(pwstrId: PWideChar; out ppDevice): HResult; stdcall;
  end;

  IMMDeviceCollection = interface(IUnknown)
    ['{0BD7A1BE-7A1A-44DB-8397-CC5392387B5E}']
    function GetCount(out pcDevices: UINT): HResult; stdcall;
    function Item(nDevice: UINT; out ppDevice): HResult; stdcall;
  end;

  IAudioClient = interface(IUnknown)
    ['{1CB9AD4C-DBFA-4C32-B178-C2F568A703B2}']
    function Initialize(ShareMode, StreamFlags: DWORD; hnsBufferDuration, hnsPeriodicity: Int64;
      const pFormat: Pointer; AudioSessionGuid: PGUID): HResult; stdcall;
    function GetBufferSize(out NumBufferFrames: UINT): HResult; stdcall;
    function GetStreamLatency(out phnsLatency: Int64): HResult; stdcall;
    function GetCurrentPadding(out NumPaddingFrames: UINT): HResult; stdcall;
    function IsFormatSupported(ShareMode: DWORD; const pFormat: Pointer;
      out ppClosestMatch): HResult; stdcall;
    function GetMixFormat(out ppDeviceFormat): HResult; stdcall;
    function GetDevicePeriod(out phnsDefaultDevicePeriod, phnsMinimumDevicePeriod: Int64): HResult; stdcall;
    function Start: HResult; stdcall;
    function Stop: HResult; stdcall;
    function Reset: HResult; stdcall;
    function SetEventHandle(EventHandle: THandle): HResult; stdcall;
    function GetService(const riid: TGUID; out ppv): HResult; stdcall;
  end;

  IAudioCaptureClient = interface(IUnknown)
    ['{C8ADBD64-E71E-48A0-A4DE-185C395CD317}']
    function GetBuffer(out ppData: PByte; out NumFramesToRead: UINT;
      out dwFlags: DWORD; out pu64DevicePosition: UInt64; out pu64QPCPosition: UInt64): HResult; stdcall;
    function ReleaseBuffer(NumFramesRead: UINT): HResult; stdcall;
    function GetNextPacketSize(out NumFramesInNextPacket: UINT): HResult; stdcall;
  end;

  TPropVariant = record
    case Integer of
      0: (
        vt: Word;
        wReserved1: Word;
        wReserved2: Word;
        wReserved3: Word;
        val: Int64);
      1: (
        vt2: Word;
        w1, w2, w3: Word;
        pwszVal: PWideChar);
  end;

  IPropertyStore = interface(IUnknown)
    ['{886D8EEB-8CF2-4446-8D02-CDBAE1AEFFB9}']
    function GetCount(out cProps: DWORD): HResult; stdcall;
    function GetAt(iProp: DWORD; out pkey: TPropertyKey): HResult; stdcall;
    function GetValue(const key: TPropertyKey; out pv: TPropVariant): HResult; stdcall;
    function SetValue(const key: TPropertyKey; const propvar: TPropVariant): HResult; stdcall;
    function Commit: HResult; stdcall;
  end;

  TWaveFormatEx = record
    wFormatTag: Word;
    nChannels: Word;
    nSamplesPerSec: DWORD;
    nAvgBytesPerSec: DWORD;
    nBlockAlign: Word;
    wBitsPerSample: Word;
    cbSize: Word;
  end;
  PWaveFormatEx = ^TWaveFormatEx;

const
  WAVE_FORMAT_IEEE_FLOAT = $0003;
  WAVE_FORMAT_PCM = 1;
  DEVICE_STATE_ACTIVE = 1;
  STGM_READ = $00000000;
  VT_LPWSTR = 31;
  CLSID_MMDeviceEnumerator: TGUID = '{BCDE0395-E52F-467C-8E3D-C4579291692E}';
  IID_IMMDeviceEnumerator: TGUID = '{A95664D2-9614-4F35-A746-DE8DB63617E6}';
  IID_IAudioClient: TGUID = '{1CB9AD4C-DBFA-4C32-B178-C2F568A703B2}';
  IID_IAudioCaptureClient: TGUID = '{C8ADBD64-E71E-48A0-A4DE-185C395CD317}';
  PKEY_Device_FriendlyName: TPropertyKey =
    (fmtid: (D1: $A45C254E; D2: $DF1C; D3: $4EFD; D4: ($80, $20, $67, $D1, $46, $A8, $50, $E0)); pid: 14);

function CreateDeviceEnumerator(out Enumerator: IMMDeviceEnumerator): Boolean;
var
  Unk: IUnknown;
begin
  Result := Succeeded(CoCreateInstance(CLSID_MMDeviceEnumerator, nil, CLSCTX_ALL,
    IID_IMMDeviceEnumerator, Unk)) and Supports(Unk, IMMDeviceEnumerator, Enumerator);
end;

function GetDeviceFriendlyName(const Dev: IMMDevice): string;
var
  Store: IPropertyStore;
  PropValue: TPropVariant;
begin
  Result := '';
  if Failed(Dev.OpenPropertyStore(STGM_READ, Store)) then
    Exit;
  FillChar(PropValue, SizeOf(PropValue), 0);
  if Failed(Store.GetValue(PKEY_Device_FriendlyName, PropValue)) then
    Exit;
  if PropValue.vt = VT_LPWSTR then
  begin
    if PropValue.pwszVal <> nil then
      Result := string(PropValue.pwszVal);
    CoTaskMemFree(PropValue.pwszVal);
  end;
end;

function ReadSample(const Buffer: PByte; Offset: Integer; BytesPerSample: Integer;
  IsFloat: Boolean): Single;
var
  I16: SmallInt;
  I32: Integer;
begin
  if IsFloat then
    Move(Buffer[Offset], Result, 4)
  else if BytesPerSample = 2 then
  begin
    Move(Buffer[Offset], I16, 2);
    Result := I16 / 32768.0;
  end
  else if BytesPerSample = 4 then
  begin
    Move(Buffer[Offset], I32, 4);
    Result := I32 / 2147483648.0;
  end
  else
    Result := 0;
end;

procedure ResampleTo16k(const Mono: TArray<Single>; SampleRate: Integer;
  var Pos: Double; var Last: Single; out Output: TArray<Single>);
var
  Ratio: Double;
  OutList: TList<Single>;
  Idx: Integer;
  Frac, A, B: Double;
  P: Double;
begin
  OutList := TList<Single>.Create;
  try
    Ratio := SampleRate / WASAPI_TARGET_RATE;
    P := Pos;
    while P < Length(Mono) do
    begin
      Idx := Floor(P);
      Frac := P - Idx;
      if Idx = 0 then
        A := Last
      else
        A := Mono[Idx - 1];
      B := Mono[Idx];
      OutList.Add(Single(A + (B - A) * Frac));
      P := P + Ratio;
    end;
    Pos := P - Length(Mono);
    if Length(Mono) > 0 then
      Last := Mono[High(Mono)];
    Output := OutList.ToArray;
  finally
    OutList.Free;
  end;
end;

function WasapiEnumerateCaptureDevices(out Names, Ids: TArray<string>): Boolean;
var
  Enum: IMMDeviceEnumerator;
  Col: IMMDeviceCollection;
  Count, I: UINT;
  Dev: IMMDevice;
  IdPtr: PWideChar;
  NameList, IdList: TList<string>;
  FriendlyName: string;
begin
  NameList := TList<string>.Create;
  IdList := TList<string>.Create;
  try
    Result := False;
    if not CreateDeviceEnumerator(Enum) then
      Exit;
    if Failed(Enum.EnumAudioEndpoints(eCapture, DEVICE_STATE_ACTIVE, Col)) then
      Exit;
    if Failed(Col.GetCount(Count)) then
      Exit;
    for I := 0 to Count - 1 do
    begin
      if Failed(Col.Item(I, Dev)) then
        Continue;
      if Succeeded(Dev.GetId(IdPtr)) then
      begin
        IdList.Add(string(IdPtr));
        CoTaskMemFree(IdPtr);
        FriendlyName := Trim(GetDeviceFriendlyName(Dev));
        if FriendlyName.IsEmpty then
          FriendlyName := 'Microphone ' + IntToStr(I + 1);
        NameList.Add(FriendlyName);
      end;
    end;
    Names := NameList.ToArray;
    Ids := IdList.ToArray;
    Result := True;
  finally
    IdList.Free;
    NameList.Free;
  end;
end;

function WasapiGetDefaultCaptureId: string;
var
  Enum: IMMDeviceEnumerator;
  Dev: IMMDevice;
  IdPtr: PWideChar;
begin
  Result := '';
  if not CreateDeviceEnumerator(Enum) then
    Exit;
  if Failed(Enum.GetDefaultAudioEndpoint(eCapture, eCommunications, Dev)) then
    Exit;
  if Succeeded(Dev.GetId(IdPtr)) then
  begin
    Result := string(IdPtr);
    CoTaskMemFree(IdPtr);
  end;
end;

function WasapiGetDeviceId(const DeviceId: string): string;
begin
  if DeviceId.IsEmpty then
    Result := WasapiGetDefaultCaptureId
  else
    Result := DeviceId;
end;

{ TWasapiLoopbackCapture }

constructor TWasapiLoopbackCapture.Create;
begin
  inherited;
  FReadyEvent := nil;
end;

destructor TWasapiLoopbackCapture.Destroy;
begin
  Stop;
  FreeAndNil(FReadyEvent);
  inherited;
end;

function TWasapiLoopbackCapture.Start: Boolean;
begin
  Result := False;
  if FActive then
    Exit(True);
  FreeAndNil(FReadyEvent);
  FReadyEvent := TEvent.Create(nil, True, False, '');
  FCaptureOk := False;
  FActive := True;
  FCaptureThread := TThread.CreateAnonymousThread(
    procedure
    begin
      CaptureLoop;
    end);
  FCaptureThread.FreeOnTerminate := False;
  FCaptureThread.Start;
  if FReadyEvent.WaitFor(4000) <> wrSignaled then
  begin
    Stop;
    Exit;
  end;
  Result := FCaptureOk;
  if not Result then
    Stop;
end;

procedure TWasapiLoopbackCapture.Stop;
begin
  FActive := False;
  if FCaptureThread <> nil then
  begin
    FCaptureThread.Terminate;
    FCaptureThread.WaitFor;
    FreeAndNil(FCaptureThread);
  end;
end;

procedure TWasapiLoopbackCapture.CaptureLoop;
var
  Enum: IMMDeviceEnumerator;
  Dev: IMMDevice;
  Client: IAudioClient;
  Capture: IAudioCaptureClient;
  Format: PWaveFormatEx;
  EventHandle: THandle;
  BufferSize, PacketLength, Flags, NumFrames: UINT;
  Data: PByte;
  ResamplePos: Double;
  LastSample: Single;
  Mono: TArray<Single>;
  OutChunk: TArray<Single>;
  I, C, FrameStride, Offset: Integer;
  DevPos, QpcPos: UInt64;

  procedure SignalReady(Ok: Boolean);
  begin
    FCaptureOk := Ok;
    if FReadyEvent <> nil then
      FReadyEvent.SetEvent;
  end;

begin
  CoInitialize(nil);
  try
    if not CreateDeviceEnumerator(Enum) then
    begin
      SignalReady(False);
      Exit;
    end;
    if Failed(Enum.GetDefaultAudioEndpoint(eRender, eConsole, Dev)) then
    begin
      SignalReady(False);
      Exit;
    end;
    if Failed(Dev.Activate(IID_IAudioClient, CLSCTX_ALL, nil, Client)) then
    begin
      SignalReady(False);
      Exit;
    end;
    if Failed(Client.GetMixFormat(Format)) then
    begin
      SignalReady(False);
      Exit;
    end;
    FSampleRate := Format.nSamplesPerSec;
    FChannels := Format.nChannels;
    EventHandle := CreateEvent(nil, False, False, nil);
    if Failed(Client.Initialize(AUDCLNT_SHAREMODE_SHARED,
      AUDCLNT_STREAMFLAGS_LOOPBACK or AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
      WASAPI_BUFFER_DURATION, 0, Format, nil)) then
    begin
      CoTaskMemFree(Format);
      SignalReady(False);
      Exit;
    end;
    if Failed(Client.SetEventHandle(EventHandle)) then
    begin
      CoTaskMemFree(Format);
      CloseHandle(EventHandle);
      SignalReady(False);
      Exit;
    end;
    if Failed(Client.GetService(IID_IAudioCaptureClient, Capture)) then
    begin
      CoTaskMemFree(Format);
      CloseHandle(EventHandle);
      SignalReady(False);
      Exit;
    end;
    if Failed(Client.Start) then
    begin
      CoTaskMemFree(Format);
      CloseHandle(EventHandle);
      SignalReady(False);
      Exit;
    end;
    SignalReady(True);
    ResamplePos := 0;
    LastSample := 0;
    FrameStride := (Format.wBitsPerSample div 8) * Format.nChannels;
    while FActive do
    begin
      WaitForSingleObject(EventHandle, 200);
      while FActive do
      begin
        if Failed(Capture.GetNextPacketSize(PacketLength)) or (PacketLength = 0) then
          Break;
        if Failed(Capture.GetBuffer(Data, NumFrames, Flags, DevPos, QpcPos)) then
          Break;
        try
          if (Flags and 1) = 0 then
          begin
            SetLength(Mono, NumFrames);
            Offset := 0;
            for I := 0 to NumFrames - 1 do
            begin
              Mono[I] := 0;
              for C := 0 to FChannels - 1 do
              begin
                Mono[I] := Mono[I] + ReadSample(Data, Offset, 4, True);
                Inc(Offset, 4);
              end;
              Mono[I] := Mono[I] / FChannels;
            end;
            ResampleTo16k(Mono, FSampleRate, ResamplePos, LastSample, OutChunk);
            if (Length(OutChunk) > 0) and Assigned(FOnSamples) then
              FOnSamples(OutChunk);
          end;
        finally
          Capture.ReleaseBuffer(NumFrames);
        end;
      end;
    end;
    Client.Stop;
    CloseHandle(EventHandle);
    CoTaskMemFree(Format);
  finally
    CoUninitialize;
  end;
end;

{ TWasapiMicCapture }

constructor TWasapiMicCapture.Create(const ADeviceId: string);
begin
  inherited Create;
  FDeviceId := ADeviceId;
  FReadyEvent := nil;
end;

destructor TWasapiMicCapture.Destroy;
begin
  Stop;
  FreeAndNil(FReadyEvent);
  inherited;
end;

function TWasapiMicCapture.Start: Boolean;
begin
  Result := False;
  if FActive then
    Exit(True);
  FreeAndNil(FReadyEvent);
  FReadyEvent := TEvent.Create(nil, True, False, '');
  FCaptureOk := False;
  FActive := True;
  FCaptureThread := TThread.CreateAnonymousThread(CaptureLoop);
  FCaptureThread.FreeOnTerminate := False;
  FCaptureThread.Start;
  if FReadyEvent.WaitFor(4000) <> wrSignaled then
  begin
    Stop;
    Exit;
  end;
  Result := FCaptureOk;
  if not Result then
    Stop;
end;

procedure TWasapiMicCapture.Stop;
begin
  FActive := False;
  if FCaptureThread <> nil then
  begin
    FCaptureThread.Terminate;
    FCaptureThread.WaitFor;
    FreeAndNil(FCaptureThread);
  end;
end;

procedure TWasapiMicCapture.CaptureLoop;
var
  Enum: IMMDeviceEnumerator;
  Dev: IMMDevice;
  Client: IAudioClient;
  Capture: IAudioCaptureClient;
  Format: PWaveFormatEx;
  EventHandle: THandle;
  PacketLength, Flags, NumFrames: UINT;
  Data: PByte;
  ResamplePos: Double;
  LastSample: Single;
  Mono, OutChunk: TArray<Single>;
  I, C, Offset: Integer;
  DevId: string;
  DevPos, QpcPos: UInt64;

  procedure SignalReady(Ok: Boolean);
  begin
    FCaptureOk := Ok;
    if FReadyEvent <> nil then
      FReadyEvent.SetEvent;
  end;

begin
  CoInitialize(nil);
  try
    if not CreateDeviceEnumerator(Enum) then
    begin
      SignalReady(False);
      Exit;
    end;
    DevId := WasapiGetDeviceId(FDeviceId);
    if DevId.IsEmpty then
    begin
      SignalReady(False);
      Exit;
    end;
    if Failed(Enum.GetDevice(PWideChar(DevId), Dev)) then
    begin
      SignalReady(False);
      Exit;
    end;
    if Failed(Dev.Activate(IID_IAudioClient, CLSCTX_ALL, nil, Client)) then
    begin
      SignalReady(False);
      Exit;
    end;
    if Failed(Client.GetMixFormat(Format)) then
    begin
      SignalReady(False);
      Exit;
    end;
    FSampleRate := Format.nSamplesPerSec;
    FChannels := Format.nChannels;
    FBytesPerSample := Format.wBitsPerSample div 8;
    FIsFloat := Format.wFormatTag = WAVE_FORMAT_IEEE_FLOAT;
    EventHandle := CreateEvent(nil, False, False, nil);
    if Failed(Client.Initialize(AUDCLNT_SHAREMODE_SHARED,
      AUDCLNT_STREAMFLAGS_EVENTCALLBACK, WASAPI_BUFFER_DURATION, 0, Format, nil)) then
    begin
      CoTaskMemFree(Format);
      SignalReady(False);
      Exit;
    end;
    if Failed(Client.SetEventHandle(EventHandle)) then
    begin
      CoTaskMemFree(Format);
      CloseHandle(EventHandle);
      SignalReady(False);
      Exit;
    end;
    if Failed(Client.GetService(IID_IAudioCaptureClient, Capture)) then
    begin
      CoTaskMemFree(Format);
      CloseHandle(EventHandle);
      SignalReady(False);
      Exit;
    end;
    if Failed(Client.Start) then
    begin
      CoTaskMemFree(Format);
      CloseHandle(EventHandle);
      SignalReady(False);
      Exit;
    end;
    SignalReady(True);
    ResamplePos := 0;
    LastSample := 0;
    while FActive do
    begin
      WaitForSingleObject(EventHandle, 200);
      while FActive do
      begin
        if Failed(Capture.GetNextPacketSize(PacketLength)) or (PacketLength = 0) then
          Break;
        if Failed(Capture.GetBuffer(Data, NumFrames, Flags, DevPos, QpcPos)) then
          Break;
        try
          if (Flags and 1) = 0 then
          begin
            SetLength(Mono, NumFrames);
            Offset := 0;
            for I := 0 to NumFrames - 1 do
            begin
              Mono[I] := 0;
              for C := 0 to FChannels - 1 do
              begin
                Mono[I] := Mono[I] + ReadSample(Data, Offset, FBytesPerSample, FIsFloat);
                Inc(Offset, FBytesPerSample);
              end;
              Mono[I] := Mono[I] / FChannels;
            end;
            ResampleTo16k(Mono, FSampleRate, ResamplePos, LastSample, OutChunk);
            if (Length(OutChunk) > 0) and Assigned(FOnSamples) then
              FOnSamples(OutChunk);
          end;
        finally
          Capture.ReleaseBuffer(NumFrames);
        end;
      end;
    end;
    Client.Stop;
    CloseHandle(EventHandle);
    CoTaskMemFree(Format);
  finally
    CoUninitialize;
  end;
end;

end.
