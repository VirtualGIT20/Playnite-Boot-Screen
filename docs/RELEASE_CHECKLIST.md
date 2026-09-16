# Release checklist — 0.8.1

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
- [ ] Ready, Wait, and Loop video-end behaviors each complete with the expected readiness/end semantics.
- [ ] A video that ends before Playnite is ready holds its final frame instead of revealing Playnite early.
- [ ] WebM selection resolves through the compatibility alias and still preserves the original source file.
- [ ] Streaming Preload primes and rewinds the decoder, and Continue restarts playback from the beginning.
- [ ] The startup-intro marker is signaled while PBS owns the overlay and absent/reset after release.
- [ ] With Aniki Helper intro enabled, PBS startup suppresses the duplicate Aniki intro; a normal Playnite launch remains outside the PBS marker lifecycle.
- [ ] Alt+F4 closes the overlay and stops the Playnite Fullscreen process started by the boot sequence.
- [ ] Alt+F4 during Preload prevents a later Continue command from using the standalone fallback.
- [ ] Alt+Tab yields the overlay, restores the cursor, and does not cancel Playnite startup.
- [ ] Automatic foreground changes from Terminal, Explorer, Sunshine, or Apollo do not reveal the cursor or disable Alt+F4.
- [ ] Streaming Preload and Continue succeed on the target virtual display.
- [ ] Follow Playnite selects the primary display when Playnite uses its primary-display option.
- [ ] Follow Playnite selects Playnite's configured secondary display when primary-display mode is disabled.
- [ ] Missing, invalid, or stale Playnite display settings fall back without stopping the launcher.
- [ ] Playnite readiness is detected when the overlay and Playnite Fullscreen are on different monitors.
- [ ] During Desktop → Fullscreen, changing Windows from an extended topology to a single active display is detected without the 45-second readiness timeout.
- [ ] If `MainWindowHandle` is not the valid Fullscreen window, the exact-PID top-level window fallback can complete readiness and foreground handoff.
- [ ] A `MediaFailed` event hides the failed video surface and falls back to a black overlay while readiness continues.
- [ ] The standard video folder list refreshes, ignores subfolders, and keeps external video paths supported.
- [ ] Standard-folder videos are written to `config.json` as relative `.\media\...` paths.
- [ ] Desktop and Start shortcuts can be created, renamed, and removed.
- [ ] PBS-managed shortcuts can use the PBS icon, Playnite Fullscreen icon, and a custom `.ico`; custom icons persist from the extension data folder.
- [ ] Upgrading 0.8.0 preserves the Playnite Fullscreen shortcut icon choice, while a fresh 0.8.1 profile defaults to the PBS icon.
- [ ] Quick Setup reports Ready when a PBS shortcut exists or Desktop → Fullscreen is enabled, and Setup needed otherwise.
- [ ] Invalid or modified shortcut state cannot escape the Desktop or Start menu directories.
- [ ] Runtime log rotates to `PlayniteBoot.log.1` after 2 MiB.
- [ ] With `VERSION.txt` unchanged at `1.0.13`, modifying a managed installed runtime file is repaired automatically on the next Playnite start.

## Display matrix

- [ ] Single 1080p display at 100% scaling.
- [ ] 4K display or VDD at 250% scaling: the bootstrap cover fills the physical display before the video.
- [ ] The same 4K display or VDD at 100% scaling: the bootstrap cover remains full-screen.
- [ ] Mixed 1080p/4K displays with different scaling values.
- [ ] Secondary display with negative desktop coordinates.
- [ ] Sunshine/Apollo virtual display at 4K60.

## Packaging

- [ ] `scripts/verify-release.ps1 -Version 0.8.1` succeeds.
- [ ] `scripts/pack.ps1 -Configuration Release` creates exactly one expected `.pext`.
- [ ] Build output and `.pext` both contain `RuntimeTemplate\SwitchBootstrap.ps1`.
- [ ] Build output and `.pext` both contain `RuntimeTemplate\PlayniteBoot.ico`.
- [ ] Build output and `.pext` both contain `RuntimeTemplate\media\Aniki_Remake_Intro.mp4`.
- [ ] Build and package contain no `.pdb`, source, temporary, or stale files.
- [ ] SHA-256 file matches the package.
- [ ] The `.pext` installs on a clean Playnite profile.
- [ ] The `.pext` installs over the maintainer's local development installation without losing settings or custom media.
- [ ] Updating an existing installation synchronizes managed runtime files and preserves custom media/configuration.

## GitHub

- [ ] Repository description, topics, and license are set.
- [ ] Private vulnerability reporting is enabled.
- [ ] CI workflow succeeds.
- [ ] Tag `v0.8.1` creates a release with `.pext` and checksum.
- [ ] Release notes highlight Quick Setup, shortcut icon choices, topology-aware Switch readiness, and the MediaFailed fallback.

## Playnite add-on database

- [ ] GitHub release asset URL is live.
- [ ] `distribution/installer.yaml` verifies with Toolbox.
- [ ] `distribution/addon.yaml` verifies with Toolbox.
- [ ] Published store entry resolves `distribution/installer.yaml` and exposes version `0.8.1`; no database pull request is needed unless central metadata changes.
