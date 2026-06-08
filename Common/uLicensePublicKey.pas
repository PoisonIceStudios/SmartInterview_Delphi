unit uLicensePublicKey;

{ ECDSA P-256 public key (BCRYPT_ECCPUBLIC_BLOB) for license v5 verification.
  Must match Projects/LicenseManager/Keys/license_signing.pub — regenerate with tools/KeyGen. }

interface

function LicensePublicKeyBlob: TBytes;

implementation

function HexToBytes(const Hex: string): TBytes;
var
  I, N: Integer;
begin
  N := Length(Hex) div 2;
  SetLength(Result, N);
  for I := 0 to N - 1 do
    Result[I] := Byte(StrToInt('$' + Copy(Hex, I * 2 + 1, 2)));
end;

function LicensePublicKeyBlob: TBytes;
begin
  Result := HexToBytes(
    '45435331200000001FC80934B34F5AD860ECD715B3A9225FF88387B95DCBB5774096644' +
    'FF95D506B7D56E98C5D09EB9B3CAAC1C703087E4940E63B807AF1ABB47FD796A80341FFD0');
end;

end.
