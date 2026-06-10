unit uWhisperCat;

{ Delphi mirror of the engine transcription catalog (SherpaModelCatalog).
  Used only for UI state: menu install hints and the "remove downloaded model" action. The
  engine is the source of truth for downloading/loading.
  All tiers use Parakeet (sherpa-onnx), a FOLDER of onnx files:
    Fast               -> parakeet-fast      (int8, ~670 MB);
    Balanced and Max   -> parakeet-accurate  (full precision, ~2.5 GB, shared download). }

interface

uses
  System.SysUtils,
  uAppSettings,
  uAppPaths;

type
  TWhisperModelInfo = record
    FileName: string;       // Whisper: the .bin file. Parakeet: the model folder name.
    IsFolder: Boolean;      // True for Parakeet (folder of files), False for Whisper (.bin).
    SizeBytes: Int64;       // Whisper: file size. Parakeet: total bytes of all files.
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
        Result.FileName := 'parakeet-fast';
        Result.IsFolder := True;
        Result.SizeBytes := 670478772; // encoder+decoder+joiner+tokens (int8)
        Result.LabelText := 'Fast';
        Result.Description := 'Parakeet v3 int8 - very fast, 25 languages, noise-robust (~670 MB).';
      end;
    tiMax:
      begin
        Result.FileName := 'parakeet-accurate'; // same model/folder as Balanced
        Result.IsFolder := True;
        Result.SizeBytes := 2549700490;
        Result.LabelText := 'Maximum accuracy';
        Result.Description := 'Parakeet v3 full precision - highest local transcription accuracy (~2.5 GB).';
      end;
  else
    begin
      Result.FileName := 'parakeet-accurate';
      Result.IsFolder := True;
      Result.SizeBytes := 2549700490; // encoder+weights+decoder+joiner+tokens (fp32)
      Result.LabelText := 'Balanced (recommended)';
      Result.Description := 'Parakeet v3 full precision - highest local transcription accuracy (~2.5 GB).';
    end;
  end;
end;

function WhisperCatalogPathFor(const Level: TTranscriptionIntelligence): string;
begin
  Result := TPath.Combine(ModelsDir, WhisperCatalogGet(Level).FileName);
end;

function ParakeetFolderComplete(const Dir: string): Boolean;
var
  EncOnnx, EncInt8: string;
begin
  // The folder is "installed" when an encoder (int8 or fp32) plus tokens are present.
  EncInt8 := TPath.Combine(Dir, 'encoder.int8.onnx');
  EncOnnx := TPath.Combine(Dir, 'encoder.onnx');
  Result := TFile.Exists(TPath.Combine(Dir, 'tokens.txt')) and
            (TFile.Exists(EncInt8) or TFile.Exists(EncOnnx));
end;

function WhisperCatalogIsInstalled(const Level: TTranscriptionIntelligence): Boolean;
var
  Info: TWhisperModelInfo;
  Path: string;
begin
  Result := False;
  try
    Info := WhisperCatalogGet(Level);
    Path := WhisperCatalogPathFor(Level);
    if Info.IsFolder then
      Result := TDirectory.Exists(Path) and ParakeetFolderComplete(Path)
    else if TFile.Exists(Path) then
      Result := TFile.GetSize(Path) = Info.SizeBytes
    else if Level = tiMax then
      // legacy flat name
      Result := TFile.Exists(TPath.Combine(ModelsDir, 'ggml-large-v3.bin'));
  except
    Result := False;
  end;
end;

procedure WhisperCatalogDelete(const Level: TTranscriptionIntelligence);
var
  Info: TWhisperModelInfo;
  Path: string;
begin
  Info := WhisperCatalogGet(Level);
  Path := WhisperCatalogPathFor(Level);
  try
    if Info.IsFolder then
    begin
      if TDirectory.Exists(Path) then
        TDirectory.Delete(Path, True);
    end
    else
    begin
      if TFile.Exists(Path) then
        TFile.Delete(Path);
      if TFile.Exists(Path + '.download') then
        TFile.Delete(Path + '.download');
      if (Level = tiMax) and TFile.Exists(TPath.Combine(ModelsDir, 'ggml-large-v3.bin')) then
        TFile.Delete(TPath.Combine(ModelsDir, 'ggml-large-v3.bin'));
    end;
  except
    // best effort
  end;
end;

end.
