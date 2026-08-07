# Changelog

All notable changes are documented here. Versions follow the Playnite extension manifest format.

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
