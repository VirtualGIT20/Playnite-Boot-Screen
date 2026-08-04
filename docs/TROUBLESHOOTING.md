# Troubleshooting

## Recover from a persistent fullscreen black window

Version 0.4.0 does not install a global emergency hotkey.

On the host PC, open PowerShell and run:

```powershell
Stop-Process -Name Playnite.FullscreenApp -Force -ErrorAction SilentlyContinue

Get-CimInstance Win32_Process |
    Where-Object { $_.CommandLine -match 'PlayniteBoot\.ps1' } |
    ForEach-Object { Invoke-CimMethod -InputObject $_ -MethodName Terminate | Out-Null }
```

This closes Playnite Fullscreen and any remaining Playnite Boot Screen runtime host. It does not terminate Playnite Desktop unless Desktop is itself switching or shutting down.

## Logs

Playnite logs:

```text
%APPDATA%\Playnite\playnite.log
%APPDATA%\Playnite\extensions.log
```

Runtime logs are available through **Installation and diagnostics → Open logs**.

The active runtime log is limited to 2 MiB. When it reaches the limit, it is moved to `PlayniteBoot.log.1`; any older backup is replaced.

## Extension settings page crashes

Start Playnite with `--safestartup`, remove or replace the development extension build, then inspect `playnite.log` for binding or XAML exceptions.

## Build errors

- `Microsoft.NET.Sdk.WindowsDesktop not found`: use this repository's classic MSBuild project and install the .NET Framework 4.6.2 Targeting Pack.
- `System.Drawing.Rectangle` missing: ensure the current project file includes the `System.Drawing` reference.
