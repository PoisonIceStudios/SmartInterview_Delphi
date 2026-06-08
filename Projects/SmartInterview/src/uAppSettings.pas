unit uAppSettings;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  uRegistryStore,
  uVoiceSegmenter;

type
  TAnswerLength = (alShort = 0, alMedium = 1, alLong = 2);

  TResponseIntelligence = (riFast = 0, riBalanced = 1, riMax = 2);

  TTranscriptionIntelligence = (tiFast = 0, tiBalanced = 1, tiMax = 2);

function GetAnswerLength: TAnswerLength;
procedure SetAnswerLength(const Length: TAnswerLength);

function GetResponseIntelligence: TResponseIntelligence;
procedure SetResponseIntelligence(const Level: TResponseIntelligence);

function GetTranscriptionIntelligence: TTranscriptionIntelligence;
procedure SetTranscriptionIntelligence(const Level: TTranscriptionIntelligence);

function GetAnswerLengthOptions(const Length: TAnswerLength): TPair<Integer, string>;

procedure ApplyVadTo(Seg: TVoiceSegmenter);
procedure SaveVad(Seg: TVoiceSegmenter);
procedure SaveVadDefaults;

implementation

uses
  System.Classes,
  System.Math,
  Winapi.Windows,
  System.Win.Registry;

const
  GB = Int64(1024) * 1024 * 1024;

function GetMaxDedicatedVramBytes: Int64;
var
  Reg: TRegistry;
  SubKeys: TStringList;
  Sub: string;
  Val: Integer;
  Raw: Int64;
  Bytes: TBytes;
begin
  Result := 0;
  Reg := TRegistry.Create(KEY_READ);
  SubKeys := TStringList.Create;
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if not Reg.OpenKey(
      'SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}', False) then
      Exit;
    Reg.GetKeyNames(SubKeys);
    for Sub in SubKeys do
    begin
      if not TryStrToInt(Sub, Val) then
        Continue;
      try
        if Reg.OpenKey(Sub, False) then
        try
          if Reg.ValueExists('HardwareInformation.qwMemorySize') then
          begin
            Raw := 0;
            case Reg.GetDataType('HardwareInformation.qwMemorySize') of
              rdInteger:
                Raw := Reg.ReadInteger('HardwareInformation.qwMemorySize');
              rdInt64:
                Raw := Reg.ReadInt64('HardwareInformation.qwMemorySize');
              rdBinary:
                begin
                  SetLength(Bytes, Reg.GetDataSize('HardwareInformation.qwMemorySize'));
                  if Length(Bytes) >= SizeOf(Int64) then
                  begin
                    Reg.ReadBinaryData('HardwareInformation.qwMemorySize', Bytes[0], Length(Bytes));
                    Move(Bytes[0], Raw, SizeOf(Int64));
                  end;
                end;
            end;
            if Raw > Result then
              Result := Raw;
          end;
        finally
          Reg.CloseKey;
        end;
      except
      end;
    end;
  finally
    SubKeys.Free;
    Reg.Free;
  end;
end;

function GetTotalPhysicalMemoryBytes: Int64;
var
  Status: MEMORYSTATUSEX;
begin
  Result := 0;
  FillChar(Status, SizeOf(Status), 0);
  Status.dwLength := SizeOf(Status);
  try
    if GlobalMemoryStatusEx(Status) then
      Result := Int64(Status.ullTotalPhys);
  except
    Result := 0;
  end;
end;

function RecommendedResponseLevel: TResponseIntelligence;
var
  Vram, Ram: Int64;
begin
  Vram := GetMaxDedicatedVramBytes;
  if Vram >= 6 * GB then
    Exit(riBalanced);
  if Vram > 0 then
    Exit(riFast);
  Ram := GetTotalPhysicalMemoryBytes;
  if Ram >= 16 * GB then
    Result := riBalanced
  else
    Result := riFast;
end;

function AnswerLengthFromInt(const Value: Integer): TAnswerLength;
begin
  case Value of
    0: Result := alShort;
    1: Result := alMedium;
    2: Result := alLong;
  else
    Result := alMedium;
  end;
end;

function ResponseIntelligenceFromInt(const Value: Integer): TResponseIntelligence;
begin
  case Value of
    0: Result := riFast;
    1: Result := riBalanced;
    2: Result := riMax;
  else
    Result := riBalanced;
  end;
end;

function GetAnswerLength: TAnswerLength;
begin
  Result := AnswerLengthFromInt(RegistryGetInt('AnswerLength', Ord(alMedium)));
end;

