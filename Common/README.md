# Common — unità Pascal condivise

Cartella per unità `.pas` usate da **più progetti** Delphi nel repository.

## Convenzione

- Ogni nuovo progetto Delphi deve aggiungere `..\..\Common\` a `DCC_UnitSearchPath` nel file `.dproj`.
- Non duplicare le unità condivise nei singoli progetti: mettile qui.
- Le unità specifiche di un singolo progetto restano in `Projects/<NomeProgetto>/src/`.

## Unità attuali

| Unità | Descrizione |
|-------|-------------|
| `uLicenseCodec.pas` | Codifica/decodifica chiavi licenza v4 (Base32, HMAC, XOR). Usata da SmartInterview e LicenseManager. |

## Esempio search path (.dproj)

```xml
<DCC_UnitSearchPath>..\..\Common\;src\;$(DCC_UnitSearchPath)</DCC_UnitSearchPath>
```

Per LicenseManager (senza cartella `src` locale):

```xml
<DCC_UnitSearchPath>..\..\Common\;$(DCC_UnitSearchPath)</DCC_UnitSearchPath>
```
