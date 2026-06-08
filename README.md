# SmartInterview

**Copilota AI locale per colloqui tecnici su Windows.**

SmartInterview cattura l'audio di sistema (e opzionalmente il microfono), lo trascrive in locale con **Whisper**, e genera risposte in streaming da un modello **Qwen2.5** (GGUF) — tutto **senza API cloud** durante il colloquio.

| Stack | Tecnologia |
|-------|------------|
| Interfaccia | Delphi 12 VCL (Win64) |
| Motore AI | Assembly .NET 10 `SmartInterview.Engine.dll` (host `dotnet`) |
| Speech-to-text | Whisper.net |
| LLM | LLamaSharp / llama.cpp (CUDA12, Vulkan, CPU) |

---

## Documentazione

| Documento | Contenuto |
|-----------|-----------|
| [Architettura](docs/architecture.md) | Diagrammi, flussi, modalità ascolto, GPU backends, gate licenza |
| [Setup e build](docs/setup.md) | Requisiti, compilazione, prima esecuzione, troubleshooting |
| [Riferimento unità Pascal](docs/pas-reference.md) | Descrizione di ogni file `.pas` |
| [Motore C# / DLL](docs/csharp-dll.md) | Assembly Engine, protocollo JSON, moduli `.cs` |
| [Sistema licenze](docs/licensing.md) | Codec v4, attivazione, token sessione, LicenseManager |
| [Unità condivise Common](docs/setup.md#common--unità-pascal-condivise) | Convenzioni per `.pas` multi-progetto |

---

## Struttura repository

```
SmartInterview_Delphi/
├── Projects.groupproj              # Group project (SmartInterview + LicenseManager)
├── Projects/
│   ├── SmartInterview/             # Applicazione principale
│   │   ├── SmartInterview.dpr/.dproj
│   │   ├── uMainForm.*             # Overlay colloquio
│   │   ├── uFrm*.pas               # Form (licenza, splash, settings, …)
│   │   └── src/                    # Unità Delphi (audio, bridge engine, settings)
│   └── LicenseManager/             # Tool generazione licenze
├── Common/                         # Unità Pascal condivise (es. uLicenseCodec)
├── Engine/                         # Motore C# (.NET 10)
│   ├── Program.cs                  # Entry point JSON stdin/stdout
│   ├── SmartInterview.Engine.csproj
│   └── *.cs
├── docs/                           # Documentazione dettagliata
└── README.md                       # Questo file
```

---

## Come funziona (in breve)

```mermaid
flowchart TB
  subgraph Delphi["SmartInterview.exe (Delphi)"]
    UI[uMainForm]
    Pipe[uPipeEngine]
    Lic[uLicenseService]
    UI --> Pipe
    Lic -->|token + env vars| Pipe
  end
  subgraph Host["Processo figlio dotnet"]
    DLL[SmartInterview.Engine.dll]
    Auth[EngineSessionAuth]
    Auth -->|gate licenza| DLL
  end
  Pipe -->|CreateProcess + pipe| Host
  Pipe <-->|JSON stdin/stdout| DLL
  UI --> Audio[WASAPI 16 kHz]
```

1. **Avvio** — verifica licenza, disclaimer, splash con download/caricamento modelli.
2. **Motore** — `uPipeEngine` avvia `dotnet SmartInterview.Engine.dll` dalla cartella `EngineDeploy\`, passando token di sessione e chiave licenza via variabili d'ambiente.
3. **Ascolto** — manuale (tieni Ctrl/Shift/Alt) o automatico (VAD su audio di sistema).
4. **Trascrizione** — PCM inviato al motore via IPC `transcribe` / `transcribe_stream`.
5. **Risposta** — LLM locale in streaming (`generate_stream`); in modalità auto, `classify_utterance` filtra le non-domande.

Il motore **rifiuta tutti i comandi AI** senza autenticazione licenza valida. Dettagli in [Architettura → Gate licenza](docs/architecture.md#gate-licenza-motore-ai).

---

## Modelli AI

I modelli **non** sono nel repository. Al primo avvio vengono scaricati in `<exe>\models` o `%LOCALAPPDATA%\SmartInterview\models`.

| Tier | LLM (file locale) | Whisper (file locale) |
|------|-------------------|------------------------|
| Fast | `response-fast.bin` (Qwen2.5-3B Q4_K_M) | `whisper-fast.bin` (ggml-small) |
| Balanced | `response-balanced.bin` (Qwen2.5-7B) | `whisper-balanced.bin` (ggml-medium) |
| Max | `response-max.bin` (Qwen2.5-14B) | `whisper-max.bin` (ggml-large-v3) |

Il tier viene scelto in base alla GPU/VRAM rilevata (`HardwareProbe` + impostazioni utente).

### Backend GPU

| GPU | Ordine preferenza LLM |
|-----|----------------------|
| NVIDIA (non-Blackwell) | CUDA12 → Vulkan → CPU |
| NVIDIA Blackwell (RTX 50xx) | Vulkan → CPU |
| Altro | Vulkan → CPU |

---

## Build rapida

**Requisiti:** RAD Studio 12+ (Delphi Win64), .NET SDK 10, Windows x64.

1. Apri `Projects.groupproj` in RAD Studio.
2. Compila **SmartInterview** (Win64).
3. La build Delphi esegue automaticamente `dotnet build` sull'engine e deploya l'output in `Projects/SmartInterview/Win64/<Config>/EngineDeploy/`.

Build manuale engine:

```powershell
dotnet build Engine\SmartInterview.Engine.csproj -c Release
```

Guida completa: [docs/setup.md](docs/setup.md).

---

## Progetti Delphi

| Progetto | Scopo | Output |
|----------|-------|--------|
| **SmartInterview** | App colloquio | `Projects/SmartInterview/Win64/Release/SmartInterview.exe` |
| **LicenseManager** | Tool licenze (interno) | `Projects/LicenseManager/Win64/Release/LicenseManager.exe` |

Entrambi risolvono le unità condivise da `Common/` (search path `..\..\Common\`).

---

## Impostazioni utente

Salvate nel registry `HKCU\Software\SmartInterview` (`uRegistryStore.pas`):

- Lingua (default `en`)
- Tier modelli LLM e Whisper
- Lunghezza risposta (breve/medio/lungo)
- Tasto ascolto (Ctrl/Shift/Alt)
- Opacità overlay
- Profilo colloquio (ruolo, stack, job, esperienza)
- Parametri VAD (soglia, silenzio)

---

## Note per manutentori

- **Discovery motore:** `uPipeEngine.FindEngineDll` cerca `SmartInterview.Engine.dll` in `EngineDeploy\` accanto a `SmartInterview.exe`.
- **Avvio motore:** `CreateProcess` con comando `dotnet "<path>\SmartInterview.Engine.dll"` e pipe stdin/stdout per IPC JSON-lines.
- **Gate licenza:** variabili `SMARTINTERVIEW_SESSION`, `SMARTINTERVIEW_LICENSE`, `SMARTINTERVIEW_USER` + validazione in `EngineSessionAuth.cs`.
- **Memoria conversazione:** RAM in `LocalLlmClient.cs`; baseline tokens esclusi dalla % contesto UI.
- **Manuale vs auto:** la cattura manuale risponde sempre; l'auto usa `classify_utterance` + marker `[[SKIP]]`.
- **Nuovo comando IPC:** handler in `Engine/Program.cs` → wrapper `uPipeEngine.pas` → caller `uMainForm.pas`.
- **Unità condivise:** mettere in `Common/`, non duplicare tra progetti.
- **Diagnostica trascrizione:** `%LOCALAPPDATA%\SmartInterview\live-transcribe-diag.log`.

---

## Licenza software

SmartInterview richiede una chiave licenza valida all'avvio. Per generare chiavi usare **LicenseManager** (tool interno). Vedi [docs/licensing.md](docs/licensing.md).
