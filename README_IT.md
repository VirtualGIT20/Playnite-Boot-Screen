# Playnite Boot Screen

[English](README.md) · [Changelog](CHANGELOG.md) · [Risoluzione problemi](docs/TROUBLESHOOTING.md)

![Anteprima di Playnite Boot Screen](docs/assets/boot-screen.png)

Playnite Boot Screen è un'estensione Generic Plugin per Playnite che mostra un video di avvio a schermo intero mentre Playnite Fullscreen viene caricato in background.

Supporta anche un flusso di preload generico per Sunshine, Apollo, Vibeshine, Vibepollo e fork compatibili: il video può partire tramite comando **Prep** prima dell'apertura dello stream, mentre un comando **Detached** avvia Playnite dietro lo stesso overlay.

> Estensione indipendente della community, non affiliata né approvata dal progetto Playnite.

## Funzioni

- Video, monitor, adattamento, fade, mute e volume da 0 a 100 configurabili.
- Possibilità di mostrare Playnite appena pronto oppure attendere la fine naturale del video.
- Runtime gestito fuori dalla directory sostituita durante gli aggiornamenti dell'estensione.
- Nome personalizzabile per i collegamenti Desktop e menu Start.
- Comandi Preload e Continue nella schermata Streaming.
- Interfaccia in inglese e italiano.
- Log locali limitati a 2 MiB con un solo backup.
- Nessuna telemetria, account o servizio di rete.

## Requisiti

- Windows 10 o 11.
- Playnite 10.
- Windows PowerShell 5.1.

Il plugin usa .NET Framework 4.6.2 e Playnite SDK 6.16.0.

## Installazione

1. Scarica il file `Playnite-Boot-Screen-v*.pext` più recente dalla pagina Releases di GitHub.
2. Apri il file e consenti a Playnite di installarlo.
3. Riavvia Playnite.
4. Apri **Componenti aggiuntivi → Impostazioni estensioni → Generico → Playnite Boot Screen**.

Per una build di sviluppo, chiudi Playnite ed esegui:

```powershell
.\scripts\install-dev.ps1 -Configuration Release
```

## Avvio diretto

In **Installazione e diagnostica**:

1. scegli il nome del collegamento;
2. seleziona **Crea/aggiorna collegamento Desktop** oppure **Crea/aggiorna collegamento Start**;
3. chiudi completamente Playnite;
4. avvia il nuovo collegamento.

Il collegamento usa un bridge VBS nascosto, quindi non dovrebbe comparire alcuna console PowerShell.

## Streaming

Abilita il preload nella scheda **Streaming** e copia:

1. **Prep command — Preload**;
2. **Detached command — Continue**.

Non è richiesto un comando Undo. Consulta [Configurazione streaming](docs/STREAMING.md) per i dettagli.

## Dati runtime

I file persistenti vengono salvati nella directory dati dell’estensione:

```text
%APPDATA%\Playnite\ExtensionsData\71b5c099-3c25-4fe7-b26f-1262c7f0e138\
├── Runtime\
│   ├── config.json
│   ├── media\
│   └── logs\
└── shortcut-state.json
```

La directory di installazione dell’estensione può essere sostituita senza eliminare video personalizzati, configurazione o log.

## Build e pacchetto

```powershell
.\scripts\build.ps1 -Configuration Release
.\scripts\pack.ps1 -Configuration Release
```

Il secondo comando usa `Toolbox.exe` fornito con Playnite e crea il `.pext` in `dist` insieme al checksum SHA-256.

## Licenza

Il codice sorgente è distribuito con [licenza MIT](LICENSE). Nomi, loghi e marchi di terze parti restano dei rispettivi proprietari; consulta [Third-party notices](THIRD_PARTY_NOTICES.md).
