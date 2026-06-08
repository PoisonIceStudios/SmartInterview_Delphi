# Audit sicurezza — licenze e runtime

Audit del sistema di licenze (SmartInterview + LicenseManager + Engine DLL).

> **Spiegazione semplice (non tecnica):** vedi [Sicurezza — guida elementare](sicurezza-guida.md).

## Riepilogo esecutivo

| Area | Stato | Note |
|------|-------|------|
| Ora online obbligatoria (app) | OK | `TryFetchUtcNow` in attivazione e validazione |
| Ora online obbligatoria (LicenseManager) | OK | Creazione chiavi bloccata senza internet |
| Licenza scaduta al riavvio | OK | Registry pulito → schermata attivazione |
| Integrità chiave licenza v5 | **Forte** | ECDSA P-256, chiave privata solo in LicenseManager |
| Integrità chiave licenza v4 | OK | HMAC-SHA256 (legacy, ancora accettata) |
| Segretezza chiave licenza v4 | **Debole** | Segreti simmetrici nel binario client |
| Nuove emissioni | v5 | `SI5-…` firmate dal LicenseManager (chiave privata locale) |
| Controllo periodico runtime | OK | Ogni 6h tentativo online; grace offline 72h |
| Binding macchina sulla chiave | No | Solo username forum |
| Storage locale | Medio | Chiave in chiaro in registry HKCU |
| Gate engine (DLL) | OK | `EngineSessionAuth` + ora online + licenza |
| Bypass diagnostico | OK (Release) | Solo build Debug con `DIAGNOSTIC_LOG` |

---

## 1. Requisito: ora online per generazione e verifica

### SmartInterview (runtime)

