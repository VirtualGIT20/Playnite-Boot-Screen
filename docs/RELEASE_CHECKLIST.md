# Release checklist — 0.5.0

## Code and behavior

- [ ] Release build completes with zero warnings and errors.
- [ ] Settings page opens in English and Italian.
- [ ] Settings save and cancel correctly.
- [ ] Direct cold launch succeeds.
- [ ] Launch while Playnite Desktop is already open switches to Fullscreen successfully.
- [ ] Wait-for-video-end mode succeeds.
- [ ] Alt+F4 closes the overlay and leaves an already launched Playnite session running.
- [ ] Streaming Preload and Continue succeed on the target virtual display.
- [ ] Desktop and Start shortcuts can be created, renamed, and removed.
- [ ] Invalid or modified shortcut state cannot escape the Desktop or Start menu directories.
- [ ] Runtime log rotates to `PlayniteBoot.log.1` after 2 MiB.

## Display matrix

- [ ] Single 1080p display at 100% scaling.
- [ ] Single 4K display at 150% or 200% scaling.
- [ ] Mixed 1080p/4K displays with different scaling values.
- [ ] Secondary display with negative desktop coordinates.
- [ ] Sunshine/Apollo virtual display at 4K60.

## Packaging

- [ ] `scripts/verify-release.ps1 -Version 0.5.0` succeeds.
- [ ] `scripts/pack.ps1 -Configuration Release` creates exactly one expected `.pext`.
- [ ] Build and package contain no `.pdb`, source, temporary, or stale files.
- [ ] SHA-256 file matches the package.
- [ ] The `.pext` installs on a clean Playnite profile.
- [ ] The `.pext` installs over the maintainer's local development installation without losing settings or custom media.

## GitHub

- [ ] Repository description, topics, and license are set.
- [ ] Private vulnerability reporting is enabled.
- [ ] CI workflow succeeds.
- [ ] Tag `v0.5.0` creates a release with `.pext` and checksum.
- [ ] Release notes mention the theme-related black-screen diagnostic.

## Playnite add-on database

- [ ] GitHub release asset URL is live.
- [ ] `distribution/installer.yaml` verifies with Toolbox.
- [ ] `distribution/addon.yaml` verifies with Toolbox.
- [ ] Add-on database pull request is opened under `addons/generic`.
