# Changelog

All notable changes are documented here. Versions follow the Playnite extension manifest format.

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
