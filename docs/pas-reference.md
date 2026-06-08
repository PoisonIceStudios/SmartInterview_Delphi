# Riferimento unità Pascal (.pas)

[← Torna al README](../README.md) · [Architettura](architecture.md)

Elenco completo di tutte le unità Delphi nel repository, organizzate per area funzionale.

---

## Common/ — condivise tra progetti

| Unità | Descrizione |
|-------|-------------|
| `uLicenseCodec.pas` | Codec chiavi licenza v4: encode/decode Base32, payload 20 byte, HMAC-SHA256, XOR keystream. Espone `LicenseCodecEncode`, `LicenseCodecTryValidate`, `LicenseCodecTryDecodePayload`, costanti `LicenseKeyChars`, `LicenseMaxUsernameLen`. |

---

## Projects/SmartInterview/ — form e entry point

| Unità | Descrizione |
|-------|-------------|
| `SmartInterview.dpr` | Programma principale: mutex single-instance, flusso licenza → disclaimer → setup → splash → main form. |
| `uMainForm.pas` | Form principale: overlay colloquio, waveform, chat Q&A, tray icon, hotkey ascolto, modalità manuale/auto, read-along, indicatori GPU/contesto. |
| `uFrmSplash.pas` | Splash screen con stato avvio; delega a `uAppStartup.RunInitialStartup`. |
| `uFrmLicense.pas` | Dialog attivazione licenza (`EnsureLicensed`). |
| `uFrmDisclaimer.pas` | Dialog accettazione disclaimer (`EnsureAccepted`, EULA v3). |
| `uFrmInterviewSetup.pas` | Prompt opzionale configurazione profilo colloquio al primo avvio. |
| `uFrmProfile.pas` | Editor profilo: ruolo, tech stack, job description, esperienza. |
| `uFrmSettings.pas` | Impostazioni: modalità auto, VAD threshold/silenzio, meter audio, tasto ascolto. |
| `uFrmAbout.pas` | Finestra informazioni sull'applicazione. |

---

## Projects/SmartInterview/src/ — logica applicativa

### Avvio e bridge motore

| Unità | Descrizione |
|-------|-------------|
| `uAppStartup.pas` | Orchestrazione startup: `TPipeEngine.Start`, IPC `ping` + `startup` (con fallback `StartupLegacy`), singleton condiviso col main form via `TakeStartupEngine`. |
| `uPipeEngine.pas` | Bridge Delphi ↔ `SmartInterview.Engine.dll`: `CreateProcess` con `dotnet`, pipe stdin/stdout, protocollo JSON-lines, comandi ping/startup/transcribe/generate_stream/reset/classify ecc. Costruisce token sessione e env vars licenza all'avvio. |
| `uAppSettings.pas` | Getter/setter impostazioni runtime: tier intelligenza LLM/Whisper, lunghezza risposta, lingua, VRAM dedicata da registry, parametri VAD. |
| `uAppPaths.pas` | Percorsi modelli: directory exe, `%LOCALAPPDATA%\SmartInterview\models`, elenco file noti. |
| `uRegistryStore.pas` | Persistenza impostazioni e licenza in `HKCU\Software\SmartInterview`. |
| `uDebugLog.pas` | Log diagnostico su file in `%LOCALAPPDATA%\SmartInterview\`. |

### Audio e cattura

| Unità | Descrizione |
|-------|-------------|
| `uAudioCapture.pas` | Facciata cattura: combina loopback sistema + microfono opzionale in buffer PCM float32 16 kHz. |
| `uWasapiCapture.pas` | WASAPI loopback (audio di sistema) con resampling a 16 kHz; enumerazione dispositivi. |
| `uWasapi16k.pas` | Sorgente microfono WASAPI già a 16 kHz mono. |
| `uMicCapture.pas` | Wrapper semplificato cattura microfono. |
| `uMicDevices.pas` | Enumerazione e selezione dispositivi microfono. |
| `uVoiceSegmenter.pas` | VAD (Voice Activity Detection): soglia energia, silenzio minimo, segmentazione utterance per modalità auto. |

### UI e interazione

| Unità | Descrizione |
|-------|-------------|
| `uGlobalKeyboardHook.pas` | Hook tastiera globale low-level (WH_KEYBOARD_LL) per tasto ascolto Ctrl/Shift/Alt. |
| `uTheme.pas` | Costanti e helper stile VCL: font Segoe UI, colori accent, applicazione tema a controlli. |
| `uTitleIndicators.pas` | Indicatori LED nella title bar: stato ascolto, GPU, contesto chat. |
| `uRichEditFmt.pas` | Formattazione RichEdit: colori testo, nascondere caret. |
| `uReadAlongMatcher.pas` | Matcher parole per evidenziazione read-along durante la lettura della risposta. |
| `uLiveTransDiag.pas` | Diagnostica trascrizione live su file log. |

### Profilo colloquio e cataloghi modelli

| Unità | Descrizione |
|-------|-------------|
| `uInterviewProfile.pas` | Record profilo colloquio (ruolo, stack, job, esperienza); load/save JSON via registry. |
| `uModelCat.pas` | Catalogo modelli LLM Qwen2.5: URL HuggingFace, SHA256, dimensioni, label tier Fast/Balanced/Max. |
| `uWhisperCat.pas` | Catalogo modelli Whisper ggml: path, URL, hash per tier Fast/Balanced/Max. |

### Licenze e sicurezza

| Unità | Descrizione |
|-------|-------------|
| `uLicenseService.pas` | API licenza applicazione: `LicenseIsValid`, `LicenseTryActivate`, `LicenseBuildSessionToken`, storage registry. |
| `uLicenseOnlineTime.pas` | Fetch ora UTC online (worldtimeapi.org, timeapi.io) per anti-manomissione data di scadenza. |
| `uSessionAuth.pas` | Token sessione motore `SI_SESSION.v2`: HMAC-SHA256, variabili d'ambiente processo figlio, expiry 24h. |
| `uMachineFingerprint.pas` | Fingerprint macchina via WMI (CPU, board, disk) + Base32 per codici richiesta attivazione. |
| `uActivationRequest.pas` | Codice richiesta attivazione `RQ1` (JSON base64url con fingerprint + username). |
| `uBCryptApi.pas` | Dichiarazioni API Windows CNG (`bcrypt.dll`) per operazioni crittografiche native. |

---

## Projects/LicenseManager/

| Unità | Descrizione |
|-------|-------------|
| `LicenseManager.dpr` | Entry point tool gestione licenze. |
| `LicenseManagerMain.pas` | UI principale: crea licenze, preset 1/3/6/12 mesi, lifetime, lista `licenses.json`, decode chiavi. |
| `uLicenseRecordStore.pas` | Persistenza record licenza in `licenses.json` accanto all'exe (username, chiave, scadenza, flag active/lifetime). |

---

## Dipendenze chiave tra unità

```
uMainForm
  ├── uPipeEngine → uLicenseService → uLicenseCodec (Common)
  │                 └── uSessionAuth → uLicenseCodec (Common)
  ├── uAudioCapture → uWasapiCapture, uWasapi16k
  ├── uVoiceSegmenter
  ├── uGlobalKeyboardHook
  └── uAppSettings → uRegistryStore

uAppStartup → uPipeEngine, uInterviewProfile

uLicenseService → uLicenseCodec, uSessionAuth, uLicenseOnlineTime, uRegistryStore
uActivationRequest → uMachineFingerprint
```
