# Troubleshooting

## Close a persistent boot overlay

Press **Alt+F4** while the Playnite Boot Screen overlay is active. This cancels the boot sequence and also stops the Playnite Fullscreen process launched by that sequence.

Press **Alt+Tab** instead when you only want to move the overlay into the background and continue launching Playnite. The mouse cursor is restored after the explicit Alt+Tab.

If the overlay or host process is no longer responding, open PowerShell on the host PC and run:

```powershell
Get-CimInstance Win32_Process |
    Where-Object { $_.CommandLine -match 'PlayniteBoot\.ps1' } |
    ForEach-Object { Invoke-CimMethod -InputObject $_ -MethodName Terminate | Out-Null }
```

If Playnite Fullscreen is still present after a failed cancellation, run:

```powershell
Stop-Process -Name Playnite.FullscreenApp -Force -ErrorAction SilentlyContinue
```

These commands do not terminate Playnite Desktop unless Desktop is itself switching or shutting down.

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
