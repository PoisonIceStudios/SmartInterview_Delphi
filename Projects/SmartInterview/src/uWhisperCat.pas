unit uWhisperCat;

{ Delphi mirror of the engine transcription catalog (WhisperModelCatalog).
  Used only for UI state: menu install hints and the "remove downloaded model" action. The
  engine is the source of truth for downloading/loading.
  Default engine = Whisper (the interview language is forced, so no foreign-language output).
  Tiers: Fast -> ggml-small, Balanced -> ggml-medium, Max -> ggml-large-v3 (single .bin each). }

interface

uses
  System.SysUtils,
  uAppSettings,
  uAppPaths;

type
  TWhisperModelInfo = record
    FileName: string;
    IsFolder: Boolean;      // kept for compatibility; always False for Whisper .bin models
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
  Result.IsFolder := False;
  case Level of
    tiFast:
      begin
        Result.FileName := 'whisper-fast.bin';
        Result.SizeBytes := 487601967;
        Result.LabelText := 'Fast';
        Result.Description := 'Whisper small - fast, forced to your language (~470 MB).';
      end;
    tiMax:
      begin
        Result.FileName := 'whisper-max.bin';
        Result.SizeBytes := 3095033483;
        Result.LabelText := 'Maximum accuracy';
        Result.Description := 'Whisper large-v3 - highest accuracy, forced to your language (~3.1 GB).';
      end;
  else
    begin
      Result.FileName := 'whisper-balanced.bin';
      Result.SizeBytes := 1533763059;
      Result.LabelText := 'Balanced (recommended)';
      Result.Description := 'Whisper medium - balanced speed/accuracy, forced to your language (~1.5 GB).';
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
begin
  Result := False;
  try
    Info := WhisperCatalogGet(Level);
    if TFile.Exists(WhisperCatalogPathFor(Level)) then
      Result := TFile.GetSize(WhisperCatalogPathFor(Level)) = Info.SizeBytes;
  except
    Result := False;
  end;
end;

procedure WhisperCatalogDelete(const Level: TTranscriptionIntelligence);
var
  Path: string;
begin
  Path := WhisperCatalogPathFor(Level);
  try
    if TFile.Exists(Path) then
      TFile.Delete(Path);
    if TFile.Exists(Path + '.download') then
      TFile.Delete(Path + '.download');
  except
    // best effort
  end;
end;

end.
