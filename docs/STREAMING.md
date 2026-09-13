# Streaming setup

Playnite Boot Screen supports Sunshine, Apollo, and compatible forks without using a vendor-specific API.

## Commands

Copy the commands from the extension's **Streaming** tab.

- Configure the first command as **Prep**. It runs `PlayniteBoot.ps1 -Mode Preload`.
- Configure the second command as **Detached**. It runs `PlayniteBoot.ps1 -Mode Continue`.
- Do not add an Undo command for Playnite Boot Screen.

## Flow

1. Prep starts a hidden PowerShell host.
2. The host selects the target display, preferably matching the client resolution.
3. The boot video is opened and allowed to advance only long enough to validate that the decoder is producing frames.
4. The host pauses the video, rewinds it to the beginning, and keeps the overlay black; Prep can then exit while the streaming session continues opening.
5. Detached/Continue launches or adopts Playnite Fullscreen directly.
6. Continue signals the preload host, which restarts the video from the beginning, adopts the Playnite process, and keeps the overlay visible while tracking readiness.
7. The overlay fades after Playnite passes the configured readiness rules and the selected video-end policy allows it.

## Existing Playnite Desktop instance

An already open Playnite Desktop instance is supported. Playnite can receive the Fullscreen switch command and start its Fullscreen process normally. The extension does not close Desktop preemptively.

## Theme-related black screens

A Fullscreen theme can create a valid fullscreen window but fail to render visible content on a virtual display. The launcher cannot reliably inspect theme pixels. When a black screen persists after the runtime log reports a successful exit:

1. retry with Playnite's default Fullscreen theme;
2. inspect `playnite.log` and `extensions.log`;
3. compare the exact timestamps with the Playnite Boot Screen runtime log.

## Fallback

When no usable preload host is available, Continue uses the configured standalone fallback. This preserves the historical launcher behavior but cannot repair a Fullscreen theme or display driver that has failed to render.