procedure SetAnswerLength(const Length: TAnswerLength);
begin
  RegistrySetInt('AnswerLength', Ord(Length));
end;

function GetResponseIntelligence: TResponseIntelligence;
var
  V: Integer;
begin
  V := RegistryGetInt('ResponseIntelligence', -1);
  if V < 0 then
  begin
    Result := RecommendedResponseLevel;
    SetResponseIntelligence(Result);
    Exit;
  end;
  Result := ResponseIntelligenceFromInt(V);
end;

procedure SetResponseIntelligence(const Level: TResponseIntelligence);
begin
  RegistrySetInt('ResponseIntelligence', Ord(Level));
end;

function RecommendedTranscriptionLevel: TTranscriptionIntelligence;
var
  Vram, Ram: Int64;
begin
  Vram := GetMaxDedicatedVramBytes;
  if Vram >= 10 * GB then
    Exit(tiMax);
  if Vram >= 6 * GB then
    Exit(tiBalanced);
  if Vram > 0 then
    Exit(tiFast);
  Ram := GetTotalPhysicalMemoryBytes;
  if Ram >= 16 * GB then
    Result := tiBalanced
  else
    Result := tiFast;
end;

function TranscriptionIntelligenceFromInt(const Value: Integer): TTranscriptionIntelligence;
begin
  case Value of
    0: Result := tiFast;
    1: Result := tiBalanced;
    2: Result := tiMax;
  else
    Result := tiBalanced;
  end;
end;

function GetTranscriptionIntelligence: TTranscriptionIntelligence;
var
  V: Integer;
begin
  V := RegistryGetInt('TranscriptionIntelligence', -1);
  if V < 0 then
  begin
    Result := RecommendedTranscriptionLevel;
    SetTranscriptionIntelligence(Result);
    Exit;
  end;
  Result := TranscriptionIntelligenceFromInt(V);
end;

procedure SetTranscriptionIntelligence(const Level: TTranscriptionIntelligence);
begin
  RegistrySetInt('TranscriptionIntelligence', Ord(Level));
end;

function GetAnswerLengthOptions(const Length: TAnswerLength): TPair<Integer, string>;
begin
  case Length of
    alShort:
      Result := TPair<Integer, string>.Create(140,
        'ANSWER LENGTH - SHORT (STRICT): Answer in 1-2 short sentences only, about 30-45 words total. ' +
        'Give just the single core point. Do NOT add examples, background, lists, or caveats. Stop as soon as the point is made.');
    alLong:
      Result := TPair<Integer, string>.Create(2048,
        'ANSWER LENGTH - LONG (STRICT): Write a thorough, in-depth answer of AT LEAST 4 paragraphs, about 250-350 words. ' +
        'Cover, in order: (1) the core concept, (2) why it matters, (3) trade-offs or alternatives, (4) a concrete real-world example. ' +
        'Develop each point with real detail. Do NOT be brief, do NOT stop early, do NOT summarise in a few lines.');
  else
    Result := TPair<Integer, string>.Create(600,
      'ANSWER LENGTH - MEDIUM: Answer in about 4-6 sentences, around 90-130 words: the key idea explained clearly, ' +
      'with a short concrete example when useful. Balanced - neither one-liner nor multi-paragraph essay.');
  end;
end;

procedure ApplyVadTo(Seg: TVoiceSegmenter);
var
  Thresh, Silence, MinSpeech: Integer;
begin
  Thresh := RegistryGetInt('VadThreshold', -1);
  if Thresh >= 0 then
    Seg.Threshold := Thresh / 1000 * 0.1;

  Silence := RegistryGetInt('VadSilenceMs', -1);
  if Silence >= 200 then
    Seg.SilenceMs := Silence;

  MinSpeech := RegistryGetInt('VadMinSpeechMs', -1);
  if MinSpeech >= 100 then
    Seg.MinSpeechMs := MinSpeech;
end;

procedure SaveVad(Seg: TVoiceSegmenter);
begin
  RegistrySetInt('VadThreshold', Round(Seg.Threshold / 0.1 * 1000));
  RegistrySetInt('VadSilenceMs', Seg.SilenceMs);
  RegistrySetInt('VadMinSpeechMs', Seg.MinSpeechMs);
end;

procedure SaveVadDefaults;
begin
  RegistrySetInt('VadThreshold', Round(TVoiceSegmenter.DefaultThreshold / 0.1 * 1000));
  RegistrySetInt('VadSilenceMs', TVoiceSegmenter.DefaultSilenceMs);
  RegistrySetInt('VadMinSpeechMs', TVoiceSegmenter.DefaultMinSpeechMs);
end;

end.
