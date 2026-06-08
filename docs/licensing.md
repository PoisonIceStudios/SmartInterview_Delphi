# Sistema licenze

[← Torna al README](../README.md) · [Architettura](architecture.md)

## Panoramica

SmartInterview usa licenze offline embedded nella chiave (formato **v4**), con verifica dell'ora di scadenza tramite **ora UTC online** (anti-manomissione data di sistema).

## Componenti

| Componente | Percorso | Ruolo |
|------------|----------|-------|
| Codec licenza | `Common/uLicenseCodec.pas` | Encode/decode chiavi 32 caratteri Base32 (8 gruppi × 4) |
| Servizio app | `uLicenseService.pas` | Validazione, attivazione, storage registry |
| Ora online | `uLicenseOnlineTime.pas` | Fetch UTC da API pubblica |
| Sessione engine | `uSessionAuth.pas` | Token HMAC per autorizzare il motore AI |
| Fingerprint | `uMachineFingerprint.pas` | Binding opzionale macchina per richieste attivazione |
| Tool admin | `LicenseManager.exe` | Generazione e gestione licenze |

## Formato chiave v4

- **32 caratteri** Base32 (alfabeto senza I/L/O/U), formattati come `XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX`
- Payload 20 byte: magic `$54`, flags (active/lifetime), expiry Unix day, username (max 10 char), HMAC tail
- Cifratura XOR con keystream derivato da HMAC
- Username normalizzato: lowercase, trim

### Flag

| Flag | Valore | Significato |
|------|--------|-------------|
| `LicenseFlagActive` | `$01` | Licenza attiva |
| `LicenseFlagLifetime` | `$02` | Senza scadenza |

## Flusso attivazione (SmartInterview)

1. Utente inserisce username forum + chiave in `uFrmLicense`.
2. `LicenseTryActivate` verifica:
   - Connessione internet (per ora UTC)
   - Decode payload
   - Username corrispondente
   - Flag active, non scaduta
   - Round-trip encode (integrità)
3. Chiave salvata in registry via `uRegistryStore`.

## Flusso avvio engine

1. `LicenseBuildSessionToken` crea token con scadenza 24h.
2. `TPipeEngine.Start` passa token via env vars al subprocesso.
3. Engine rifiuta comandi AI senza autenticazione valida.

## LicenseManager (tool interno)

Utility separata per venditori/admin:

- Crea licenze con username, scadenza (o lifetime), flag active
- Preset rapidi: 1/3/6/12 mesi
- Salva elenco in `licenses.json` accanto all'exe
- Decode/visualizza payload chiavi esistenti

### Build

```text
Projects/LicenseManager/LicenseManager.dproj
Search path: ..\..\Common\
```

## Aggiungere unità condivise future

Mettere nuove unità in `Common/` e aggiornare `DCC_UnitSearchPath` in tutti i `.dproj` che le usano. Vedi [Setup → Common](setup.md#common--unità-pascal-condivise).
