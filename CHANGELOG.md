# Changelog

All notable changes are documented here. Versions follow the Playnite extension manifest format.

## [Unreleased]

## [0.8.0] - 2026-09-14

### Added

- Three explicit video-end behaviors: reveal Playnite as soon as it is ready, wait for the video to finish, or loop until Playnite is ready.
- Transparent WebM compatibility playback through a local MKV alias/cache without transcoding or FFmpeg.
- Public `Local\PlayniteBootScreen.StartupIntroHandled.v1` integration marker for themes and helper extensions that need to suppress duplicate startup intros.
- Aniki ReMake extended startup intro as an optional bundled video.

### Changed

- Streaming Preload now primes the decoder while the overlay stays hidden, then pauses and rewinds playback so Continue starts the intro from the beginning.
- Bundled videos are seeded into the persistent runtime media library without overwriting existing user files.
- Video settings now use a single mutually exclusive playback selector and explicitly list MP4, MKV, WebM, AVI, and MOV.
- The streaming Host now abandons a missing Continue command after 10 seconds instead of 30 seconds.
- Added an early Continue-entry diagnostic log for failed streaming Detached launches.
- Runtime updated to 1.0.9.

### Fixed

- A video ending before Playnite is ready now keeps its final frame instead of exposing the media element's end-of-stream surface.
- Wait mode no longer seeks backward to the held final frame when Playnite is already ready and the video finishes naturally.
- Streaming Preload no longer consumes the beginning of the startup video before the client session continues.
- Desktop-to-Fullscreen bootstrap is suppressed while a streaming Host already owns the startup overlay, preventing an extra black cover during streaming startup.

### Compatibility

- Existing 0.7.x playback settings are migrated automatically to the new video-end behavior model.
- Existing custom media, shortcuts, and streaming configuration remain compatible.

## [0.7.1] - 2026-09-13

### Fixed

- The Desktop-to-Fullscreen bootstrap cover now uses the monitor's physical display bounds when Windows DPI virtualization reports scaled WinForms coordinates, preventing a smaller black rectangle from appearing in the top-left corner before the boot video on high-DPI and virtual displays.

### Changed

- Runtime updated to 1.0.8.

## [0.7.0] - 2026-09-11

### Added

- The configured boot screen can now cover Playnite's built-in Desktop-to-Fullscreen transition; the option is enabled by default and can be disabled in settings.
- A lightweight on-demand bootstrap cover bridges the Desktop window closing to the existing boot overlay without keeping a helper process resident.

### Changed

- Managed runtime files are now synchronized by content on Playnite startup, so runtime updates and repairs no longer depend only on `VERSION.txt`.
- Runtime updated to 1.0.7.

### Compatibility

- Desktop-to-Fullscreen interception fails open: if the bootstrap cover cannot be armed, Playnite continues its native transition normally.

## [0.6.2] - 2026-09-02

### Fixed

- Streaming startup now delegates foreground permission from Detached/Continue to the preload Host before Continue exits, so the Host can perform the final Playnite foreground handoff even when Fullscreen is replaced by a new PID during startup.

## [0.6.1] - 2026-08-25

### Fixed

- Streaming Prep/Continue now launches Playnite Fullscreen from the Detached/Continue process and lets the preload Host adopt that PID, preventing Playnite from remaining behind another foreground application when the boot overlay closes.

## [0.6.0] - 2026-08-07

### Added

- A managed video library scans supported files directly inside the persistent `Runtime\media` folder.
- `Follow Playnite Fullscreen setting` selects the desktop overlay monitor from Playnite's read-only Fullscreen configuration, with a saved manual fallback.
- Refresh, open-folder, external-file, and restore-default controls for boot-video selection.

### Changed

- Videos inside the standard media folder are written to the runtime configuration as portable relative paths.
- The extension icon now uses a language-neutral design.

### Fixed

- Playnite Fullscreen readiness is detected on the monitor actually occupied by its window, even when the boot overlay is displayed elsewhere.
- Stale or unavailable monitor indices now fall back safely instead of stopping the launcher.

## [0.5.0] - 2026-08-05

### Added

- English 4K60 default boot video and matching documentation preview.
- Alt+F4 cancellation for closing the boot overlay and stopping the Playnite Fullscreen process started by the current boot sequence.
- Explicit Alt+Tab handling that yields the overlay without relying on foreground-window polling.

### Changed

- Windows PowerShell is resolved through its absolute system path.
- Build output is cleaned before compilation and packaging uses an isolated temporary directory.
- Release packages no longer include PDB files.
- CI resolves the extension version from `extension.yaml`.

### Fixed

- The mouse cursor no longer becomes visible when a terminal, launcher, or streaming client temporarily receives foreground during Prep/Continue.
- Alt+F4 remains available throughout streaming preload and launch, including when another process temporarily owns foreground.
- Cancelling a preload before Continue no longer triggers the standalone fallback and relaunches Playnite.

### Security

- Shortcut names and persisted shortcut state are validated before filesystem paths are created or deleted.

## [0.4.0] - 2026-08-04

### Added

- Public name **Playnite Boot Screen**.
- English and Italian settings UI.
- Managed runtime installation under Playnite's extension data directory.
- Direct-launch shortcuts with a configurable name.
- Generic Sunshine/Apollo-compatible Preload and Continue commands.
- Optional wait for the natural end of the video.
- Volume control from 0 to 100 percent.
- Diagnostic summary copied without private paths or log contents.
- Runtime log rotation at 2 MiB with one backup.
- GitHub Actions build and tagged-release workflows.
- Playnite add-on database manifest templates.

### Compatibility

- Existing plugin ID and settings are preserved.
- Legacy `vibepollo` runtime configuration is accepted in read-only compatibility mode.
- Playnite Desktop to Fullscreen switching remains supported.

### Known limitations

- Fullscreen themes can fail to render correctly on some virtual displays. Test with Playnite's default Fullscreen theme when diagnosing a black screen.
- No global emergency hotkey is included in this version.
