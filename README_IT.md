# Playnite Boot Screen

[English](README.md) · [Changelog](CHANGELOG.md) · [Risoluzione problemi](docs/TROUBLESHOOTING.md) · [Contratto integrazione](docs/INTEGRATION.md)

![Anteprima di Playnite Boot Screen](docs/assets/boot-screen.png)

Playnite Boot Screen è un'estensione Generic Plugin per Playnite che mostra un video di avvio a schermo intero mentre Playnite Fullscreen viene caricato in background e può coprire anche la transizione integrata di Playnite da Desktop a Fullscreen.

## Demo

https://github.com/user-attachments/assets/fc1d7d9a-7a05-4b44-a43e-959a9b4a4fad

## Funzioni

- Elenco gestito dei video supportati nella cartella media persistente, mantenendo anche i percorsi video esterni.
- Possibilità di seguire il display Fullscreen scelto da Playnite oppure selezionare manualmente il monitor, con rilevamento sicuro in configurazioni multi-monitor.
- Adattamento, fade, mute e volume da 0 a 100 configurabili.
- Possibilità di mostrare Playnite appena pronto, attendere la fine del video oppure ripeterlo in loop finché Playnite non è pronto.
- Copertura della transizione integrata Desktop → Fullscreen con il video configurato, attiva di default e disattivabile dalle impostazioni.
- Runtime gestito fuori dalla directory sostituita durante gli aggiornamenti dell'estensione.
- Nome e icona personalizzabili per i collegamenti Desktop e menu Start: Playnite Boot Screen, Playnite Fullscreen oppure un file `.ico` personalizzato.
- Comandi Preload e Continue nella schermata Streaming.
- Marker runtime pubblico per temi/helper che devono evitare intro di avvio duplicate.
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

In **Configurazione rapida**:

1. scegli nome e icona del collegamento;
2. seleziona **Crea/aggiorna** per il collegamento Desktop o menu Start;
3. chiudi completamente Playnite;
4. avvia il nuovo collegamento.

Il collegamento usa un bridge VBS nascosto, quindi non dovrebbe comparire alcuna console PowerShell.

## Streaming

Abilita il preload nella scheda **Streaming** e copia:

1. **Prep command — Preload**;
2. **Detached command — Continue**.

Non è richiesto un comando Undo. Preload prepara il decoder, quindi mette in pausa e riavvolge il video mantenendo nero l’overlay; Continue fa ripartire la riproduzione dall’inizio mentre l’host segue la readiness di Playnite. Consulta [Configurazione streaming](docs/STREAMING.md) per i dettagli.

## Integrazione con temi e helper

Mentre Playnite Boot Screen sta coprendo attivamente l'avvio, pubblica l'evento Windows segnalato `Local\PlayniteBootScreen.StartupIntroHandled.v1`. Temi e plugin helper possono usare questo marker per evitare di riprodurre una seconda intro nello stesso avvio senza leggere le impostazioni di Playnite Boot Screen. Il marker è indipendente dal video selezionato e dal comportamento di fine video.

Consulta il [contratto di integrazione](docs/INTEGRATION.md) per semantica esatta ed esempio C# lato consumer.

### Aniki ReMake / Aniki Helper

Aniki ReMake / Aniki Helper supporta il marker di avvio di PBS, quindi può evitare la propria intro quando Playnite Boot Screen sta già gestendo l'avvio. L'intro estesa di Aniki ReMake è inoltre inclusa come video opzionale e può essere selezionata dalla normale libreria multimediale di PBS.

L'integrazione non lega PBS ad Aniki: il marker è indipendente dal video selezionato e i video personalizzati o altri temi continuano a funzionare normalmente.

## Dati runtime

I file persistenti vengono salvati nella directory dati dell’estensione:

```text
%APPDATA%\Playnite\ExtensionsData\71b5c099-3c25-4fe7-b26f-1262c7f0e138\
├── Runtime\
│   ├── config.json
│   ├── media\
│   ├── cache\
│   │   └── video-compat\
│   └── logs\
├── shortcut-icons\
└── shortcut-state.json
```

La directory di installazione dell’estensione può essere sostituita senza eliminare video personalizzati, configurazione o log.
I file runtime gestiti vengono sincronizzati in base al contenuto all’avvio di Playnite, mentre video personalizzati, configurazione e log restano intatti.

Copia i file `.mp4`, `.mkv`, `.webm`, `.avi` o `.mov` direttamente in `Runtime\media`, quindi usa **Aggiorna elenco** nelle impostazioni. I file esterni alla cartella restano selezionabili tramite **Sfoglia esterno…**. I file WebM vengono esposti in modo trasparente alla pipeline multimediale di Windows tramite un alias `.mkv` in cache; il file originale non viene mai rinominato né modificato. La cache di compatibilità conserva solo l'alias relativo al WebM attualmente selezionato e viene svuotata quando si seleziona un video non WebM.

## Build e pacchetto

```powershell
.\scripts\build.ps1 -Configuration Release
.\scripts\pack.ps1 -Configuration Release
```

Il secondo comando usa `Toolbox.exe` fornito con Playnite e crea il `.pext` in `dist` insieme al checksum SHA-256.

## Licenza

Il codice sorgente è distribuito con [licenza MIT](LICENSE). Nomi, loghi e marchi di terze parti restano dei rispettivi proprietari; consulta [Third-party notices](THIRD_PARTY_NOTICES.md).