- `uLicenseService.LicenseIsValid` e `LicenseTryActivate` chiamano `TryFetchUtcNow` (`Common/uLicenseOnlineTime.pas`).
- Senza risposta da [worldtimeapi.org](https://worldtimeapi.org) o [timeapi.io](https://timeapi.io) → messaggio offline, nessuna attivazione né uso.
- L'engine C# ripete lo stesso controllo in `EngineSessionAuth.TryValidateToken` via `OnlineTime.TryFetchUtcNow`.

**Anti-bypass orologio di sistema:** la scadenza confronta il giorno UTC online con `ExpiryUnixDay` incorporato nella chiave, non `Now` locale.

### LicenseManager (emissione)

- `btnCreateClick` richiede `TryFetchUtcNow` prima di generare la chiave.
- I preset mensili (1/3/6/12 mesi) usano la data locale derivata dall'UTC online, non `Date` di sistema.
- `Registered` nel JSON viene timestampato con l'ora locale corrispondente all'UTC online.

---

## 2. Requisito: licenza scaduta → riattivazione

Flusso verificato in codice:

```
SmartInterview.dpr
  → TFrmLicense.EnsureLicensed
       → LicenseIsValid
            → TryFetchUtcNow (online)
            → LicenseCodecTryValidate
            → se scaduta o disattivata: LicenseStoreClear
       → se non valida: mostra form attivazione
```

- La chiave **incorpora la data di scadenza** (`ExpiryUnixDay`). Dopo la scadenza serve una **nuova chiave** emessa dal venditore (con nuova data nel payload).
- `LicenseStoreClear` rimuove chiave e username da `HKCU\Software\SmartInterview`.
- Il form mostra `LicenseLastCheckError` (es. *"This license has expired. Enter a new license code from the seller."*).

---

## 3. Schema crittografico v5 (corrente — ECDSA P-256)

Implementato in `Common/uLicenseCodecV5.pas`, `uLicenseEcdsa.pas`, `Projects/Engine/LicenseCodecV5.cs`.

| Elemento | Dettaglio |
|----------|-----------|
| Prefisso | `SI5-` + 34 gruppi Base32 (136 caratteri dati) |
| Payload | 21 byte: magic `$55`, flags, expiry day UTC, issued day UTC, username |
| Firma | 64 byte ECDSA P-256 su SHA-256(payload) |
| Chiave privata | Solo `Projects/LicenseManager/Keys/license_signing.priv` (gitignored) |
| Chiave pubblica | `uLicensePublicKey.pas` + `LicenseCodecV5.cs` |
| Generazione coppia | LicenseManager → menu **Chiavi → Genera chiavi di firma** (BCrypt) |

**Sicurezza:** senza la chiave privata non si possono creare chiavi valide. La chiave pubblica nel client permette solo verifica.

---

## 3b. Schema legacy v4 (ancora accettato)

### Formato chiave (32 caratteri Base32, 8×4)

Payload interno (20 byte), poi XOR, poi Base32:

| Offset | Contenuto |
|--------|-----------|
| 0 | Magic `0x54` |
| 1 | Flags (`Active`, `Lifetime`) |
| 2–5 | `ExpiryUnixDay` (uint32, giorno UTC) |
| 6 | Lunghezza username (1–10) |
| 7+ | Username UTF-8 (lowercase) |
| resto | Troncamento HMAC-SHA256 del canone `user\|expiry\|flags` |

**Trasformazione esterna:** XOR con keystream = primi 20 byte di `HMAC-SHA256("stream", XorSecret)`.

**Segreti (hardcoded in `uLicenseCodec.pas` e `LicenseCodec.cs`):**

- `SmartInterview|License|v4|hmac`
- `SmartInterview|License|v4|xor`

### Cosa NON c'è nella chiave v4

- **Data di attivazione/emissione** — solo scadenza (o lifetime). La data `Registered` esiste solo in `licenses.json` del LicenseManager, non nel client.
- **Fingerprint macchina** — il binding hardware è solo nel codice richiesta attivazione (`RQ1...`), non nella licenza finale.
- **AES o crittografia asimmetrica** — non usati.

### Valutazione sicurezza

| Meccanismo | Pro | Contro |
|------------|-----|--------|
| HMAC-SHA256 | Integrità e anti-tampering del payload | Segreto simmetrico nel client → estraibile dal binario |
| XOR + keystream statico | Offusca il payload a occhio nudo | Reversibile in secondi con il segreto noto |
| Base32 | Leggibilità umana | Nessuna protezione aggiuntiva |
| Ora online | Impedisce bypass data sistema | Richiede rete; MITM su HTTP(S) time API (basso rischio) |

**Conclusione v4:** formato simmetrico — segreti estraibili dal binario; usare solo per chiavi legacy. **Nuove emissioni: v5.**

---

## 3c. Controllo periodico runtime (`uLicenseMonitor.pas`)

| Parametro | Valore | File |
|-----------|--------|------|
| Timer UI | 30 min | `uMainForm.tmrLicenseTimer` |
| Soglia re-check | 6 ore | `LicenseRecheckIntervalMs` |
| Grace offline | 72 ore | `LicenseOfflineGraceMs` |
| Ancoraggio UTC | Registry + HMAC | `LicenseAnchorUtc`, `LicenseAnchorHmac` |

Flusso: ultimo UTC online noto + tempo monotonic (`GetTickCount64`) → stima scadenza offline; oltre 72h senza refresh online → `FEngine.Stop`.

---

## 4. Token di sessione engine (`SI_SESSION.v2`)

- Costruito in `uSessionAuth.SessionBuildToken`: `HMAC-SHA256(username|licenseKey|expiryUnix, SessionHmacSecret)`.
- Scadenza sessione: 24 ore (`SessionValiditySeconds = 86400`).
- Passato all'engine via variabili d'ambiente `SMARTINTERVIEW_SESSION`, `SMARTINTERVIEW_LICENSE`, `SMARTINTERVIEW_USER`.
- L'engine verifica: formato token, scadenza, username, **licenza valida con ora online**, firma HMAC.

**Rischio:** `SessionHmacSecret` è nel binario Delphi e C#. Con licenza + username un attaccante potrebbe costruire token di sessione finché la licenza è valida.

**Mitigazione attuale:** senza licenza valida (verificata online) l'engine rifiuta i comandi AI.

---

## 5. Superfici d'attacco aggiuntive

| Superficie | Dettaglio | Mitigazione |
|------------|-----------|-------------|
| Registry `HKCU\Software\SmartInterview` | Chiave licenza in chiaro | Accettabile per HKCU; utente standard non può modificare HKCU altrui |
| `licenses.json` (LicenseManager) | Archivio chiavi in chiaro sul PC venditore | Proteggere filesystem; non distribuire il file |
| Richiesta attivazione `RQ1.*` | Base64(JSON) senza firma | Solo identifica macchina+user per supporto; non è la licenza |
| `DIAGNOSTIC_LOG` | Bypass auth engine in Debug | Solo `Configuration==Debug` nel `.csproj` |
| IPC JSON stdin/stdout | Processo figlio locale | Token sessione richiesto su `startup` e comandi |
| Time API HTTP | Possibile risposta manipolata (MITM) | HTTPS; rischio basso per uso consumer |

---

## 6. Checklist conformità requisiti utente

| # | Requisito | Esito |
|---|-----------|-------|
| 1 | Data corrente online alla generazione licenza | **Implementato** (LicenseManager + unità condivisa) |
| 1b | Verifica licenza richiede ora online | **Già presente** (app + engine) |
| 2 | Riavvio con licenza scaduta → attivazione iniziale | **Funziona** (`LicenseStoreClear` + `EnsureLicensed`) |
| 2b | Nuova chiave necessaria dopo scadenza | **Per design** (expiry nel payload) |
| 3 | Crittografia stringa licenza | **v5 = ECDSA P-256** (corrente); v4 legacy HMAC+XOR |
| 4 | App aperta a lungo | **Implementato** — re-check 6h, grace offline 72h |

---

## 7. Test manuali consigliati

1. **Offline:** avviare SmartInterview senza rete → deve rifiutare attivazione e uso.
2. **Scadenza:** impostare chiave con expiry ieri (LicenseManager) → al riavvio online, form attivazione e registry vuoto.
3. **LicenseManager offline:** creare licenza senza rete → deve fallire con messaggio offline.
4. **Engine senza token:** avviare DLL manualmente senza env vars → comandi AI rifiutati (build Release).
5. **Username mismatch:** chiave per `user_a`, attivare come `user_b` → rifiutato.

---

## Riferimenti codice

- Codec v4/v5: `Common/uLicenseCodec.pas`, `Common/uLicenseCodecV5.pas`, `Projects/Engine/LicenseCodec.cs`, `Projects/Engine/LicenseCodecV5.cs`
- Firma/verifica: `Common/uLicenseEcdsa.pas`, `Projects/LicenseManager/uLicenseEcdsaSign.pas`
- Monitor periodico: `Common/uLicenseMonitor.pas`
- Ora online: `Common/uLicenseOnlineTime.pas`, `Projects/Engine/OnlineTime.cs`
- Servizio licenza: `Projects/SmartInterview/src/uLicenseService.pas`
- UI attivazione: `Projects/SmartInterview/uFrmLicense.pas` (`EnsureLicensed`, `PromptRelicense`)
- Emissione: `Projects/LicenseManager/LicenseManagerMain.pas`
- Auth engine: `Projects/Engine/EngineSessionAuth.cs`, `Projects/SmartInterview/src/uSessionAuth.pas`
- Generazione chiavi di firma: `Projects/LicenseManager/uLicenseKeyGen.pas` (BCrypt, menu **Chiavi → Genera chiavi di firma**)
