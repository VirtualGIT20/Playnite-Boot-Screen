# Playnite Boot Screen

[Italiano](README_IT.md) · [Changelog](CHANGELOG.md) · [Troubleshooting](docs/TROUBLESHOOTING.md)

![Playnite Boot Screen preview](docs/assets/boot-screen.png)

Playnite Boot Screen is a Playnite Generic Plugin that displays a configurable fullscreen boot video while Playnite Fullscreen starts in the background.

It also supports a generic streaming preload flow for Sunshine, Apollo, Vibeshine, Vibepollo, and compatible forks: the video can start in a **Prep** command before the client stream opens, then a **Detached** command launches Playnite behind the same overlay.

> This is an independent community extension and is not affiliated with or endorsed by the Playnite project.

## Features

- Managed video list for supported files in the persistent runtime media folder, while external video paths remain supported.
- Follow Playnite's Fullscreen display setting or choose a monitor manually, with safe multi-monitor readiness detection.
- Configurable scaling, fades, mute, and volume from 0 to 100.
- Reveal Playnite as soon as it is ready, or wait for the video to end naturally.
- Managed runtime stored outside the replaceable extension installation directory.
- Configurable Desktop and Start menu shortcut name.
- Streaming Preload and Continue commands shown directly in the settings page.
- English and Italian localization.
- Local diagnostic logs capped at 2 MiB with one backup.
- No telemetry, accounts, or network services.

## Requirements

- Windows 10 or 11.
- Playnite 10.
- Windows PowerShell 5.1.

The plugin targets .NET Framework 4.6.2 and Playnite SDK 6.16.0.

## Installation

### Published package

1. Download the latest `Playnite-Boot-Screen-v*.pext` file from the GitHub Releases page.
2. Open the file and allow Playnite to install it.
3. Restart Playnite.
4. Open **Add-ons → Extension settings → Generic → Playnite Boot Screen**.

### Development build

Close Playnite, then run:

```powershell
.\scripts\install-dev.ps1 -Configuration Release
```

## Direct launch

In **Installation and diagnostics**:

1. choose a shortcut name;
2. select **Create/update Desktop shortcut** or **Create/update Start shortcut**;
3. close Playnite completely;
4. launch the new shortcut.

The shortcut uses a hidden VBS bridge, so no PowerShell console should flash.

## Streaming integration

Enable streaming preload in the **Streaming** tab, then copy:

1. **Prep command — Preload**;
2. **Detached command — Continue**.

No Undo command is required. Preload starts a hidden host, selects the streaming display, opens the video, and exits only after the video is visible and advancing. Continue signals that host to launch Playnite behind the overlay.

See [Streaming setup](docs/STREAMING.md) for details and recovery guidance.

## Runtime data

Persistent files are stored under Playnite's extension data directory:

```text
%APPDATA%\Playnite\ExtensionsData\71b5c099-3c25-4fe7-b26f-1262c7f0e138\
├── Runtime\
│   ├── config.json
│   ├── media\
│   └── logs\
└── shortcut-state.json
```

The extension installation directory can be safely replaced during updates without deleting custom media, configuration, or logs.

Place `.mp4`, `.mkv`, `.webm`, `.avi`, or `.mov` files directly in `Runtime\media`, then use **Refresh list** in the settings page. Files outside this folder can still be selected with **Browse external…**.

## Build

Install Visual Studio or Visual Studio Build Tools with:

- .NET desktop build tools;
- .NET Framework 4.6.2 SDK;
- .NET Framework 4.6.2 Targeting Pack.

Then run:

```powershell
.\scripts\build.ps1 -Configuration Release
```

Package with the Toolbox supplied by Playnite:

```powershell
.\scripts\pack.ps1 -Configuration Release
```

The package is written to `dist` with a SHA-256 checksum.

## Releasing

The repository includes a tagged-release GitHub Actions workflow. See [Releasing](docs/RELEASING.md) before creating a tag.

## License

Source code is licensed under the [MIT License](LICENSE). Third-party names, logos, and trademarks remain the property of their respective owners; see [Third-party notices](THIRD_PARTY_NOTICES.md).
