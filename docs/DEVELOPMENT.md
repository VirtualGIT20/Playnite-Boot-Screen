# Development

## Toolchain

- Windows 10 or 11
- Visual Studio 2022 or newer, or Visual Studio Build Tools
- .NET desktop build tools workload
- .NET Framework 4.6.2 SDK and Targeting Pack
- Playnite installed for runtime testing and Toolbox packaging

## Build

```powershell
.\scripts\build.ps1 -Configuration Release
```

The project uses the classic MSBuild format with `packages.config`. NuGet restores PlayniteSDK 6.16.0 into the local `packages` directory.

## Install a development build

Close Playnite completely:

```powershell
.\scripts\install-dev.ps1 -Configuration Release
```

The compiled extension is copied to:

```text
%APPDATA%\Playnite\Extensions\PlayniteBoot_71b5c099-3c25-4fe7-b26f-1262c7f0e138
```

## Design constraints

- Keep the plugin ID unchanged.
- Persist generated files only under `GetPluginUserDataPath()`.
- Keep Windows PowerShell 5.1 compatibility in the managed runtime.
- Preserve the existing Standalone and Preload/Continue behavior unless a change is explicitly documented.
- Add every user-facing string to both localization dictionaries.
