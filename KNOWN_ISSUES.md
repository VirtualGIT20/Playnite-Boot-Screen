# Known issues

## Black screen after the overlay fades

A Playnite Fullscreen theme may create a fullscreen window but fail to render visible content on a virtual display. This can look like a frozen boot player even after the Playnite Boot Screen runtime has exited successfully.

Diagnostic steps:

1. Repeat the launch with Playnite's default Fullscreen theme.
2. Check `%APPDATA%\Playnite\playnite.log` and `extensions.log`.
3. Check the Playnite Boot Screen runtime log from the extension settings page.
4. Confirm whether `Launcher exited with code 0` appears.

The extension intentionally continues to support switching from an already open Playnite Desktop instance to Fullscreen mode.

## No emergency hotkey

Version 0.4.0 does not register a global termination shortcut. See `docs/TROUBLESHOOTING.md` for recovery commands.
