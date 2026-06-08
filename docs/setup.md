# Setup e build

[← Torna al README](../README.md) · [Architettura](architecture.md)

## Requisiti

| Componente | Versione |
|------------|----------|
| Windows | 10/11 x64 |
| RAD Studio | 12+ (Delphi, target Win64) |
| .NET SDK | 10 |
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

Dopo ogni build Win64, MSBuild esegue automaticamente:

```text
dotnet build Engine\SmartInterview.Engine.csproj -c Release
```

L'engine viene deployato in:

```text
Projects/SmartInterview/Win64/<Configuration>/EngineDeploy/
```

accanto a `SmartInterview.exe`.

### Build manuale engine

Se all'avvio compare "Engine not found":

```powershell
cd C:\Users\devda\Documents\GitHub\SmartInterview_Delphi
dotnet build Engine\SmartInterview.Engine.csproj -c Release
```

### Build LicenseManager

1. Apri `Projects/LicenseManager/LicenseManager.dproj`.
2. Compila Win64 Release.
3. Output: `Projects/LicenseManager/Win64/Release/LicenseManager.exe`.

Il progetto risolve `uLicenseCodec` dalla cartella `Common/` (search path `..\..\Common\`).

## Search path unità condivise

Per aggiungere un nuovo progetto Delphi che usa `Common/`:

```xml
<DCC_UnitSearchPath>..\..\Common\;$(DCC_UnitSearchPath)</DCC_UnitSearchPath>
```

Vedi [Common/README.md](../Common/README.md).

## Prima esecuzione

1. Avvia `SmartInterview.exe`.
2. Inserisci licenza e username forum.
3. Accetta il disclaimer.
4. Al primo avvio lo splash scarica i modelli Whisper e LLM (può richiedere diversi GB e tempo in base alla connessione).
5. I modelli vengono salvati in `%LOCALAPPDATA%\SmartInterview\models\` o nella cartella `models\` accanto all'eseguibile.

## Risorse opzionali

- `Resources\splash.png` — immagine splash (opzionale, caricata a runtime se presente accanto all'exe).
- L'icona applicazione usa l'icona predefinita Delphi (nessun `app.ico` custom richiesto).

## Diagnostica

| Log | Percorso |
|-----|----------|
| Trascrizione live | `%LOCALAPPDATA%\SmartInterview\live-transcribe-diag.log` |
| Debug generale | `%LOCALAPPDATA%\SmartInterview\debug.log` |
| Engine (stderr) | Console del processo figlio |

## Risoluzione problemi

| Problema | Soluzione |
|----------|-----------|
| `uLicenseCodec` not found (LicenseManager) | Verificare `DCC_UnitSearchPath` punti a `..\..\Common\` |
| Engine not found | Eseguire `dotnet build` sull'engine; verificare `EngineDeploy\` |
| BRCC32 app.ico | Risolto: rimosso riferimento a icona custom |
| GPU non usata | Controllare log engine; su RTX 50xx usare Vulkan |
| Licenza non valida | Connessione internet richiesta per verifica ora UTC |
