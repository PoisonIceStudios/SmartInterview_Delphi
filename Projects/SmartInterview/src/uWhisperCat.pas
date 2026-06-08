unit uWhisperCat;

interface

uses
  System.SysUtils,
  uAppSettings,
  uAppPaths;

type
  TWhisperModelInfo = record
    FileName: string;
    SizeBytes: Int64;
    LabelText: string;
    Description: string;
  end;

function WhisperCatalogGet(const Level: TTranscriptionIntelligence): TWhisperModelInfo;
function WhisperCatalogPathFor(const Level: TTranscriptionIntelligence): string;
function WhisperCatalogIsInstalled(const Level: TTranscriptionIntelligence): Boolean;
procedure WhisperCatalogDelete(const Level: TTranscriptionIntelligence);

implementation

uses
  System.IOUtils;

function WhisperCatalogGet(const Level: TTranscriptionIntelligence): TWhisperModelInfo;
begin
  case Level of
    tiFast:
      begin
        Result.FileName := 'whisper-fast.bin';
        Result.SizeBytes := 487601967;
        Result.LabelText := 'Fast';
        Result.Description := 'Fast recognition for clear speech (~470 MB, ggml-small).';
      end;
    tiMax:
      begin
        Result.FileName := 'whisper-max.bin';
        Result.SizeBytes := 3095033483;
        Result.LabelText := 'Maximum accuracy';
        Result.Description := 'Best quality for noisy audio and similar-sounding words (~3.1 GB, ggml-large-v3).';
      end;
  else
    begin
      Result.FileName := 'whisper-balanced.bin';
      Result.SizeBytes := 1533763059;
      Result.LabelText := 'Balanced (recommended)';
      Result.Description := 'Good balance of speed and accuracy for accents and background noise (~1.5 GB, ggml-medium).';
    end;
  end;
end;

function WhisperCatalogPathFor(const Level: TTranscriptionIntelligence): string;
begin
  Result := TPath.Combine(ModelsDir, WhisperCatalogGet(Level).FileName);
end;

function WhisperCatalogIsInstalled(const Level: TTranscriptionIntelligence): Boolean;
var
  Info: TWhisperModelInfo;
  LegacyPath: string;
begin
  Result := False;
  try
    Info := WhisperCatalogGet(Level);
    if TFile.Exists(WhisperCatalogPathFor(Level)) then
      Exit(TFile.GetSize(WhisperCatalogPathFor(Level)) = Info.SizeBytes);
    case Level of
      tiFast:
        begin
          if TFile.Exists(TPath.Combine(ModelsDir, 'ggml-small.bin')) then
            Exit(TFile.GetSize(TPath.Combine(ModelsDir, 'ggml-small.bin')) = Info.SizeBytes);
          LegacyPath := TPath.Combine(ModelsDir, 'whisper-balanced.bin');
        end;
      tiMax:
        LegacyPath := TPath.Combine(ModelsDir, 'ggml-large-v3.bin');
    else
      begin
        if TFile.Exists(TPath.Combine(ModelsDir, 'ggml-medium.bin')) then
          Exit(TFile.GetSize(TPath.Combine(ModelsDir, 'ggml-medium.bin')) = Info.SizeBytes);
        LegacyPath := TPath.Combine(ModelsDir, 'whisper-max.bin');
      end;
    end;
    if TFile.Exists(LegacyPath) then
      Result := TFile.GetSize(LegacyPath) = Info.SizeBytes;
  except
    Result := False;
  end;
end;

procedure WhisperCatalogDelete(const Level: TTranscriptionIntelligence);
var
  Info: TWhisperModelInfo;
  Path, LegacyPath: string;
begin
  Info := WhisperCatalogGet(Level);
  Path := WhisperCatalogPathFor(Level);
  if TFile.Exists(Path) then
    TFile.Delete(Path);
  if TFile.Exists(Path + '.download') then
    TFile.Delete(Path + '.download');
  case Level of
    tiFast:
      begin
        LegacyPath := TPath.Combine(ModelsDir, 'ggml-small.bin');
        if TFile.Exists(LegacyPath) then TFile.Delete(LegacyPath);
        LegacyPath := TPath.Combine(ModelsDir, 'whisper-balanced.bin');
      end;
    tiMax:
      LegacyPath := TPath.Combine(ModelsDir, 'ggml-large-v3.bin');
  else
    begin
      LegacyPath := TPath.Combine(ModelsDir, 'ggml-medium.bin');
      if TFile.Exists(LegacyPath) then TFile.Delete(LegacyPath);
      LegacyPath := TPath.Combine(ModelsDir, 'whisper-max.bin');
    end;
  end;
  if TFile.Exists(LegacyPath) then
    TFile.Delete(LegacyPath);
end;

end.
