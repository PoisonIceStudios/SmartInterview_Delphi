# Motore C# (SmartInterview.Engine.dll)

[← Torna al README](../README.md) · [Architettura](architecture.md)

Il motore AI è un **assembly .NET 10** (`SmartInterview.Engine.dll`) avviato da Delphi come **processo figlio** tramite il runtime `dotnet`. La comunicazione avviene su **stdin/stdout JSON-lines** gestita da `uPipeEngine.pas`.

## Architettura bridge Delphi ↔ DLL

| Aspetto | Implementazione |
|---------|-----------------|
| Nome assembly | `SmartInterview.Engine.dll` |
| Entry point | `Program.cs` → `Main()` (loop stdin JSON) |
| Avvio | `CreateProcess(nil, 'dotnet "<dll>"', …)` in `uPipeEngine.Start` |
| IPC | Pipe anonime Windows su stdin/stdout del processo figlio |
| Licenza | Variabili d'ambiente + gate in `EngineSessionAuth.cs` |
| Deploy | `Win64\<Config>\EngineDeploy\` (copia automatica post-build) |

Delphi **non** usa `LoadLibrary`, COM o P/Invoke verso il motore: l'isolamento processo protegge l'app VCL da crash GPU/driver.

## Perché un processo separato (non in-process)?

- **Whisper.net** e **LLamaSharp** richiedono binding nativi a llama.cpp e whisper.cpp.
- Isolamento: crash GPU/driver non bloccano direttamente il processo VCL.
- Aggiornamenti modelli/backend senza ricompilare Delphi.

## Progetto e pacchetti

| File | Ruolo |
|------|-------|
| `Engine/Program.cs` | Host IPC: legge JSON da stdin, dispatch comandi, scrive risposte su stdout |
| `Engine/SmartInterview.Engine.csproj` | Progetto .NET 10 win-x64, pacchetti LLamaSharp + Whisper.net |

### Pacchetti principali

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
| `Program.cs` | Dispatcher comandi IPC, wiring Transcriber + LocalLlmClient, gate auth |
| `Transcriber.cs` | Wrapper Whisper.net: load model, transcribe, stream, warm-up, cancel |
| `LocalLlmClient.cs` | Client LLM: ChatML Qwen2.5, streaming token, memoria conversazione, classify utterance |
| `NativeBackendBootstrap.cs` | Selezione backend llama.cpp (CUDA/Vulkan/CPU) in base a GPU |
| `WhisperBackendBootstrap.cs` | Selezione backend Whisper analogo |
| `HardwareProbe.cs` | Rilevamento GPU NVIDIA, Blackwell RTX 50xx, VRAM |
| `GpuLoadTelemetry.cs` | Parsing log llama per layer GPU caricati |
| `ModelCatalog.cs` | Catalogo modelli LLM (URL, hash, dimensioni) |
| `WhisperModelCatalog.cs` | Catalogo modelli Whisper |
| `ModelDownloader.cs` | Download + verifica SHA256 modelli LLM |
| `WhisperModelDownloader.cs` | Download + verifica modelli Whisper |
| `AppPaths.cs` | Directory modelli; risolve `models\` accanto a SmartInterview.exe da EngineDeploy |
| `AppSettings.cs` | Enum tier intelligenza, lunghezza risposta (mirror Delphi) |
| `InterviewProfile.cs` | Record profilo colloquio per system prompt |
| `EngineSessionAuth.cs` | Validazione token sessione + licenza da env vars |
| `LicenseCodec.cs` | Mirror C# del codec licenza v4 (per validazione engine) |
| `MachineFingerprint.cs` | Mirror fingerprint macchina (per richieste attivazione, non sessione engine) |
| `RegistryStore.cs` | Accesso registry (uso interno engine se necessario) |
| `OnlineTime.cs` | Fetch ora UTC per validazione licenza |
| `VoiceSegmenter.cs` | Mirror VAD C# (l'app usa principalmente `uVoiceSegmenter.pas` Delphi) |
| `DebugLog.cs` | Log diagnostico engine |

## Protocollo IPC

Una riga JSON UTF-8 per richiesta (terminata da `\n`); risposte su stdout. Comandi streaming (`generate_stream`, `transcribe_stream`) emettono più righe prima del `result` finale.

### Comandi principali

| Comando | Scopo |
|---------|-------|
| `ping` | Health check |
| `startup` | Init completa: download/load Whisper + LLM, warm-up, profilo |
| `ensure_whisper` / `load_whisper` / `warmup_whisper` | Pipeline Whisper step-by-step (fallback legacy) |
| `transcribe` | PCM float32 base64 → testo |
| `transcribe_stream` | Trascrizione incrementale con eventi `transcribe_part` |
| `classify_utterance` | Modalità auto: è una domanda? |
| `generate_stream` | Streaming token risposta LLM |
| `reset` / `context_status` / `drop_last_exchange` | Memoria conversazione |
| `set_language` / `set_profile` / `set_answer_length` | Impostazioni runtime |
| `ensure_model` / `load_llm` / `warmup_llm` | Pipeline LLM step-by-step (fallback legacy) |
| `gpu_status` | Layer GPU caricati |
| `cancel_generation` / `cancel_transcribe` | Cancellazione operazioni in corso |
| `shutdown` | Termina processo (unico comando senza gate auth) |

### Formato richiesta (esempio)

```json
{"cmd":"transcribe","id":42,"samples_b64":"AAAA..."}
```

### Formato risposta risultato

```json
{"type":"result","id":42,"ok":true,"text":"..."}
```

### Eventi streaming/progresso

```json
{"type":"token","id":42,"token":"..."}
{"type":"transcribe_part","id":42,"text":"...","cumulative":"..."}
{"type":"progress","id":42,"phase":"whisper","progress":0.45}
{"type":"error","id":42,"error":"..."}
```

## Gate licenza (EngineSessionAuth)

Variabili d'ambiente impostate da `uPipeEngine.Start` tramite `SessionBuildChildEnvironment`:

| Variabile | Contenuto |
|-----------|-----------|
| `SMARTINTERVIEW_SESSION` | Token `SI_SESSION.v2.<expiry>.<user_b64>.<sig_b64>` |
| `SMARTINTERVIEW_LICENSE` | Chiave licenza completa |
| `SMARTINTERVIEW_USER` | Username forum normalizzato (lowercase) |

Flusso:

1. All'avvio: `TryAuthenticateFromEnvironment()` — se fallisce, `_authenticated = false`.
2. Ogni comando (eccetto `shutdown`): se `!IsAuthenticated` → `{ "ok": false, "error": "unauthorized" }`.
3. Comando `startup`: `TryConfirmStartupToken(session_token)` verifica corrispondenza col token d'ambiente.

Build Debug con `DIAGNOSTIC_LOG`: bypass auth per sviluppo locale.

## Discovery e deploy

### Percorsi ricerca DLL (`uPipeEngine.FindEngineDll`)

1. `EngineDeploy\SmartInterview.Engine.dll` accanto a `SmartInterview.exe`
2. `SmartInterview.Engine.dll` nella stessa cartella dell'exe
3. `Engine\bin\Release\net10.0-windows\win-x64\SmartInterview.Engine.dll` (sviluppo)
4. `Engine\bin\Debug\net10.0-windows\win-x64\SmartInterview.Engine.dll` (sviluppo)

### Deploy automatico

Dopo `dotnet build`, il target `DeployEngineToDelphi` in `.csproj` copia l'output completo in:

```text
Projects/SmartInterview/Win64/<Configuration>/EngineDeploy/
```

Include DLL native CUDA12, Vulkan, Whisper runtime. La build verifica la presenza dei backend nativi richiesti.

## Estendere l'IPC

Per un nuovo comando:

1. Handler in `Engine/Program.cs` (`HandleAsync`)
2. Wrapper in `uPipeEngine.pas` (`SendAndWait` + metodo pubblico)
3. Chiamata da `uMainForm.pas` (o altra unità UI)

Ricordare: i nuovi comandi AI devono rispettare il gate `EngineSessionAuth.IsAuthenticated`.
