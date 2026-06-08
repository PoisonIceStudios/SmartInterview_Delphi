# Sicurezza licenze — guida elementare

[← Torna al README](../README.md) · [Dettaglio tecnico](security-audit.md) · [Sistema licenze](licensing.md)

Questa pagina spiega **in modo semplice** come SmartInterview protegge l’accesso al software. Per implementazione e codice vedi gli altri documenti.

---

## In una frase

La chiave licenza è un “badge” firmato digitalmente dal venditore; l’app controlla che sia autentico, intestato al tuo username e non scaduto — usando l’**ora reale da internet**, non l’orologio del PC.

---

## Cosa contiene la chiave (v5, formato attuale)

Ogni nuova licenza inizia con **`SI5-`** ed include:

| Dato | A cosa serve |
|------|----------------|
| Username forum | Solo quella persona può usarla |
| Data di scadenza | Incorporata nella chiave (o “lifetime”) |
| Data di emissione | Quando è stata creata |
| Firma digitale | Prova che solo il LicenseManager (con chiave privata) l’ha generata |

L’app contiene solo la **chiave pubblica** (verifica). Chi può **creare** chiavi ha la chiave **privata** sul PC del venditore (`LicenseManager`).

---

## Quando serve internet?

| Momento | Internet obbligatorio? | Perché |
|---------|------------------------|--------|
| **Prima attivazione** | Sì | Serve l’ora UTC online per verificare la scadenza |
| **Ogni avvio** dell’app | Sì | Stesso controllo all’apertura |
| **Avvio motore AI** (Whisper/LLM) | Sì | L’engine ripete la verifica licenza + ora online |
| **Creazione licenza** (LicenseManager) | Sì | Data emissione/scadenza basate su UTC online |
| **Uso con app già aperta** | Non sempre | Vedi sotto “PC acceso a lungo” |

**Importante:** non devi stare online **ogni 24 ore** per forza. Se la licenza è valida, puoi lavorare offline per un po’ dopo l’ultimo controllo riuscito.

---

## Passaggi all’avvio (semplificati)

```
1. Apri SmartInterview
2. Legge chiave salvata nel registry (se c’è)
3. Chiede l’ora UTC a internet (worldtimeapi / timeapi.io)
   → senza rete: STOP, messaggio “serve connessione”
4. Decodifica la chiave SI5-…
5. Verifica la firma digitale (ECDSA) con la chiave pubblica nell’app
6. Controlla: username giusto? attiva? non scaduta rispetto all’ora UTC?
   → se scaduta: cancella la chiave salvata e mostra schermata attivazione
7. Se tutto OK → disclaimer → splash → motore AI
8. Prima di avviare il motore: crea un “pass temporaneo” (token sessione 24h)
   e lo passa al processo .NET insieme a licenza e username
9. Il motore rifà gli stessi controlli: senza pass valido, niente trascrizione né LLM
```

---

## Cosa succede se la licenza scade

| Situazione | Comportamento |
|------------|----------------|
| **Riavvii il PC** con licenza scaduta | All’apertura: controllo online → scaduta → registry pulito → **schermata nuova licenza** |
| **Tieni l’app aperta** e la data di scadenza passa | Controllo periodico (vedi sotto) → motore AI fermato → **schermata nuova licenza** o chiusura |
| **Chiave vecchia** dopo scadenza | Non basta cambiare data sul PC: serve una **nuova chiave** dal venditore (nuova data nel payload) |

---

## PC acceso a lungo (app non chiusa)

Per chi lascia SmartInterview aperto giorni senza spegnere il PC:

```
Ultimo controllo online riuscito
        │
        ▼
Ogni ~6 ore l’app prova di nuovo:
  • Se c’è internet → aggiorna l’ora UTC e ricontrolla la licenza
  • Se NON c’è internet → stima il tempo trascorso con un orologio interno
    (monotonic, non manipolabile come la data di Windows)
        │
        ▼
Se la licenza risulta scaduta (anche stimando offline) → stop AI + nuova attivazione
        │
        ▼
Se sei offline da più di 72 ore dall’ultimo check online → motore AI fermato
  finché non torni online (la licenza può essere ancora valida, ma serve un refresh)
```

**In pratica:**

- Puoi usare il software **offline** per un po’ dopo un check online riuscito (fino a ~72 ore).
- Non puoi tenerlo aperto **per sempre** senza mai riconnetterti.
- Non puoi evitare la scadenza **solo** cambiando la data di Windows.

---

## Chi fa cosa (ruoli)

| Attore | Ruolo |
|--------|--------|
| **LicenseManager** | Crea chiavi `SI5-…` firmate; tiene la chiave privata |
| **SmartInterview.exe** | Verifica licenza, ora online, controlli periodici |
| **SmartInterview.Engine.dll** | Secondo controllo: senza licenza valida, niente AI |
| **Server ora (HTTPS)** | Fornisce UTC affidabile per la scadenza |

---

## Cosa NON fa il sistema (limiti onesti)

- **Non lega la licenza al PC** — solo al username forum (il codice macchina `RQ1` è per supporto, non per bloccare la chiave).
- **Non richiede un server licenze** tuo — tutto offline dopo la verifica, salvo i check ora/scadenza.
- **Chiavi v4 vecchie** (32 caratteri senza `SI5-`) sono ancora accettate ma meno sicure; le nuove emissioni usano v5.

---

## Test rapido consigliato

1. Genera chiavi: `dotnet run --project tools/KeyGen`
2. Compila LicenseManager → crea licenza con internet
3. Incolla in SmartInterview → deve attivarsi
4. Crea licenza scaduta ieri → riavvia online → deve chiedere nuova chiave

---

## Riferimenti codice (manutentori)

| Funzione | File |
|----------|------|
| Verifica licenza app | `uLicenseService.pas` |
| Ora online | `Common/uLicenseOnlineTime.pas` |
| Codec v5 + firma | `Common/uLicenseCodecV5.pas`, `uLicenseEcdsa.pas` |
| Controllo periodico | `Common/uLicenseMonitor.pas`, timer in `uMainForm.pas` |
| Gate motore | `Engine/EngineSessionAuth.cs` |
| Emissione chiavi | `LicenseManagerMain.pas`, `uLicenseEcdsaSign.pas` |
