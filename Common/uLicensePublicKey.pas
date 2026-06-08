unit uLicensePublicKey;

{ ECDSA P-256 public key (BCRYPT_ECCPUBLIC_BLOB) for license v5 verification.
  Must match Projects/LicenseManager/Keys/license_signing.pub — regenerate from
  LicenseManager: menu Chiavi -> Genera chiavi di firma. }

interface

uses
  System.SysUtils;

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
    '45435331200000000D72BBD2CB65C07A57795369F5A0538BEBC0FCE8DB653C5EB25E4A961486320B85' +
    '800CF1B870739CE62A6F1A1ECA5759DA424F8613A8F4E944A69699DC36D026');
end;

end.
