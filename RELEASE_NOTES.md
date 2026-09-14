# Playnite Boot Screen 0.8.0

Version 0.8.0 focuses on predictable video completion, cleaner streaming startup, WebM compatibility, and better cooperation with Fullscreen themes and helpers.

## Highlights

- **New video-end behavior controls** — reveal Playnite as soon as it is ready, wait for the video to finish, or loop until Playnite is ready.
- **WebM compatibility** — WebM files are exposed to the Windows media pipeline through a local MKV compatibility alias, without transcoding or FFmpeg.
- **Improved Sunshine / Apollo / VibePollo startup** — Preload primes and rewinds the decoder, then Continue restarts playback from the beginning.
- **Aniki ReMake / Aniki Helper integration** — compatible helpers can detect when PBS is already handling the startup intro and avoid playing a duplicate intro.
- **Optional Aniki ReMake intro included** — the extended intro is bundled as a selectable video while custom media remains fully supported.
- **Safer streaming failure handling** — an abandoned Preload now closes after 10 seconds, and a new Continue-entry log helps diagnose rare Detached launch failures.

## Aniki ReMake integration

Playnite Boot Screen now publishes `Local\PlayniteBootScreen.StartupIntroHandled.v1` while it is actively handling startup. Aniki Helper can use this marker to suppress its own startup intro for that launch, avoiding two intro videos back to back.

The integration is independent from the selected video: the bundled extended Aniki ReMake intro is optional, and PBS continues to work normally with custom videos and other themes.

## Compatibility

Existing 0.7.x playback settings are migrated automatically. Existing shortcuts, custom media, and streaming configuration remain compatible.

Runtime updated to 1.0.9.
