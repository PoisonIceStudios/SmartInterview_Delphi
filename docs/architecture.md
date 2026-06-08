# Architettura SmartInterview

[← Torna al README](../README.md)

## Panoramica

SmartInterview è un copilota desktop per colloqui tecnici su Windows. L'applicazione cattura l'audio di sistema (e opzionalmente il microfono), lo trascrive localmente con **Whisper**, e genera risposte in streaming da un modello **Qwen2.5 GGUF** caricato in locale. Durante il colloquio **non** vengono usate API cloud.

Lo stack è ibrido:

| Componente | Tecnologia | Ruolo |
|------------|------------|-------|
| Interfaccia utente | Delphi 12 VCL (Win64) | Overlay, hotkey, tray, cattura audio WASAPI, licensing |
| Motore AI | .NET 10 (`SmartInterview.Engine.exe`) | Whisper.net + LLamaSharp (llama.cpp) |
| Comunicazione | Pipe stdin/stdout, JSON-lines | IPC tra Delphi e Engine |

```
┌─────────────────────────────────────────────────────────────┐
│                    SmartInterview.exe (Delphi)               │
│  ┌──────────┐  ┌─────────────┐  ┌────────────────────────┐ │
│  │ uMainForm│  │uAudioCapture│  │ uGlobalKeyboardHook    │ │
│  │ overlay  │  │ WASAPI 16kHz│  │ Ctrl/Shift/Alt hold    │ │
│  └────┬─────┘  └──────┬──────┘  └────────────────────────┘ │
│       │               │ PCM float32                            │
│       ▼               ▼                                      │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              uPipeEngine (spawn + JSON IPC)              │ │
│  └──────────────────────────┬──────────────────────────────┘ │
└─────────────────────────────┼────────────────────────────────┘
                              │ stdin/stdout JSON-lines
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              SmartInterview.Engine.exe (.NET 10)             │
│  ┌──────────────┐  ┌────────────────┐  ┌─────────────────┐ │
│  │ Transcriber  │  │ LocalLlmClient │  │ HardwareProbe   │ │
│  │ Whisper.net  │  │ LLamaSharp     │  │ CUDA/Vulkan/CPU │ │
│  └──────────────┘  └────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Progetti nel repository

| Progetto | Percorso | Scopo |
|----------|----------|-------|
| SmartInterview | `Projects/SmartInterview/` | Applicazione principale |
| LicenseManager | `Projects/LicenseManager/` | Tool interno per generare/gestire licenze |
| Engine | `Engine/` | Subprocess C# per AI |
| Common | `Common/` | Unità Pascal condivise |
| Group project | `Projects.groupproj` | Build di entrambi i progetti Delphi |

## Flusso di avvio

1. **Mutex single-instance** — una sola istanza dell'app.
2. **Licenza** (`uFrmLicense` → `uLicenseService`) — verifica chiave + ora UTC online.
3. **Disclaimer** (`uFrmDisclaimer`) — accettazione obbligatoria.
4. **Setup colloquio** (`uFrmInterviewSetup`) — prompt opzionale profilo.
5. **Splash** (`uFrmSplash` → `uAppStartup.RunInitialStartup`):
   - Avvia `SmartInterview.Engine.exe` da `Win64\<Config>\EngineDeploy\`.
   - IPC `ping` → `startup`: download/caricamento modelli Whisper + LLM, warm-up, profilo.
6. **Main form** — riusa l'engine già avviato dallo splash.

## Autenticazione sessione Engine

L'engine rifiuta i comandi AI senza un token di sessione valido:

1. Delphi costruisce `SI_SESSION.v2.<expiry>.<machineId>.<hmac>` (`uSessionAuth.pas`).
2. All'avvio del processo figlio, Delphi imposta le variabili d'ambiente `SMARTINTERVIEW_SESSION`, `SMARTINTERVIEW_LICENSE`, `SMARTINTERVIEW_USER`.
3. L'engine valida HMAC + fingerprint macchina + scadenza (`Engine/EngineSessionAuth.cs`) prima di ogni comando.
4. Il comando `startup` invia anche `session_token` per ridondanza.

Build Debug dell'engine (`DIAGNOSTIC_LOG`) permettono test locali senza variabili d'ambiente.

## Modalità di ascolto

### Manuale (tieni premuto Ctrl/Shift/Alt)

- Cattura audio finché il tasto è premuto.
- Anteprima live ogni ~450 ms (trascrizione full-buffer).
- Al rilascio: trascrizione finale → risposta sempre generata (`StreamAnswer` forzato).

### Automatica (VAD)

- `TVoiceSegmenter` segmenta l'audio di sistema per attività vocale.
- Anteprima live durante il segmento.
- A fine segmento: `classify_utterance` → salta non-domande/duplicati → streaming risposta (rispetta `[[SKIP]]`).

## Rilevamento hardware e backend GPU

`Engine/HardwareProbe.cs` rileva GPU NVIDIA (incluso Blackwell RTX 50xx).

`Engine/NativeBackendBootstrap.cs` seleziona il backend llama.cpp:

| GPU | Ordine LLM |
|-----|------------|
| NVIDIA (non-Blackwell) | CUDA12 → Vulkan → CPU |
| NVIDIA Blackwell (RTX 50xx) | Vulkan → CPU |
| Altro | Vulkan → CPU |

Whisper usa backend analoghi via `WhisperBackendBootstrap.cs` (CUDA12/Vulkan/CPU).

## Modelli

I modelli **non** sono nel repository. Al primo avvio vengono scaricati in:

- `<exe>\models\`, oppure
- `%LOCALAPPDATA%\SmartInterview\models\`

Cataloghi: `Engine/ModelCatalog.cs`, `Engine/WhisperModelCatalog.cs` (mirror Delphi in `uModelCat.pas`, `uWhisperCat.pas`).

| Tier | LLM | Whisper |
|------|-----|---------|
| Fast | Qwen2.5-3B Q4_K_M | ggml-small |
| Balanced | Qwen2.5-7B | ggml-medium |
| Max | Qwen2.5-14B | ggml-large-v3 |

## Impostazioni persistenti

Registry via `uRegistryStore.pas`: lingua, tier modelli, lunghezza risposta, tasto ascolto, opacità overlay, profilo colloquio (ruolo/stack/job/experienza), parametri VAD.

## Documentazione correlata

- [Setup e build](setup.md)
- [Motore C# / IPC](csharp-engine.md)
- [Riferimento unità Pascal](pas-reference.md)
- [Sistema licenze](licensing.md)
