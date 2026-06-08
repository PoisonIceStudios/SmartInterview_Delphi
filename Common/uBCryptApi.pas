unit uBCryptApi;

{ Minimal bcrypt.dll bindings for ECDSA P-256 (Delphi 12). }

interface

uses
  Winapi.Windows;

type
  BCRYPT_ALG_HANDLE = Pointer;
  BCRYPT_KEY_HANDLE = Pointer;

const
  BcryptLib = 'bcrypt.dll';
  BCRYPT_ECDSA_PUBLIC_P256_MAGIC = $31534345;
  BCRYPT_ECDSA_PRIVATE_P256_MAGIC = $32534345;
  BCRYPT_ECDSA_P256_ALGORITHM = 'ECDSA_P256';
  BCRYPT_ECCPUBLIC_BLOB = 'ECCPUBLICBLOB';
  BCRYPT_ECCPRIVATE_BLOB = 'ECCPRIVATEBLOB';

function BCryptOpenAlgorithmProvider(out phAlgorithm: BCRYPT_ALG_HANDLE;
  pszAlgId: PWideChar; pszImplementation: PWideChar; dwFlags: ULONG): NTSTATUS; stdcall;
  external BcryptLib name 'BCryptOpenAlgorithmProvider';

function BCryptCloseAlgorithmProvider(hAlgorithm: BCRYPT_ALG_HANDLE;
  dwFlags: ULONG): NTSTATUS; stdcall;
  external BcryptLib name 'BCryptCloseAlgorithmProvider';

function BCryptImportKeyPair(hAlgorithm: BCRYPT_ALG_HANDLE; hImportKey: BCRYPT_KEY_HANDLE;
  pszBlobType: PWideChar; out phKey: BCRYPT_KEY_HANDLE; pbInput: PByte; cbInput: ULONG;
  dwFlags: ULONG): NTSTATUS; stdcall;
  external BcryptLib name 'BCryptImportKeyPair';

function BCryptVerifySignature(hKey: BCRYPT_KEY_HANDLE; pPaddingInfo: Pointer;
  pbHash: PByte; cbHash: ULONG; pbSignature: PByte; cbSignature: ULONG;
  dwFlags: ULONG): NTSTATUS; stdcall;
  external BcryptLib name 'BCryptVerifySignature';

function BCryptSignHash(hKey: BCRYPT_KEY_HANDLE; pPaddingInfo: Pointer; pbInput: PByte;
  cbInput: ULONG; pbOutput: PByte; cbOutput: ULONG; pcbResult: PULONG;
  dwFlags: ULONG): NTSTATUS; stdcall;
  external BcryptLib name 'BCryptSignHash';

function BCryptDestroyKey(hKey: BCRYPT_KEY_HANDLE): NTSTATUS; stdcall;
  external BcryptLib name 'BCryptDestroyKey';

function BCryptGenerateKeyPair(hAlgorithm: BCRYPT_ALG_HANDLE; out phKey: BCRYPT_KEY_HANDLE;
  dwLength: ULONG; dwFlags: ULONG): NTSTATUS; stdcall;
  external BcryptLib name 'BCryptGenerateKeyPair';

function BCryptFinalizeKeyPair(hKey: BCRYPT_KEY_HANDLE; dwFlags: ULONG): NTSTATUS; stdcall;
  external BcryptLib name 'BCryptFinalizeKeyPair';

function BCryptExportKey(hKey: BCRYPT_KEY_HANDLE; hExportKey: BCRYPT_KEY_HANDLE;
  pszBlobType: PWideChar; pbOutput: PByte; cbOutput: ULONG; pcbResult: PULONG;
  dwFlags: ULONG): NTSTATUS; stdcall;
  external BcryptLib name 'BCryptExportKey';

implementation

end.
