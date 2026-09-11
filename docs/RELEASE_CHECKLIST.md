# Release checklist — 0.7.0

## Code and behavior

- [ ] Release build completes with zero warnings and errors.
- [ ] Settings page opens in English and Italian.
- [ ] Settings save and cancel correctly.
- [ ] Direct cold launch succeeds.
- [ ] Launch while Playnite Desktop is already open switches to Fullscreen successfully.
- [ ] Playnite's built-in Desktop → Fullscreen command shows the configured boot screen when the new option is enabled.
- [ ] Fullscreen → Desktop → Fullscreen can be repeated and the boot transition still works.
- [ ] Disabling the Desktop → Fullscreen option leaves Playnite's native switch untouched.
- [ ] Normal Playnite Desktop exit does not trigger the switch overlay.
- [ ] Wait-for-video-end mode succeeds.
- [ ] Alt+F4 closes the overlay and stops the Playnite Fullscreen process started by the boot sequence.
- [ ] Alt+F4 during Preload prevents a later Continue command from using the standalone fallback.
- [ ] Alt+Tab yields the overlay, restores the cursor, and does not cancel Playnite startup.
- [ ] Automatic foreground changes from Terminal, Explorer, Sunshine, or Apollo do not reveal the cursor or disable Alt+F4.
- [ ] Streaming Preload and Continue succeed on the target virtual display.
- [ ] Follow Playnite selects the primary display when Playnite uses its primary-display option.
- [ ] Follow Playnite selects Playnite's configured secondary display when primary-display mode is disabled.
- [ ] Missing, invalid, or stale Playnite display settings fall back without stopping the launcher.
- [ ] Playnite readiness is detected when the overlay and Playnite Fullscreen are on different monitors.
- [ ] The standard video folder list refreshes, ignores subfolders, and keeps external video paths supported.
- [ ] Standard-folder videos are written to `config.json` as relative `.\media\...` paths.
- [ ] Desktop and Start shortcuts can be created, renamed, and removed.
- [ ] Invalid or modified shortcut state cannot escape the Desktop or Start menu directories.
- [ ] Runtime log rotates to `PlayniteBoot.log.1` after 2 MiB.
- [ ] With `VERSION.txt` unchanged at `1.0.7`, modifying a managed installed runtime file is repaired automatically on the next Playnite start.

## Display matrix

- [ ] Single 1080p display at 100% scaling.
- [ ] Single 4K display at 150% or 200% scaling.
- [ ] Mixed 1080p/4K displays with different scaling values.
- [ ] Secondary display with negative desktop coordinates.
- [ ] Sunshine/Apollo virtual display at 4K60.

## Packaging

- [ ] `scripts/verify-release.ps1 -Version 0.7.0` succeeds.
- [ ] `scripts/pack.ps1 -Configuration Release` creates exactly one expected `.pext`.
- [ ] Build output and `.pext` both contain `RuntimeTemplate\SwitchBootstrap.ps1`.
- [ ] Build and package contain no `.pdb`, source, temporary, or stale files.
- [ ] SHA-256 file matches the package.
- [ ] The `.pext` installs on a clean Playnite profile.
- [ ] The `.pext` installs over the maintainer's local development installation without losing settings or custom media.
- [ ] Updating an existing installation synchronizes managed runtime files and preserves custom media/configuration.

## GitHub

- [ ] Repository description, topics, and license are set.
- [ ] Private vulnerability reporting is enabled.
- [ ] CI workflow succeeds.
- [ ] Tag `v0.7.0` creates a release with `.pext` and checksum.
- [ ] Release notes describe the Desktop → Fullscreen transition, fail-open behavior, and content-aware runtime synchronization.

## Playnite add-on database

- [ ] GitHub release asset URL is live.
- [ ] `distribution/installer.yaml` verifies with Toolbox.
- [ ] `distribution/addon.yaml` verifies with Toolbox.
- [ ] Published store entry resolves `distribution/installer.yaml` and exposes version `0.7.0`; no database pull request is needed unless central metadata changes.
