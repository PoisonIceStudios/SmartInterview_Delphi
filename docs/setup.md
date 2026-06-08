# Setup e build

[← Torna al README](../README.md) · [Architettura](architecture.md)

## Requisiti

| Componente | Versione |
|------------|----------|
| Windows | 10/11 x64 |
| RAD Studio | 12+ (Delphi, target Win64) |
| .NET SDK | 10 (runtime host per `SmartInterview.Engine.dll`) |
| GPU (consigliata) | NVIDIA con driver CUDA, oppure GPU Vulkan |

## Struttura directory

```
SmartInterview_Delphi/
├── Projects.groupproj          # Group project RAD Studio
├── Projects/
│   ├── SmartInterview/         # App principale
│   │   ├── SmartInterview.dpr
│   │   ├── SmartInterview.dproj
│   │   ├── src/                # Unità specifiche SmartInterview
│   │   └── Win64/Release/      # Output build (gitignored)
│   └── LicenseManager/         # Tool licenze
├── Common/                     # Unità Pascal condivise
├── Engine/                     # Motore C# (.NET 10)
└── docs/                       # Documentazione
```

## Build SmartInterview

1. Apri `Projects.groupproj` o `Projects/SmartInterview/SmartInterview.dproj` in RAD Studio.
2. Seleziona piattaforma **Win64** e configurazione **Release** (o Debug).
3. Compila.

Dopo ogni build Win64, il `.dproj` esegue automaticamente:

```text
dotnet build Engine\SmartInterview.Engine.csproj -c Release
```

Il target MSBuild `DeployEngineToDelphi` copia l'intero output (DLL, dipendenze .NET, runtime nativi CUDA/Vulkan/Whisper) in:

```text
Projects/SmartInterview/Win64/<Configuration>/EngineDeploy/
```

accanto a `SmartInterview.exe`.

### Contenuto EngineDeploy

| Elemento | Descrizione |
|----------|-------------|
| `SmartInterview.Engine.dll` | Assembly motore AI (entry point per `dotnet`) |
| `*.dll` dipendenze | LLamaSharp, Whisper.net, System.* |
| `runtimes\` | Backend nativi llama.cpp e whisper (CUDA12, Vulkan, CPU) |

Delphi avvia il motore con:

```text
dotnet "<percorso>\EngineDeploy\SmartInterview.Engine.dll"
```

via `uPipeEngine.Start` (`CreateProcess` + pipe stdin/stdout).

### Build manuale engine

Se all'avvio compare "Engine not found":

```powershell
cd C:\Users\devda\Documents\GitHub\SmartInterview_Delphi
dotnet build Engine\SmartInterview.Engine.csproj -c Release
```

Verificare che esista:

```text
Projects\SmartInterview\Win64\Release\EngineDeploy\SmartInterview.Engine.dll
```

### Build LicenseManager

1. Apri `Projects/LicenseManager/LicenseManager.dproj`.
2. Compila Win64 Release.
3. Output: `Projects/LicenseManager/Win64/Release/LicenseManager.exe`.

Il progetto risolve `uLicenseCodec` dalla cartella `Common/` (search path `..\..\Common\`).

## Common — unità Pascal condivise

La cartella `Common/` contiene unità `.pas` usate da **più progetti** Delphi nel repository.

### Convenzione

- Ogni nuovo progetto Delphi deve aggiungere `..\..\Common\` a `DCC_UnitSearchPath` nel file `.dproj`.
- Non duplicare le unità condivise nei singoli progetti: mettile in `Common/`.
- Le unità specifiche di un singolo progetto restano in `Projects/<NomeProgetto>/src/`.

### Unità attuali

| Unità | Descrizione |
|-------|-------------|
| `uLicenseCodec.pas` | Codifica/decodifica chiavi licenza v4 (Base32, HMAC, XOR). Usata da SmartInterview e LicenseManager. |
| `uLicenseOnlineTime.pas` | Fetch ora UTC online (worldtimeapi.org, timeapi.io). Obbligatoria per creazione e verifica licenze. |

### Search path (.dproj)

Per un progetto con cartella `src/` locale (es. SmartInterview):

```xml
<DCC_UnitSearchPath>..\..\Common\;src\;$(DCC_UnitSearchPath)</DCC_UnitSearchPath>
```

Per LicenseManager (senza cartella `src` locale):

```xml
<DCC_UnitSearchPath>..\..\Common\;$(DCC_UnitSearchPath)</DCC_UnitSearchPath>
```

## Prima esecuzione

1. Avvia `SmartInterview.exe`.
2. Inserisci licenza e username forum.
3. Accetta il disclaimer.
4. Al primo avvio lo splash scarica i modelli Whisper e LLM (può richiedere diversi GB e tempo in base alla connessione).
5. I modelli vengono salvati in `%LOCALAPPDATA%\SmartInterview\models\` o nella cartella `models\` accanto all'eseguibile.

**Connessione internet richiesta** per: verifica ora UTC della licenza, autenticazione sessione motore, download modelli.

## Risorse opzionali

- `Resources\splash.png` — immagine splash (opzionale, caricata a runtime se presente accanto all'exe).
- L'icona applicazione usa l'icona predefinita Delphi (nessun `app.ico` custom richiesto).

## Diagnostica

| Log | Percorso |
|-----|----------|
| Trascrizione live | `%LOCALAPPDATA%\SmartInterview\live-transcribe-diag.log` |
| Debug generale | `%LOCALAPPDATA%\SmartInterview\debug.log` |
| Motore (stderr) | Output diagnostico del processo `dotnet` figlio |

## Risoluzione problemi

| Problema | Soluzione |
|----------|-----------|
| `uLicenseCodec` not found (LicenseManager) | Verificare `DCC_UnitSearchPath` punti a `..\..\Common\` |
| Engine not found | Eseguire `dotnet build` sull'engine; verificare `EngineDeploy\SmartInterview.Engine.dll` |
| `unauthorized` dal motore | Verificare licenza valida, connessione internet (ora UTC), username forum corretto |
| GPU non usata | Controllare log stderr motore; su RTX 50xx usare Vulkan |
| Licenza non valida | Connessione internet richiesta per verifica ora UTC |
| Modelli mancanti | Controllare cartella `models\` o `%LOCALAPPDATA%\SmartInterview\models\` |
