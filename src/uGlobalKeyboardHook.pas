unit uGlobalKeyboardHook;

interface

uses
  System.SysUtils,
  Winapi.Windows;

type
  PKBDLLHOOKSTRUCT = ^KBDLLHOOKSTRUCT;
  KBDLLHOOKSTRUCT = record
    vkCode: DWORD;
    scanCode: DWORD;
    flags: DWORD;
    time: DWORD;
    dwExtraInfo: NativeUInt;
  end;

  TListeningKey = (lkCtrl = 0, lkShift = 1, lkAlt = 2);

  TGlobalKeyboardHook = class(TObject)
  private
    type
      TNotifyProc = procedure of object;
    const
      WH_KEYBOARD_LL = 13;
      WM_KEYDOWN = $0100;
      WM_KEYUP = $0101;
      WM_SYSKEYDOWN = $0104;
      WM_SYSKEYUP = $0105;
      VK_LCONTROL = $A2;
      VK_RCONTROL = $A3;
      VK_LSHIFT = $A0;
      VK_RSHIFT = $A1;
      VK_LALT = $A4;
      VK_RALT = $A5;
      VK_F3 = $72;
      VK_F7 = $76;
      VK_F8 = $77;
    var
      FHookId: HHOOK;
      FListeningKeyDown: Boolean;
      FListeningKey: TListeningKey;
      FOnListeningKeyPressed: TNotifyProc;
      FOnListeningKeyReleased: TNotifyProc;
      FOnToggleTopmostPressed: TNotifyProc;
      FOnOpacityDownPressed: TNotifyProc;
      FOnOpacityUpPressed: TNotifyProc;
      function IsListeningKey(Vk: Integer): Boolean;
      procedure HookCallback(Info: PKBDLLHOOKSTRUCT; Msg: Integer);
    public
      constructor Create;
      destructor Destroy; override;
      procedure Start;
      procedure SetListeningKey(const Key: TListeningKey);
      property OnListeningKeyPressed: TNotifyProc read FOnListeningKeyPressed write FOnListeningKeyPressed;
      property OnListeningKeyReleased: TNotifyProc read FOnListeningKeyReleased write FOnListeningKeyReleased;
      property OnToggleTopmostPressed: TNotifyProc read FOnToggleTopmostPressed write FOnToggleTopmostPressed;
      property OnOpacityDownPressed: TNotifyProc read FOnOpacityDownPressed write FOnOpacityDownPressed;
      property OnOpacityUpPressed: TNotifyProc read FOnOpacityUpPressed write FOnOpacityUpPressed;
  end;

function ListeningKeyLoadSaved: TListeningKey;
function ListeningKeyDisplayName(const Key: TListeningKey): string;
function ListeningKeyHoldHint(const Key: TListeningKey): string;

implementation

uses
  uRegistryStore;

var
  GHookInstance: TGlobalKeyboardHook = nil;

function LowLevelKeyboardProc(Code: Integer; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
begin
  if (GHookInstance <> nil) and (Code >= 0) then
    GHookInstance.HookCallback(PKBDLLHOOKSTRUCT(lParam), Integer(wParam));
  if (GHookInstance <> nil) and (GHookInstance.FHookId <> 0) then
    Result := CallNextHookEx(GHookInstance.FHookId, Code, wParam, lParam)
  else
    Result := CallNextHookEx(0, Code, wParam, lParam);
end;

function ListeningKeyLoadSaved: TListeningKey;
var
  Saved: string;
  Value: Integer;
begin
  Value := RegistryGetInt('ListeningKey', -1);
  if (Value >= Ord(Low(TListeningKey))) and (Value <= Ord(High(TListeningKey))) then
    Exit(TListeningKey(Value));
  Saved := RegistryGetString('ListeningKey');
  if TryStrToInt(Saved, Value) and (Value >= Ord(Low(TListeningKey))) and
    (Value <= Ord(High(TListeningKey))) then
    Exit(TListeningKey(Value));
  if SameText(Saved, 'Ctrl') then Exit(lkCtrl);
  if SameText(Saved, 'Shift') then Exit(lkShift);
  if SameText(Saved, 'Alt') then Exit(lkAlt);
  Result := lkCtrl;
end;

function ListeningKeyDisplayName(const Key: TListeningKey): string;
begin
  case Key of
    lkCtrl: Result := 'Ctrl';
    lkShift: Result := 'Shift';
    lkAlt: Result := 'Alt';
  else
    Result := IntToStr(Ord(Key));
  end;
end;

function ListeningKeyHoldHint(const Key: TListeningKey): string;
begin
  Result := 'Hold ' + ListeningKeyDisplayName(Key);
end;

constructor TGlobalKeyboardHook.Create;
begin
  inherited Create;
  FHookId := 0;
  FListeningKeyDown := False;
  FListeningKey := lkCtrl;
end;

destructor TGlobalKeyboardHook.Destroy;
begin
  if FHookId <> 0 then
  begin
    UnhookWindowsHookEx(FHookId);
    FHookId := 0;
  end;
  if GHookInstance = Self then
    GHookInstance := nil;
  inherited;
end;

procedure TGlobalKeyboardHook.SetListeningKey(const Key: TListeningKey);
begin
  FListeningKey := Key;
end;

procedure TGlobalKeyboardHook.Start;
begin
  if FHookId <> 0 then
    Exit;
  GHookInstance := Self;
  FHookId := SetWindowsHookEx(WH_KEYBOARD_LL, @LowLevelKeyboardProc,
    HInstance, 0);
  if FHookId = 0 then
    raise Exception.Create('Unable to install the keyboard hook.');
end;

function TGlobalKeyboardHook.IsListeningKey(Vk: Integer): Boolean;
begin
  case FListeningKey of
    lkCtrl: Result := (Vk = VK_LCONTROL) or (Vk = VK_RCONTROL);
    lkShift: Result := (Vk = VK_LSHIFT) or (Vk = VK_RSHIFT);
    lkAlt: Result := (Vk = VK_LALT) or (Vk = VK_RALT);
  else
    Result := False;
  end;
end;

procedure TGlobalKeyboardHook.HookCallback(Info: PKBDLLHOOKSTRUCT; Msg: Integer);
var
  IsDown, IsUp: Boolean;
begin
  IsDown := (Msg = WM_KEYDOWN) or (Msg = WM_SYSKEYDOWN);
  IsUp := (Msg = WM_KEYUP) or (Msg = WM_SYSKEYUP);

  if IsListeningKey(Info.vkCode) then
  begin
    if IsDown and not FListeningKeyDown then
    begin
      FListeningKeyDown := True;
      if Assigned(FOnListeningKeyPressed) then
        FOnListeningKeyPressed;
    end
    else if IsUp and FListeningKeyDown then
    begin
      FListeningKeyDown := False;
      if Assigned(FOnListeningKeyReleased) then
        FOnListeningKeyReleased;
    end;
  end
  else if IsDown then
  begin
    case Info.vkCode of
      VK_F3:
        if Assigned(FOnToggleTopmostPressed) then
          FOnToggleTopmostPressed;
      VK_F7:
        if Assigned(FOnOpacityDownPressed) then
          FOnOpacityDownPressed;
      VK_F8:
        if Assigned(FOnOpacityUpPressed) then
          FOnOpacityUpPressed;
    end;
  end;
end;

end.
