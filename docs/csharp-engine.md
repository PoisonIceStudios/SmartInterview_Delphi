# Motore C# (SmartInterview.Engine)

[← Torna al README](../README.md) · [Architettura](architecture.md)

Il motore AI non è una DLL caricata in-process da Delphi, ma un **subprocesso .NET 10** (`SmartInterview.Engine.exe`) comunicante via **stdin/stdout JSON-lines**.

## Perché un subprocesso?

- **Whisper.net** e **LLamaSharp** sono ecosystem .NET con binding nativi a llama.cpp e whisper.cpp.
- Isolamento: crash GPU/driver non bloccano direttamente il processo VCL.
- Aggiornamenti modelli/backend senza ricompilare Delphi.

## Entry point

| File | Ruolo |
|------|-------|
| `Engine/Program.cs` | Host IPC: legge JSON da stdin, dispatch comandi, scrive risposte su stdout |
| `Engine/SmartInterview.Engine.csproj` | Progetto .NET 10 win-x64, pacchetti LLamaSharp + Whisper.net |

## Pacchetti principali

| Pacchetto | Uso |
|-----------|-----|
| LLamaSharp 0.27 | Inferenza LLM Qwen2.5 GGUF |
| LLamaSharp.Backend.Cuda12 | Backend NVIDIA |
| LLamaSharp.Backend.Vulkan | Backend Vulkan (AMD, Intel, Blackwell) |
| LLamaSharp.Backend.Cpu | Fallback CPU |
| Whisper.net 1.9 | Trascrizione speech-to-text |
| Whisper.net.Runtime.* | Runtime CUDA/Vulkan/CPU per Whisper |
| System.Management | WMI per `HardwareProbe` |

## Moduli C#

| File | Descrizione |
|------|-------------|
| `Program.cs` | Dispatcher comandi IPC, wiring Transcriber + LocalLlmClient |
| `Transcriber.cs` | Wrapper Whisper.net: load model, transcribe, stream, warm-up, cancel |
| `LocalLlmClient.cs` | Client LLM in-process: ChatML Qwen2.5, streaming token, memoria conversazione, classify utterance |
| `NativeBackendBootstrap.cs` | Selezione backend llama.cpp (CUDA/Vulkan/CPU) in base a GPU |
| `WhisperBackendBootstrap.cs` | Selezione backend Whisper analogo |
| `HardwareProbe.cs` | Rilevamento GPU NVIDIA, Blackwell RTX 50xx, VRAM |
| `GpuLoadTelemetry.cs` | Parsing log llama per layer GPU caricati |
| `ModelCatalog.cs` | Catalogo modelli LLM (URL, hash, dimensioni) |
| `WhisperModelCatalog.cs` | Catalogo modelli Whisper |
| `ModelDownloader.cs` | Download + verifica SHA256 modelli LLM |
| `WhisperModelDownloader.cs` | Download + verifica modelli Whisper |
| `AppPaths.cs` | Directory modelli e path runtime |
| `AppSettings.cs` | Enum tier intelligenza, lunghezza risposta (mirror Delphi) |
| `InterviewProfile.cs` | Record profilo colloquio per system prompt |
| `EngineSessionAuth.cs` | Validazione token sessione da env vars |
| `LicenseCodec.cs` | Mirror C# del codec licenza (per validazione engine) |
| `MachineFingerprint.cs` | Mirror fingerprint macchina |
| `RegistryStore.cs` | Accesso registry (uso interno engine se necessario) |
| `OnlineTime.cs` | Verifica ora UTC |
| `VoiceSegmenter.cs` | Segmentazione VAD lato engine (se usata) |
| `DebugLog.cs` | Log diagnostico engine |

## Protocollo IPC

Una riga JSON per richiesta; risposte su stdout (streaming: più righe per `generate_stream`).

### Comandi principali

| Comando | Scopo |
|---------|-------|
| `ping` | Health check |
| `startup` | Init completa: download/load Whisper + LLM, warm-up, profilo |
| `transcribe` | PCM float32 base64 → testo |
| `transcribe_stream` | Trascrizione incrementale con eventi `transcribe_part` |
| `classify_utterance` | Modalità auto: è una domanda? |
| `generate_stream` | Streaming token risposta LLM |
| `reset` / `context_status` | Memoria conversazione + % riempimento contesto UI |
| `set_language` / `set_profile` / `set_answer_length` | Impostazioni runtime |
| `gpu_status` | Layer GPU caricati |
| `shutdown` | Termina processo |

### Formato richiesta (esempio)

```json
{"cmd":"transcribe","id":42,"samples_b64":"AAAA..."}
```

### Formato risposta

```json
{"type":"result","id":42,"ok":true,"text":"..."}
```

Eventi progresso/stream:

```json
{"type":"event","id":42,"event":"token","data":{"token":"..."}}
```

## Autenticazione

Variabili d'ambiente impostate da `uPipeEngine` all'avvio:

| Variabile | Contenuto |
|-----------|-----------|
| `SMARTINTERVIEW_SESSION` | Token `SI_SESSION.v2...` |
| `SMARTINTERVIEW_LICENSE` | Chiave licenza |
| `SMARTINTERVIEW_USER` | Username forum normalizzato |

`EngineSessionAuth.cs` valida prima di ogni comando (eccetto shutdown).

## Deploy

Dopo `dotnet build`, il target `DeployEngineToDelphi` copia l'output in:

```text
Projects/SmartInterview/Win64/<Configuration>/EngineDeploy/
```

Include DLL native CUDA12, Vulkan, Whisper runtime.

Delphi cerca l'engine in ordine (`uPipeEngine.FindEngineExe`):

1. `<exe>\EngineDeploy\SmartInterview.Engine.exe`
2. `<exe>\SmartInterview.Engine.exe`
3. Path relativi verso `Engine\bin\...\`

## Estendere l'IPC

Per un nuovo comando:

1. Handler in `Engine/Program.cs`
2. Wrapper in `uPipeEngine.pas`
3. Chiamata da `uMainForm.pas` (o altra unità UI)
