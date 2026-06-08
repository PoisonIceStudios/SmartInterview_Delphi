unit uModelCat;

interface

uses
  System.SysUtils,
  uAppSettings,
  uAppPaths;

type
  TLocalModelInfo = record
    FileName: string;
    Url: string;
    Sha256: string;
    SizeBytes: Int64;
    LabelText: string;
    Description: string;
    ApproxVramBytes: Int64;
  end;

function ModelCatalogGet(const Level: TResponseIntelligence): TLocalModelInfo;
function ModelCatalogPathFor(const Level: TResponseIntelligence): string;
function ModelCatalogIsInstalled(const Level: TResponseIntelligence): Boolean;
function ModelSizeText(Bytes: Int64): string;

implementation

uses
  System.IOUtils;

const
  BaseUrl = 'https://huggingface.co/bartowski';

function ModelCatalogGet(const Level: TResponseIntelligence): TLocalModelInfo;
begin
  case Level of
    riFast:
      begin
        Result.FileName := 'response-fast.bin';
        Result.Url := BaseUrl + '/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf';
        Result.Sha256 := '9c9f56a391a3abbd5b89d0245bf6106081bcc3173119d4229235dd9d23253f94';
        Result.SizeBytes := 1929903264;
        Result.LabelText := 'Fast';
        Result.Description := 'Quick responses, basic accuracy - best for lower-end PCs (~2 GB).';
        Result.ApproxVramBytes := 3000000000;
      end;
    riMax:
      begin
        Result.FileName := 'response-max.bin';
        Result.Url := BaseUrl + '/Qwen2.5-14B-Instruct-GGUF/resolve/main/Qwen2.5-14B-Instruct-Q4_K_M.gguf';
        Result.Sha256 := 'e47ad95dad6ff848b431053b375adb5d39321290ea2c638682577dafca87c008';
        Result.SizeBytes := 8988110976;
        Result.LabelText := 'Maximum accuracy';
        Result.Description := 'Most accurate, detailed answers - needs more memory and time (~9 GB).';
        Result.ApproxVramBytes := 11000000000;
      end;
  else
    begin
      Result.FileName := 'response-balanced.bin';
      Result.Url := BaseUrl + '/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf';
      Result.Sha256 := '65b8fcd92af6b4fefa935c625d1ac27ea29dcb6ee14589c55a8f115ceaaa1423';
      Result.SizeBytes := 4683074240;
      Result.LabelText := 'Balanced (recommended)';
      Result.Description := 'Good balance of accuracy and speed (~4.7 GB).';
      Result.ApproxVramBytes := 6500000000;
    end;
  end;
end;

function ModelCatalogPathFor(const Level: TResponseIntelligence): string;
begin
  Result := TPath.Combine(ModelsDir, ModelCatalogGet(Level).FileName);
end;

function ModelCatalogIsInstalled(const Level: TResponseIntelligence): Boolean;
var
  Info: TLocalModelInfo;
  Size: Int64;
begin
  Result := False;
  try
    Info := ModelCatalogGet(Level);
    if not TFile.Exists(ModelCatalogPathFor(Level)) then
      Exit;
    Size := TFile.GetSize(ModelCatalogPathFor(Level));
    Result := Size = Info.SizeBytes;
  except
    Result := False;
  end;
end;

function ModelSizeText(Bytes: Int64): string;
begin
  if Bytes >= 1073741824 then
    Result := Format('%.1f GB', [Bytes / 1073741824])
  else if Bytes >= 1048576 then
    Result := Format('%.0f MB', [Bytes / 1048576])
  else
    Result := Format('%.0f KB', [Bytes / 1024]);
end;

end.
